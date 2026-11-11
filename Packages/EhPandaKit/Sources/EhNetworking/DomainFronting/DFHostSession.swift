import Foundation
import Security
import Synchronization

/// The connections to the addresses of one fronted domain.
///
/// Every domain has a session, and so a connection pool, of its own. A pooled connection is
/// reused without a new handshake, and domains can share addresses; with one pool for all of
/// them a request could travel over a connection that was authenticated for another domain.
final class DFHostSession: Sendable {
    private let delegate: DFSessionDelegate
    private let session: URLSession

    init(host: String, cookieStorage: HTTPCookieStorage, evaluateTrust: @escaping DFLoader.EvaluateTrust) {
        delegate = DFSessionDelegate(host: host, cookieStorage: cookieStorage, evaluateTrust: evaluateTrust)
        session = URLSession(configuration: Self.makeConfiguration(), delegate: delegate, delegateQueue: nil)
    }

    // A session keeps its delegate alive until it is invalidated.
    deinit { session.invalidateAndCancel() }

    /// Sends `request`, already addressed to one of the domain's addresses.
    /// - Parameter url: The URL the app asked for, which responses and redirects are reported against.
    func start(_ request: URLRequest, for url: URL, onEvent: @escaping @Sendable (DFLoadEvent) -> Void) -> DFLoad {
        let task = session.dataTask(with: request)
        delegate.track(task, url: url, onEvent: onEvent)
        task.resume()
        // Capturing `self` keeps the session, and with it the task, alive for as long as the
        // load's owner holds on to it.
        return DFLoad { [self] in
            delegate.forget(task)
            task.cancel()
        }
    }

    static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        // The session sees the address as its host. Cookies, caches and credentials keyed by
        // an address are meaningless at best, so the loader handles cookies for the domain itself.
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCredentialStorage = nil
        // Same limit as `URLSessionTransport`; gallery pages fan out to many requests per host.
        configuration.httpMaximumConnectionsPerHost = 8
        return configuration
    }
}

/// A task of the session and who hears about it.
private struct TrackedLoad {
    /// The URL the app asked for.
    let url: URL
    let onEvent: @Sendable (DFLoadEvent) -> Void
    var failedTrust = false
}

private final class DFSessionDelegate: NSObject, Sendable {
    private let host: String
    private let cookieStorage: HTTPCookieStorage
    private let evaluateTrust: DFLoader.EvaluateTrust
    private let loads = Mutex<[Int: TrackedLoad]>([:])

    init(host: String, cookieStorage: HTTPCookieStorage, evaluateTrust: @escaping DFLoader.EvaluateTrust) {
        self.host = host
        self.cookieStorage = cookieStorage
        self.evaluateTrust = evaluateTrust
    }

    func track(_ task: URLSessionTask, url: URL, onEvent: @escaping @Sendable (DFLoadEvent) -> Void) {
        loads.withLock { $0[task.taskIdentifier] = TrackedLoad(url: url, onEvent: onEvent) }
    }

    /// Stops reporting for `task`, returning its load if it was still tracked.
    @discardableResult
    func forget(_ task: URLSessionTask) -> TrackedLoad? {
        loads.withLock { $0.removeValue(forKey: task.taskIdentifier) }
    }

    private func load(for task: URLSessionTask) -> TrackedLoad? {
        loads.withLock { $0[task.taskIdentifier] }
    }

    private func storeCookies(from response: HTTPURLResponse, for url: URL) {
        guard let fields = response.allHeaderFields as? [String: String] else { return }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
        if !cookies.isEmpty {
            cookieStorage.setCookies(cookies, for: url, mainDocumentURL: nil)
        }
    }
}

extension DFSessionDelegate: URLSessionDataDelegate {
    /// The session asks during the TLS handshake and the handshake waits for the answer, so
    /// when the certificate is refused here nothing of the request has been sent.
    func urlSession(
        _ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        if let trust = challenge.protectionSpace.serverTrust, evaluateTrust(trust, host) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            // Cancelling the challenge fails the task as "cancelled"; this tells the two apart.
            loads.withLock { $0[task.taskIdentifier]?.failedTrust = true }
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// Redirects are reported, never followed here: the request the session proposes still
    /// carries this domain's `Host` header and, for a relative location, points at the address.
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
        guard let load = load(for: task) else { return }
        storeCookies(from: response, for: load.url)
        guard let location = response.value(forHTTPHeaderField: "Location"),
              let target = dfRedirectURL(location: location, relativeTo: load.url),
              forget(task) != nil
        else { return }
        task.cancel()

        var redirect = URLRequest(url: target)
        redirect.httpMethod = "GET"
        load.onEvent(.redirected(to: redirect, response: response.readdressed(to: load.url)))
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        guard let load = load(for: dataTask) else {
            completionHandler(.cancel)
            return
        }
        guard let response = response as? HTTPURLResponse else {
            forget(dataTask)
            completionHandler(.cancel)
            load.onEvent(.failed(URLError(.badServerResponse, userInfo: [NSURLErrorFailingURLErrorKey: load.url])))
            return
        }
        storeCookies(from: response, for: load.url)
        load.onEvent(.received(response.readdressed(to: load.url)))
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        load(for: dataTask)?.onEvent(.loaded(data))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let load = forget(task) else { return }
        guard let error else {
            load.onEvent(.finished)
            return
        }
        let reported = reportedError(for: error, load: load)
        let code = reported.code.rawValue
        NetworkLog.logger.debug("Domain fronting: a request for \(self.host, privacy: .public) failed (\(code))")
        load.onEvent(.failed(reported))
    }

    /// The session's error as the app should see it: about the URL it asked for rather than
    /// the address, and naming the certificate when that is what stopped the request.
    private func reportedError(for error: any Error, load: TrackedLoad) -> URLError {
        var userInfo: [String: Any] = [NSURLErrorFailingURLErrorKey: load.url]
        guard !load.failedTrust else {
            return URLError(.serverCertificateUntrusted, userInfo: userInfo)
        }
        userInfo[NSUnderlyingErrorKey] = error
        userInfo[NSLocalizedDescriptionKey] = error.localizedDescription
        return URLError((error as? URLError)?.code ?? .unknown, userInfo: userInfo)
    }
}
