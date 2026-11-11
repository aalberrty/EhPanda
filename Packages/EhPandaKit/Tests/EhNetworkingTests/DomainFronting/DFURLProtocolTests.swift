import EhTestSupport
import Foundation
import Synchronization
import Testing
@testable import EhNetworking

/// `DFURLProtocol` with every fronted domain found on this machine and the test root trusted.
private final class LocalFrontingProtocol: DFURLProtocol, @unchecked Sendable {
    // `@unchecked Sendable`: restates the inherited conformance; adds no state.
    static let cookies = InMemoryCookieStorage()
    static let localLoader = DFLoader.local(cookieStorage: cookies)

    override class var loader: DFLoader { localLoader }
}

/// The same, validating certificates exactly as the app does.
private final class LocalValidatingProtocol: DFURLProtocol, @unchecked Sendable {
    // `@unchecked Sendable`: restates the inherited conformance; adds no state.
    static let cookies = InMemoryCookieStorage()
    static let localLoader = DFLoader.local(cookieStorage: cookies, evaluateTrust: DFTrust.evaluate)

    override class var loader: DFLoader { localLoader }
}

/// Stands in for the session's own protocols: answers whatever reaches it.
private final class FallbackProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("not fronted".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// What a session's delegate sees of a download as it arrives.
private final class Download: NSObject, URLSessionDataDelegate, Sendable {
    struct Progress: Sendable {
        var expectedLength: Int64?
        var chunks = 0
        var body = Data()
        var result: Result<Void, URLError>?
    }

    private let state = Mutex(Progress())

    var progress: Progress { state.withLock { $0 } }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        state.withLock { $0.expectedLength = response.expectedContentLength }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        state.withLock {
            $0.chunks += 1
            $0.body.append(data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        state.withLock { $0.result = error.map { .failure(URLError.normalized($0)) } ?? .success(()) }
    }
}

struct DFURLProtocolTests {
    @Test func handlesOnlyHTTPForFrontedDomains() {
        #expect(DFURLProtocol.canInit(with: makeRequest("https://e-hentai.org/")))
        #expect(DFURLProtocol.canInit(with: makeRequest("http://e-hentai.org/")))
        #expect(DFURLProtocol.canInit(with: makeRequest("https://ehgt.org/g/t.png")))
        #expect(!DFURLProtocol.canInit(with: makeRequest("ftp://e-hentai.org/")))
        #expect(!DFURLProtocol.canInit(with: makeRequest("data:text/plain,hi")))
        // Everything else stays with the session's own protocols.
        #expect(!DFURLProtocol.canInit(with: makeRequest("https://example.com/")))
        #expect(!DFURLProtocol.canInit(with: makeRequest("https://104.20.134.21/")))
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

/// `DFURLProtocol` driven the way the app drives it: installed in a `URLSession`.
@Suite(.timeLimit(.minutes(2)))
struct DFURLProtocolSessionTests {
    private func makeSession(
        _ protocolClass: AnyClass = LocalFrontingProtocol.self, delegate: (any URLSessionDelegate)? = nil
    ) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass, FallbackProtocol.self]
        configuration.timeoutIntervalForRequest = 60
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    @Test func loadsARequestForAFrontedDomain() async throws {
        let server = try await LocalServer { _ in .text("gallery", headers: [("Content-Type", "text/html")]) }
        defer { server.stop() }
        LocalFrontingProtocol.cookies.setCookie(makeCookie("sk", "abc", path: "/posted"))
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: makeLoginRequest(server.url("/posted/login")))

        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect(http.url == server.url("/posted/login"))
        #expect(http.value(forHTTPHeaderField: "Content-Type") == "text/html")
        #expect(String(decoding: data, as: UTF8.self) == "gallery")

        let received = try #require(server.record.requests.first)
        #expect(received.method == "POST")
        #expect(received.headers["host"] == "e-hentai.org")
        #expect(received.headers["cookie"] == "sk=abc")
        #expect(received.body == Data("UserName=me&PassWord=SECRET-PASSWORD".utf8))
    }

    @Test func theSessionFollowsARedirectThroughTheProtocolAgain() async throws {
        let server = try await LocalServer { request in
            request.target == "/login" ? .redirect(to: "/home?from=login") : .text("landed")
        }
        defer { server.stop() }
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: makeLoginRequest(server.url("/login")))

        #expect(String(decoding: data, as: UTF8.self) == "landed")
        #expect(response.url == server.url("/home?from=login"))
        #expect(server.record.requests.map(\.method) == ["POST", "GET"])
        #expect(server.record.requests.map(\.target) == ["/login", "/home?from=login"])
        #expect(server.record.requests.last?.headers["host"] == "e-hentai.org")
        #expect(server.record.requests.last?.body.isEmpty == true)
    }

    @Test func leavesOtherDomainsToTheSession() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let (data, _) = try await session.data(from: try #require(URL(string: "https://example.com/")))

        #expect(String(decoding: data, as: UTF8.self) == "not fronted")
    }

    @Test func streamsALargeBodyWithProgress() async throws {
        let firstPart = Data(repeating: 0x61, count: 256 * 1024)
        let rest = Data(repeating: 0x62, count: 768 * 1024)
        let gate = Gate()
        let server = try await LocalServer { _ in LocalReply(body: firstPart, held: (rest, gate)) }
        defer { server.stop() }
        let download = Download()
        let session = makeSession(delegate: download)
        defer { session.invalidateAndCancel() }

        session.dataTask(with: server.url("/fullimg.jpg")).resume()

        // The start arrives while the server still holds the rest back.
        #expect(await eventually { download.progress.body.count == firstPart.count })
        #expect(download.progress.expectedLength == Int64(firstPart.count + rest.count))
        #expect(download.progress.result == nil)

        gate.open()
        #expect(await eventually { download.progress.result != nil })
        let progress = download.progress
        #expect(progress.body == firstPart + rest)
        #expect(progress.chunks > 1)
        #expect(throws: Never.self) { try progress.result?.get() }
    }

    @Test func loadsManyRequestsAtOnce() async throws {
        // A page of thumbnails: every request gets its own body back, over a bounded number of
        // connections.
        let server = try await LocalServer { request in .text("image for \(request.target)") }
        defer { server.stop() }
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let bodies = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for index in 0..<60 {
                group.addTask { (index, try await session.data(from: server.url("/t/\(index).jpg")).0) }
            }
            return try await group.reduce(into: [Int: Data]()) { $0[$1.0] = $1.1 }
        }

        #expect(bodies.count == 60)
        for (index, body) in bodies {
            #expect(String(decoding: body, as: UTF8.self) == "image for /t/\(index).jpg")
        }
        #expect(server.record.requests.count == 60)
        #expect(server.record.handshakes <= DFHostSession.makeConfiguration().httpMaximumConnectionsPerHost)
    }

    @Test func cancellingTheTaskCancelsTheLoad() async throws {
        let server = try await LocalServer { _ in .silence }
        defer { server.stop() }
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let task = Task { try await session.data(from: server.url("/hang")) }
        #expect(await eventually { server.record.requests.count == 1 })
        task.cancel()

        let error = await #expect(throws: URLError.self) { try await task.value }
        #expect(error?.code == .cancelled)
        // The connection to the server is given up too, not left to time out.
        #expect(await server.connectionsDidEnd())
    }

    @Test func aRequestTimesOutWithTheSessionsTimeout() async throws {
        let server = try await LocalServer { _ in .silence }
        defer { server.stop() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocalFrontingProtocol.self]
        configuration.timeoutIntervalForRequest = 1
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let error = await #expect(throws: URLError.self) { try await session.data(from: server.url("/hang")) }

        #expect(error?.code == .timedOut)
        #expect(await server.connectionsDidEnd())
    }

    /// The whole path the app uses, with the app's own certificate validation: a server that
    /// cannot prove it is the domain learns nothing from the login it was sent.
    @Test func aServerThatCannotAuthenticateReceivesNothing() async throws {
        let server = try await LocalServer()
        defer { server.stop() }
        LocalValidatingProtocol.cookies.setCookie(makeCookie("ipb_pass_hash", "SECRET-HASH"))
        let session = makeSession(LocalValidatingProtocol.self)
        defer { session.invalidateAndCancel() }

        let error = await #expect(throws: URLError.self) {
            try await session.data(for: makeLoginRequest(server.url("/bounce_login.php")))
        }

        #expect(error?.code == .serverCertificateUntrusted)
        #expect(await server.connectionsDidEnd())
        #expect(server.record.connections >= 1)
        #expect(server.record.handshakes == 0)
        #expect(server.record.received.isEmpty)
        #expect(server.record.requests.isEmpty)
    }
}
