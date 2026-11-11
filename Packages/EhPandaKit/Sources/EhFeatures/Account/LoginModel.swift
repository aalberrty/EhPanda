import Dependencies
import EhCore
import EhModels
import EhNetworking
import Foundation
import Observation

/// The login screen: username / password login and the web login.
@Observable public final class LoginModel {
    nonisolated public enum Field: Hashable, Sendable {
        case username
        case password
    }

    public var username = ""
    public var password = ""
    public var focusedField: Field?
    public private(set) var loginState: LoadingState = .idle
    /// Bumped when a login attempt starts, for the start haptic.
    public private(set) var attemptCount = 0
    /// Set once a login succeeded; the screen then closes.
    public private(set) var didLogin = false
    /// The forum login page shown in a web view, when presented.
    public var webLoginURL: URL?

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.cookieStore) private var cookies
    @ObservationIgnored @Dependency(\.accountSession) private var session
    @ObservationIgnored @Dependency(\.settings) private var settings

    public init() {}

    public var isLoginDisabled: Bool {
        username.isEmpty || password.isEmpty
    }

    /// The web login opens a page directly, which domain fronting cannot route.
    public var isWebLoginAvailable: Bool {
        !settings.bypassesSNIFiltering
    }

    /// Return on the username field moves to the password; return on the password logs in.
    public func submit() async {
        if focusedField == .username {
            focusedField = .password
        } else {
            await login()
        }
    }

    public func login() async {
        guard !isLoginDisabled, !loginState.isLoading else { return }
        focusedField = nil
        loginState = .loading
        attemptCount += 1
        do {
            try await client.login(username: username, password: password)
            succeed()
        } catch is CancellationError {
            loginState = .idle
        } catch {
            loginState = .failed(error as? AppError ?? .unknown)
            session.cookiesDidChange()
        }
    }

    public func presentWebLogin() {
        guard isWebLoginAvailable else { return }
        webLoginURL = EhEndpoints.webLogin
    }

    /// The web view reached the forum's post-login page: adopts the login cookies it holds.
    public func webLoginDidFinish(cookies webCookies: [WebCookie]) {
        webLoginURL = nil
        for cookie in webCookies {
            guard CookieName.loginNames.contains(cookie.name), !cookie.value.isEmpty,
                  let host = cookie.host
            else { continue }
            for url in host.cookieURLs {
                cookies.setOrEditCookie(for: url, name: cookie.name, value: cookie.value)
            }
        }
        if cookies.didLogin {
            succeed()
        } else {
            loginState = .failed(.unknown)
            session.cookiesDidChange()
        }
    }

    private func succeed() {
        loginState = .idle
        session.loginDidComplete()
        didLogin = true
    }
}

/// A cookie read from the web view's store.
nonisolated public struct WebCookie: Sendable, Hashable {
    public var name: String
    public var value: String
    public var domain: String

    public init(name: String, value: String, domain: String) {
        self.name = name
        self.value = value
        self.domain = domain
    }

    /// The site the cookie belongs to; forum cookies (`.e-hentai.org`) count as E-Hentai.
    var host: GalleryHost? {
        let domain = domain.lowercased()
        if domain == "exhentai.org" || domain.hasSuffix(".exhentai.org") { return .exhentai }
        if domain == "e-hentai.org" || domain.hasSuffix(".e-hentai.org") { return .ehentai }
        return nil
    }
}

extension CookieName {
    /// The three cookies that make up a login.
    static var loginNames: Set<String> { [igneous, ipbMemberId, ipbPassHash] }
}
