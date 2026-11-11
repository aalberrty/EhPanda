import Foundation
import Synchronization

/// The live `HTTPTransport`, backed by its own `URLSession`s rather than `URLSession.shared`.
///
/// Domain fronting is switched with `isDomainFrontingEnabled` at any time. The transport keeps
/// two sessions built from the same configuration, one of which also routes requests through
/// `DFURLProtocol`, and each request picks one by reading a mutex-protected flag. Holders of the
/// transport therefore never need to be recreated, and requests already in flight finish on
/// the session they started on.
public final class URLSessionTransport: HTTPTransport {
    private let directSession: URLSession
    private let frontedSession: URLSession
    private let frontingEnabled: Mutex<Bool>

    /// - Parameters:
    ///   - cookieStorage: Cookies sent with and stored from every request.
    ///   - isDomainFrontingEnabled: Initial value of `isDomainFrontingEnabled`.
    public convenience init(cookieStorage: HTTPCookieStorage = .shared, isDomainFrontingEnabled: Bool = false) {
        self.init(
            configuration: Self.makeConfiguration(cookieStorage: cookieStorage),
            isDomainFrontingEnabled: isDomainFrontingEnabled
        )
    }

    /// Tests pass a configuration with their own `protocolClasses`.
    init(configuration: URLSessionConfiguration, isDomainFrontingEnabled: Bool) {
        // Sessions copy their configuration, so the two copies cannot affect each other.
        let direct = configuration.copy() as? URLSessionConfiguration ?? configuration
        let fronted = configuration.copy() as? URLSessionConfiguration ?? configuration
        fronted.setDomainFronting(true)
        directSession = URLSession(configuration: direct)
        frontedSession = URLSession(configuration: fronted)
        frontingEnabled = Mutex(isDomainFrontingEnabled)
    }

    deinit {
        directSession.finishTasksAndInvalidate()
        frontedSession.finishTasksAndInvalidate()
    }

    /// Whether new requests bypass SNI filtering through `DFURLProtocol`.
    public var isDomainFrontingEnabled: Bool {
        get { frontingEnabled.withLock { $0 } }
        set { frontingEnabled.withLock { $0 = newValue } }
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        if Task.isCancelled { throw URLError(.cancelled) }
        let session = currentSession
        let data: Data
        let response: URLResponse
        do {
            // The async API cancels the underlying `URLSessionTask` when the calling task is cancelled.
            (data, response) = try await session.data(for: request)
        } catch {
            throw URLError.normalized(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return HTTPResponse(data: data, response: httpResponse)
    }

    /// The session a request sent now would use.
    var currentSession: URLSession {
        isDomainFrontingEnabled ? frontedSession : directSession
    }

    /// The configuration both sessions start from.
    static func makeConfiguration(cookieStorage: HTTPCookieStorage) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = cookieStorage
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        // Gallery pages fan out to many image and preview requests on the same few hosts.
        configuration.httpMaximumConnectionsPerHost = 8
        return configuration
    }
}
