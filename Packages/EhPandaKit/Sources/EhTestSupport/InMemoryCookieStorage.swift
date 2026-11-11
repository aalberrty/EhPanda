import Foundation
import Synchronization

/// An `HTTPCookieStorage` that keeps cookies in memory, for tests.
///
/// `HTTPCookieStorage()` does not store anything on Apple platforms, and group-container
/// storages persist to disk, so tests use this instead. It implements the subset of the API
/// `CookieStore` relies on, with RFC 6265 domain and path matching. Unlike the system storage it
/// keeps expired cookies, so tests can observe how callers treat them.
public final class InMemoryCookieStorage: HTTPCookieStorage, @unchecked Sendable {
    // `@unchecked Sendable`: the only stored state is the mutex below.
    private let storage = Mutex<[HTTPCookie]>([])

    override public init() {
        super.init()
    }

    override public var cookies: [HTTPCookie]? {
        storage.withLock { $0 }
    }

    override public func setCookie(_ cookie: HTTPCookie) {
        storage.withLock { cookies in
            cookies.removeAll { Self.isSameCookie($0, cookie) }
            cookies.append(cookie)
        }
    }

    override public func deleteCookie(_ cookie: HTTPCookie) {
        storage.withLock { cookies in
            cookies.removeAll { Self.isSameCookie($0, cookie) }
        }
    }

    override public func removeCookies(since date: Date) {
        storage.withLock { $0.removeAll() }
    }

    override public func cookies(for url: URL) -> [HTTPCookie]? {
        guard let host = url.host?.lowercased() else { return nil }
        let path = url.path.isEmpty ? "/" : url.path
        return storage.withLock { cookies in
            cookies.filter { cookie in
                Self.domain(cookie.domain, matches: host)
                    && Self.path(cookie.path, matches: path)
                    && (!cookie.isSecure || url.scheme == "https")
            }
        }
    }

    override public func setCookies(_ cookies: [HTTPCookie], for url: URL?, mainDocumentURL: URL?) {
        cookies.forEach(setCookie)
    }

    private static func isSameCookie(_ lhs: HTTPCookie, _ rhs: HTTPCookie) -> Bool {
        lhs.name == rhs.name && lhs.domain.lowercased() == rhs.domain.lowercased() && lhs.path == rhs.path
    }

    /// A leading dot allows subdomains; otherwise the cookie is host-only.
    private static func domain(_ domain: String, matches host: String) -> Bool {
        let domain = domain.lowercased()
        if domain.hasPrefix(".") {
            let bare = String(domain.dropFirst())
            return host == bare || host.hasSuffix(domain)
        }
        return host == domain
    }

    private static func path(_ cookiePath: String, matches requestPath: String) -> Bool {
        if cookiePath == requestPath { return true }
        guard requestPath.hasPrefix(cookiePath) else { return false }
        return cookiePath.hasSuffix("/") || requestPath.dropFirst(cookiePath.count).hasPrefix("/")
    }
}
