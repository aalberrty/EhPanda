import Foundation

/// A `URLProtocol` that bypasses SNI filtering: it connects to a fixed IP for known domains,
/// sends the real domain only in the `Host` header and validates the certificate itself.
///
/// Install it with `URLSessionConfiguration.setDomainFronting(_:)`. Cookies are read from
/// `HTTPCookieStorage.shared` because a protocol instance cannot see its session's storage.
public final class DFURLProtocol: URLProtocol, @unchecked Sendable {
    // `@unchecked Sendable`: `dfRequest` is only touched in `startLoading` and `stopLoading` and
    // from stream callbacks, all of which URL loading runs on the single thread that started loading.
    private var dfRequest: DFRequest?
    static let requestIdentifier = "DomainFrontingRequest"

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override public class func canInit(with request: URLRequest) -> Bool {
        guard property(forKey: requestIdentifier, in: request) == nil else { return false }
        return ["http", "https"].contains(request.url?.scheme)
    }

    override public func startLoading() {
        dfRequest = DFRequest(request, cookieStorage: .shared, delegate: self)
        dfRequest?.resume()
    }

    override public func stopLoading() {
        dfRequest?.stop()
        dfRequest = nil
    }
}

extension DFURLProtocol: DFRequestDelegate {
    func dfRequestDidFinishLoading(_ request: DFRequest) {
        client?.urlProtocolDidFinishLoading(self)
    }

    func dfRequest(_ request: DFRequest, didLoad data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func dfRequest(_ request: URLRequest, didFailWithError error: any Error) {
        client?.urlProtocol(self, didFailWithError: error)
    }

    func dfRequest(_ request: DFRequest, wasRedirectedTo urlRequest: URLRequest, redirectResponse: URLResponse) {
        client?.urlProtocol(self, wasRedirectedTo: urlRequest, redirectResponse: redirectResponse)
    }

    func dfRequest(
        _ request: DFRequest, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy
    ) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: policy)
    }
}

extension URLSessionConfiguration {
    /// Adds or removes `DFURLProtocol` at the front of `protocolClasses`. Sessions copy their
    /// configuration, so apply this before creating a session (for Kingfisher, set the
    /// downloader's `sessionConfiguration` again afterwards).
    public func setDomainFronting(_ enabled: Bool) {
        var classes = (protocolClasses ?? []).filter { $0 != DFURLProtocol.self }
        if enabled {
            classes.insert(DFURLProtocol.self, at: 0)
        }
        protocolClasses = classes
    }

    /// Whether `DFURLProtocol` is installed.
    public var isDomainFrontingEnabled: Bool {
        protocolClasses?.contains { $0 == DFURLProtocol.self } ?? false
    }
}
