import Foundation

/// One domain-fronted HTTP exchange over a CFNetwork stream.
///
/// Confined to the thread that created it: the stream is scheduled on that thread's run loop,
/// and `DFURLProtocol` only touches it from the URL loading thread that started it.
final class DFRequest {
    let request: URLRequest
    private let stream: InputStream
    private(set) weak var delegate: (any DFRequestDelegate)?
    private var streamHandler: DFStreamEventHandler?

    init?(
        _ originalRequest: URLRequest,
        cookieStorage: HTTPCookieStorage,
        delegate: (any DFRequestDelegate)?
    ) {
        self.delegate = delegate
        var request = originalRequest.domainIPReplaced()
        // Custom protocols do not get the session's cookie handling. Setting
        // `allHTTPHeaderFields` merges into the existing headers, so `Host` is kept.
        if let url = originalRequest.url, let cookies = cookieStorage.cookies(for: url) {
            request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: cookies)
        }
        self.request = request

        switch InputStream.makeHTTPStream(for: request) {
        case .success(let stream):
            self.stream = stream
        case .failure(let error):
            delegate?.dfRequest(request, didFailWithError: error)
            return nil
        }

        if request.isHTTPS, request.domain?.isEmpty == false {
            stream.disableCertificateChainValidation()
        }
    }

    func resume() {
        let handler = DFStreamEventHandler(request: self)
        streamHandler = handler
        stream.schedule(in: .current, forMode: .common)
        stream.delegate = handler
        stream.open()
    }

    /// Closes the stream and stops reporting to the delegate. Safe to call more than once and
    /// from inside a stream event.
    func stop() {
        stream.delegate = nil
        stream.close()
        delegate = nil
    }
}

protocol DFRequestDelegate: AnyObject {
    func dfRequestDidFinishLoading(_ request: DFRequest)
    func dfRequest(_ request: DFRequest, didLoad data: Data)
    func dfRequest(_ request: URLRequest, didFailWithError error: any Error)
    func dfRequest(_ request: DFRequest, wasRedirectedTo urlRequest: URLRequest, redirectResponse: URLResponse)
    func dfRequest(
        _ request: DFRequest, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy
    )
}
