import EhTestSupport
import Foundation
import Testing
@testable import EhNetworking

/// Answers `/status/<code>` with that status and never answers `/hang`, without any network.
private final class LocalProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "local.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, url.path != "/hang" else { return }
        let status = Int(url.lastPathComponent) ?? 200
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("status \(status)".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

struct URLSessionTransportTests {
    func makeTransport(fronting: Bool = false) -> URLSessionTransport {
        let configuration = URLSessionTransport.makeConfiguration(cookieStorage: .shared)
        configuration.protocolClasses = [LocalProtocol.self] + (configuration.protocolClasses ?? [])
        return URLSessionTransport(configuration: configuration, isDomainFrontingEnabled: fronting)
    }

    @Test func returnsErrorStatusesInsteadOfThrowing() async throws {
        let response = try await makeTransport().send(makeRequest("https://local.test/status/404"))

        #expect(response.statusCode == 404)
        #expect(String(decoding: response.data, as: UTF8.self) == "status 404")
    }

    @Test func cancellingTheTaskCancelsTheRequest() async throws {
        let transport = makeTransport()
        let task = Task { try await transport.send(makeRequest("https://local.test/hang")) }
        try await Task.sleep(for: .milliseconds(100))

        let start = ContinuousClock.now
        task.cancel()
        let result = await task.result

        #expect(ContinuousClock.now - start < .seconds(2))
        let error = #expect(throws: URLError.self) { try result.get() }
        #expect(error?.code == .cancelled)
    }

    @Test func alreadyCancelledTaskThrowsWithoutSending() async {
        let transport = makeTransport()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await transport.send(makeRequest("https://local.test/status/200"))
        }
        await #expect(throws: URLError(.cancelled)) { try await task.value }
    }

    @Test func domainFrontingCanBeSwitchedAtRuntime() {
        let transport = makeTransport()
        #expect(!transport.isDomainFrontingEnabled)
        #expect(!transport.currentSession.configuration.isDomainFrontingEnabled)

        transport.isDomainFrontingEnabled = true
        #expect(transport.isDomainFrontingEnabled)
        #expect(transport.currentSession.configuration.isDomainFrontingEnabled)
        #expect(transport.currentSession.configuration.protocolClasses?.first == DFURLProtocol.self)

        transport.isDomainFrontingEnabled = false
        #expect(!transport.currentSession.configuration.isDomainFrontingEnabled)
    }

    @Test func configurationUsesInjectedCookiesAndRaisedLimits() {
        let storage = InMemoryCookieStorage()
        let configuration = URLSessionTransport.makeConfiguration(cookieStorage: storage)

        #expect(configuration.httpCookieStorage === storage)
        #expect(configuration.httpMaximumConnectionsPerHost > 6)
        #expect(configuration.timeoutIntervalForRequest == 30)
        #expect(configuration.timeoutIntervalForResource == 120)
        #expect(!configuration.isDomainFrontingEnabled)
    }
}
