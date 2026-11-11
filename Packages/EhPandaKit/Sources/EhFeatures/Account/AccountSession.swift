import Dependencies
import EhCore
import EhNetworking
import Observation

// PLACEHOLDER: the account agent's `AccountSession` replaces this file at merge. It exists only
// so the shell compiles against the agreed API; `refresh()` does nothing here.

/// The signed-in account: login state and the upkeep that runs after launch or login.
@Observable
public final class AccountSession {
    @ObservationIgnored @Dependency(\.cookieStore) private var cookies

    nonisolated public init() {}

    public var isLoggedIn: Bool { cookies.didLogin }

    /// Account upkeep after launch or login; no-op when logged out; never throws.
    public func refresh() async {}

    public func logout() async {}
}

extension AccountSession: DependencyKey {
    nonisolated public static let liveValue = AccountSession()
    nonisolated public static var testValue: AccountSession { AccountSession() }
}

extension DependencyValues {
    nonisolated public var accountSession: AccountSession {
        get { self[AccountSession.self] }
        set { self[AccountSession.self] = newValue }
    }
}
