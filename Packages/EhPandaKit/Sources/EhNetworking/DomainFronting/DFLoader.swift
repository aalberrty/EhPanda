import Foundation
import Security
import Synchronization

/// What a fronted load reports, in order. The cases mirror the `URLProtocolClient` callbacks.
enum DFLoadEvent: Sendable {
    /// The server redirected. The load ends here; the caller decides whether to follow.
    case redirected(to: URLRequest, response: HTTPURLResponse)
    case received(HTTPURLResponse)
    case loaded(Data)
    case finished
    case failed(URLError)
}

/// A fronted load in flight.
struct DFLoad: Sendable {
    /// Stops the load. An event that was already on its way may still be reported.
    let cancel: @Sendable () -> Void
}

/// Loads requests for the fronted domains from their fixed addresses.
///
/// A request for `https://e-hentai.org/…` is sent to `https://<address>/…` with `Host:
/// e-hentai.org`. The URL names an address, so the TLS handshake carries no server name, which
/// is what gets past SNI filtering. Before the handshake completes, and so before any byte of
/// the request is sent, the server's certificate is validated for the real domain.
final class DFLoader: Sendable {
    typealias Resolve = @Sendable (_ domain: String) -> String?
    typealias EvaluateTrust = @Sendable (_ trust: SecTrust, _ host: String) -> Bool

    static let live = DFLoader()

    private let resolve: Resolve
    private let cookieStorage: HTTPCookieStorage
    private let evaluateTrust: EvaluateTrust
    private let sessions = Mutex<[String: DFHostSession]>([:])

    /// - Parameters:
    ///   - resolve: The address to connect to for a domain, `nil` for domains that are not fronted.
    ///   - cookieStorage: Cookies sent with, and stored from, every load. A fronted request's
    ///     cookies belong to the domain, so the sessions that connect to the addresses handle none.
    ///   - evaluateTrust: Whether a certificate chain is valid for a domain.
    init(
        resolve: @escaping Resolve = DomainResolver.resolve(domain:),
        cookieStorage: HTTPCookieStorage = .shared,
        evaluateTrust: @escaping EvaluateTrust = DFTrust.evaluate
    ) {
        self.resolve = resolve
        self.cookieStorage = cookieStorage
        self.evaluateTrust = evaluateTrust
    }

    /// Whether `request` is for a fronted domain.
    func fronts(_ request: URLRequest) -> Bool {
        request.domain.flatMap(resolve) != nil
    }

    /// Starts loading `request`, which must be one this loader `fronts`.
    func load(_ request: URLRequest, onEvent: @escaping @Sendable (DFLoadEvent) -> Void) -> DFLoad {
        guard let domain = request.domain,
              let url = request.domainURL,
              let fronted = request.fronted(resolve: resolve, cookieStorage: cookieStorage)
        else {
            onEvent(.failed(URLError(.unsupportedURL)))
            return DFLoad {}
        }
        return session(for: domain).start(fronted, for: url, onEvent: onEvent)
    }

    private func session(for domain: String) -> DFHostSession {
        sessions.withLock { sessions in
            if let session = sessions[domain] { return session }
            let session = DFHostSession(host: domain, cookieStorage: cookieStorage, evaluateTrust: evaluateTrust)
            sessions[domain] = session
            return session
        }
    }
}
