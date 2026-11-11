import EhTestSupport
import Foundation
import Testing
@testable import EhNetworking

struct DomainResolverTests {
    @Test(arguments: ResolvableDomain.allCases)
    func resolvesKnownDomainsFromTheirPool(domain: ResolvableDomain) throws {
        #expect(!domain.ipPool.isEmpty)
        let ip = try #require(DomainResolver.resolve(domain: domain.rawValue))
        #expect(domain.ipPool.contains(ip))
    }

    @Test func unknownDomainsAreNotResolved() {
        #expect(DomainResolver.resolve(domain: "example.com") == nil)
        #expect(DomainResolver.resolve(domain: "E-HENTAI.ORG") == nil)
    }
}

struct DFRequestBuildingTests {
    private let storage = InMemoryCookieStorage()

    private func fronted(_ request: URLRequest) -> URLRequest? {
        request.fronted(resolve: { $0 == "e-hentai.org" ? "104.20.134.21" : nil }, cookieStorage: storage)
    }

    private func store(_ name: String, _ value: String, domain: String, path: String = "/") {
        storage.setCookie(HTTPCookie(properties: [.name: name, .value: value, .domain: domain, .path: path])!)
    }

    @Test func domainPrefersTheHostHeader() {
        var request = makeRequest("https://1.2.3.4/g/1/")
        #expect(request.domain == "1.2.3.4")
        #expect(!request.hasHostField)

        request.setValue("e-hentai.org", forHTTPHeaderField: "host")
        #expect(request.hostKey?.lowercased() == "host")
        #expect(request.hasHostField)
        #expect(request.domain == "e-hentai.org")
        #expect(request.domainURL?.absoluteString == "https://e-hentai.org/g/1/")
    }

    @Test func frontedRequestGoesToTheAddressWithTheDomainInTheHostHeader() throws {
        let request = try #require(fronted(makeRequest("https://e-hentai.org:8443/g/1/abc/?p=2", method: "HEAD")))

        #expect(request.url?.absoluteString == "https://104.20.134.21:8443/g/1/abc/?p=2")
        #expect(request.value(forHTTPHeaderField: "Host") == "e-hentai.org")
        #expect(request.httpMethod == "HEAD")
        #expect(request.domain == "e-hentai.org")
        #expect(request.domainURL?.absoluteString == "https://e-hentai.org:8443/g/1/abc/?p=2")
    }

    @Test func frontedRequestKeepsTheCallersHeaders() throws {
        var original = makeRequest("https://203.0.113.9/")
        original.setValue("e-hentai.org", forHTTPHeaderField: "Host")
        original.setValue("Agent", forHTTPHeaderField: "User-Agent")

        let request = try #require(fronted(original))

        #expect(request.url?.host == "104.20.134.21")
        #expect(request.allHTTPHeaderFields == ["Host": "e-hentai.org", "User-Agent": "Agent"])
    }

    @Test func unknownDomainsAreNotFronted() {
        #expect(fronted(makeRequest("https://example.com/a")) == nil)
        #expect(fronted(makeRequest("https://104.20.134.21/a")) == nil)
    }

    @Test func frontedRequestCarriesTheCookiesOfItsDomain() throws {
        store("ipb_member_id", "1", domain: "e-hentai.org")
        store("sk", "abc", domain: ".e-hentai.org")
        store("igneous", "ex-only", domain: "exhentai.org")
        store("skipserver", "s-only", domain: "e-hentai.org", path: "/s/")
        // What the session would do with the address as its host.
        store("stray", "1", domain: "104.20.134.21")

        var original = makeRequest("https://e-hentai.org/g/1/abc/")
        original.setValue("overridden=1", forHTTPHeaderField: "Cookie")
        let request = try #require(fronted(original))

        let cookies = Set(try #require(request.value(forHTTPHeaderField: "Cookie")).components(separatedBy: "; "))
        #expect(cookies == ["ipb_member_id=1", "sk=abc"])
        #expect(!request.httpShouldHandleCookies)
    }

    @Test func frontedRequestKeepsTheCallersCookieHeaderWhenNothingIsStored() throws {
        var original = makeRequest()
        original.setValue("mine=1", forHTTPHeaderField: "Cookie")

        #expect(try #require(fronted(original)).value(forHTTPHeaderField: "Cookie") == "mine=1")
        #expect(try #require(fronted(makeRequest())).value(forHTTPHeaderField: "Cookie") == nil)
    }

    @Test func frontedRequestHoldsItsBodyInMemory() throws {
        // URL loading hands a protocol the body as a stream.
        var original = makeRequest("https://e-hentai.org/api.php", method: "POST")
        original.httpBodyStream = InputStream(data: Data("a=1&b=2".utf8))

        let request = try #require(fronted(original))

        #expect(request.httpBody == Data("a=1&b=2".utf8))
        #expect(request.httpBodyStream == nil)
    }

    @Test func bodyDataDrainsStreams() {
        var request = makeRequest(method: "POST")
        request.httpBodyStream = InputStream(data: Data(repeating: 7, count: 5000))
        #expect(request.bodyData() == Data(repeating: 7, count: 5000))

        request.httpBody = Data("x".utf8)
        #expect(request.bodyData() == Data("x".utf8))

        #expect(makeRequest().bodyData() == nil)
    }

    @Test(arguments: [
        ("/", "https://e-hentai.org/"),
        ("/popular", "https://e-hentai.org/popular"),
        ("/watched", "https://e-hentai.org/watched"),
        ("/?f_search=abc", "https://e-hentai.org/?f_search=abc"),
        ("?p=2", "https://e-hentai.org/g/1/a/?p=2"),
        ("//forums.e-hentai.org/index.php", "https://forums.e-hentai.org/index.php"),
        ("https://exhentai.org/g/1/a/", "https://exhentai.org/g/1/a/")
    ])
    func redirectsResolveAgainstTheRequestedURL(location: String, expected: String) throws {
        let requested = try #require(URL(string: "https://e-hentai.org/g/1/a/"))
        #expect(dfRedirectURL(location: location, relativeTo: requested)?.absoluteString == expected)
    }

    @Test func redirectsKeepThePortOfTheRequestedURL() throws {
        let requested = try #require(URL(string: "https://e-hentai.org:8443/g/1/a/"))
        let target = dfRedirectURL(location: "/popular", relativeTo: requested)
        #expect(target?.absoluteString == "https://e-hentai.org:8443/popular")
    }

    @Test func readdressedResponseAnswersTheRequestedURL() throws {
        let address = try #require(URL(string: "https://104.20.134.21/g/1/a/"))
        let requested = try #require(URL(string: "https://e-hentai.org/g/1/a/"))
        let fields = ["Content-Type": "image/png", "Content-Length": "913", "Set-Cookie": "a=1"]
        let response = try #require(
            HTTPURLResponse(url: address, statusCode: 404, httpVersion: "HTTP/2", headerFields: fields)
        )

        let readdressed = response.readdressed(to: requested)

        #expect(readdressed.url == requested)
        #expect(readdressed.statusCode == 404)
        #expect(readdressed.allHeaderFields as? [String: String] == fields)
        #expect(readdressed.expectedContentLength == 913)
        #expect(readdressed.mimeType == "image/png")
    }
}
