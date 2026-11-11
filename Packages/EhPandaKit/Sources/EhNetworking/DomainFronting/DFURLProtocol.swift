import Foundation
import Synchronization

/// A `URLProtocol` that bypasses SNI filtering for the site's domains: it connects to a fixed
/// address without naming the server, validates the certificate for the real domain, and only
/// then sends the request with the domain in its `Host` header (see `DFLoader`).
///
/// Install it with `URLSessionConfiguration.setDomainFronting(_:)`. It takes the requests for
/// the domains `DomainResolver` knows and leaves all others to the session's own protocols.
/// Cookies come from and go to `HTTPCookieStorage.shared`, because a protocol instance cannot
/// see its session's storage.
public class DFURLProtocol: URLProtocol, @unchecked Sendable {
    // `@unchecked Sendable`: what `URLProtocol` holds (`request`, `client`) is set once at
    // initialisation and only used on the thread URL loading runs this protocol on, in
    // `startLoading` and in `report`, which runs on that thread's run loop. Other threads only
    // carry the reference back to it. The one property added here is behind a mutex.
    private let current = Mutex<DFLoad?>(nil)

    /// What carries out the loads. Tests substitute one that resolves to a local server.
    class var loader: DFLoader { .live }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override public class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme, ["http", "https"].contains(scheme) else { return false }
        return loader.fronts(request)
    }

    override public func startLoading() {
        // `URLProtocolClient` expects its calls on the thread loading was started on. The loader
        // reports from its sessions' queues, so every event is handed back to this run loop,
        // which also means that none is reported before `current` is set below.
        let clientRunLoop = ClientRunLoop(runLoop: CFRunLoopGetCurrent())
        let load = Self.loader.load(request) { [weak self] event in
            guard let self else { return }
            clientRunLoop.perform { self.report(event) }
        }
        current.withLock { $0 = load }
    }

    override public func stopLoading() {
        current.withLock { $0.take() }?.cancel()
    }

    private func report(_ event: DFLoadEvent) {
        // Events still queued when loading stopped are dropped.
        guard current.withLock({ $0 != nil }) else { return }
        switch event {
        case .redirected(let request, let response):
            // The session stops this load and starts another for the new request, which comes
            // back here when it is for a fronted domain.
            client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        case .received(let response):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        case .loaded(let data):
            client?.urlProtocol(self, didLoad: data)
        case .finished:
            client?.urlProtocolDidFinishLoading(self)
        case .failed(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

/// The run loop of the thread URL loading started a protocol on.
private struct ClientRunLoop: @unchecked Sendable {
    // `@unchecked Sendable`: the run loop is only passed to `CFRunLoopPerformBlock` and
    // `CFRunLoopWakeUp`, which, like the other `CFRunLoop` functions, may be called from any thread.
    let runLoop: CFRunLoop?

    func perform(_ block: @escaping @Sendable () -> Void) {
        // Common modes, so the block runs whichever of them the loading thread's run loop is in.
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue, block)
        CFRunLoopWakeUp(runLoop)
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
