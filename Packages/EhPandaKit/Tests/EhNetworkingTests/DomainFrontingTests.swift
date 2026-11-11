import CFNetwork
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
    @Test func domainPrefersTheHostHeader() {
        var request = makeRequest("https://1.2.3.4/g/1/")
        #expect(request.domain == "1.2.3.4")
        #expect(!request.hasHostField)

        request.setValue("e-hentai.org", forHTTPHeaderField: "host")
        #expect(request.hostKey?.lowercased() == "host")
        #expect(request.hasHostField)
        #expect(request.domain == "e-hentai.org")
        #expect(request.domainWithScheme == "https://e-hentai.org")
    }

    @Test func domainIPReplacedMovesTheDomainToTheHostHeader() {
        let request = makeRequest("https://e-hentai.org/g/1/abc/?p=2").domainIPReplaced { domain in
            domain == "e-hentai.org" ? "104.20.134.21" : nil
        }

        #expect(request.url?.absoluteString == "https://104.20.134.21/g/1/abc/?p=2")
        #expect(request.value(forHTTPHeaderField: "Host") == "e-hentai.org")
        #expect(request.domain == "e-hentai.org")
    }

    @Test func domainIPReplacedKeepsAnExistingHostHeader() {
        var original = makeRequest("https://exhentai.org/")
        original.setValue("exhentai.org", forHTTPHeaderField: "Host")

        let request = original.domainIPReplaced { _ in "178.175.128.252" }

        #expect(request.url?.host == "178.175.128.252")
        #expect(request.allHTTPHeaderFields == ["Host": "exhentai.org"])
    }

    @Test func domainIPReplacedLeavesUnknownDomainsAlone() {
        let original = makeRequest("https://example.com/a")
        #expect(original.domainIPReplaced() == original)
    }

    @Test func detectsImageURLs() {
        #expect(makeRequest("https://ehgt.org/t/ab/cd.jpg").urlContainsImageURL)
        #expect(makeRequest("https://e-hentai.org/x.webp?f=png").urlContainsImageURL)
        #expect(!makeRequest("https://e-hentai.org/g/1/abc/").urlContainsImageURL)
    }

    @Test func bodyDataDrainsPostStreams() {
        var request = makeRequest(method: "POST")
        request.httpBodyStream = InputStream(data: Data("a=1&b=2".utf8))
        #expect(request.bodyData() == Data("a=1&b=2".utf8))

        request.httpBody = Data("x".utf8)
        #expect(request.bodyData() == Data("x".utf8))

        #expect(makeRequest().bodyData() == nil)
    }

    @Test(arguments: [
        ("/", "https://e-hentai.org/"),
        ("/popular", "https://e-hentai.org/popular"),
        ("/watched", "https://e-hentai.org/watched"),
        ("/?f_search=abc", "https://e-hentai.org/?f_search=abc"),
        ("https://exhentai.org/g/1/a/", "https://exhentai.org/g/1/a/")
    ])
    func redirectsResolveAgainstTheRealDomain(location: String, expected: String) {
        #expect(dfRedirectURL(location: location, domainWithScheme: "https://e-hentai.org")?.absoluteString == expected)
    }

    @Test func httpMessageCarriesMethodHeadersAndBody() throws {
        var request = makeRequest("https://104.20.134.21/api.php", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let message = try InputStream.makeHTTPMessage(for: request).get()

        #expect(CFHTTPMessageCopyRequestMethod(message)?.takeRetainedValue() as String? == "POST")
        #expect(message.url?.absoluteString == "https://104.20.134.21/api.php")
        #expect(message.allHeaderFields["Content-Type"] == "application/json")
        #expect(message.allHeaderFields["Host"] == "104.20.134.21")
        #expect(CFHTTPMessageCopyBody(message)?.takeRetainedValue() as Data? == Data("{}".utf8))
    }

    @Test func httpMessageNeedsAURL() {
        var request = makeRequest()
        request.url = nil
        #expect(throws: DFStreamError.urlNotFound) { try InputStream.makeHTTPMessage(for: request).get() }
    }

    @Test func httpStreamIsCreatedUnopened() throws {
        let stream = try InputStream.makeHTTPStream(for: makeRequest()).get()
        #expect(stream.streamStatus == .notOpen)
    }
}

struct DFURLProtocolTests {
    @Test func handlesOnlyHTTP() {
        #expect(DFURLProtocol.canInit(with: makeRequest("https://e-hentai.org/")))
        #expect(DFURLProtocol.canInit(with: makeRequest("http://e-hentai.org/")))
        #expect(!DFURLProtocol.canInit(with: makeRequest("ftp://e-hentai.org/")))
        #expect(!DFURLProtocol.canInit(with: makeRequest("data:text/plain,hi")))
    }

    @Test func configurationSwitch() {
        let configuration = URLSessionConfiguration.ephemeral
        let original = configuration.protocolClasses ?? []

        configuration.setDomainFronting(true)
        configuration.setDomainFronting(true)
        #expect(configuration.isDomainFrontingEnabled)
        #expect(configuration.protocolClasses?.first == DFURLProtocol.self)
        #expect(configuration.protocolClasses?.count == original.count + 1)

        configuration.setDomainFronting(false)
        #expect(!configuration.isDomainFrontingEnabled)
        #expect(configuration.protocolClasses?.count == original.count)
    }
}
