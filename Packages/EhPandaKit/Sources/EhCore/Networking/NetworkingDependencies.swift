import Dependencies
import EhModels
import EhNetworking
import Foundation

// MARK: Live pieces

/// The app's one network stack: a single `URLSessionTransport` on the shared cookie jar, so
/// the client, the cookie store and the domain-fronting switch all act on the same sessions.
enum LiveNetwork {
    static let transport = URLSessionTransport(cookieStorage: .shared)

    /// The selected site, read on every call so a host switch applies to the next request.
    static let hostProvider = GalleryHostProvider(defaults: .standard)
}

// MARK: Cookie store

extension CookieStore: DependencyKey {
    /// The system cookie jar, which `URLSessionTransport` and web views also use.
    public static let liveValue = CookieStore(storage: .shared)

    /// A jar of its own that never persists anything: on Apple platforms a plain
    /// `HTTPCookieStorage()` is not the shared jar and silently drops what it is given, so
    /// tests cannot read or change the user's real cookies, and tests cannot leak cookies into
    /// each other through this value. A test that needs working cookies installs
    /// `CookieStore(storage: InMemoryCookieStorage())` from `EhTestSupport`.
    public static var testValue: CookieStore {
        CookieStore(storage: HTTPCookieStorage())
    }

    public static var previewValue: CookieStore { testValue }
}

extension DependencyValues {
    public var cookieStore: CookieStore {
        get { self[CookieStore.self] }
        set { self[CookieStore.self] = newValue }
    }
}

// MARK: Client

extension EhClient: DependencyKey {
    /// Built once from the shared transport (with retries) and `CookieStore.liveValue`. It
    /// does not read `\.cookieStore` because a live value is cached on first use, and an
    /// override active at that moment would stick to the client for good.
    public static let liveValue = EhClient(
        transport: RetryingTransport(LiveNetwork.transport),
        cookies: .liveValue,
        host: LiveNetwork.hostProvider.currentHost,
        onFailure: { failure in
            AppLogger.liveValue.warning(failure.description, category: "Network")
        }
    )

    /// Fails the test for any request, so a test that forgets to install a client with a
    /// `StubTransport` can never reach the network.
    public static var testValue: EhClient {
        EhClient(transport: UnimplementedTransport(), cookies: .testValue, host: { .ehentai })
    }

    public static var previewValue: EhClient {
        EhClient(transport: OfflineTransport(), cookies: .testValue, host: { .ehentai })
    }
}

extension DependencyValues {
    public var ehClient: EhClient {
        get { self[EhClient.self] }
        set { self[EhClient.self] = newValue }
    }
}

/// Reports an issue and fails every request.
struct UnimplementedTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        reportIssue(
            "Unimplemented: \\.ehClient sent \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "nil"). "
                + "Install an EhClient with a StubTransport."
        )
        throw URLError(.unsupportedURL)
    }
}

/// Fails every request quietly, for previews.
struct OfflineTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        throw URLError(.notConnectedToInternet)
    }
}
