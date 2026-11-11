import Dependencies
import EhCore
import EhModels
import EhNetworking
import Foundation
import Observation

/// The signed-in state of the app and the account upkeep that goes with it.
///
/// Login state lives in cookies, which are not observable, so this type keeps an observable
/// copy (`isLoggedIn`) and recomputes it whenever the session changes through it: login,
/// logout, account upkeep, or a screen reporting edited cookies with `cookiesDidChange()`.
/// One shared instance lives in `\.accountSession`.
@Observable public final class AccountSession {
    /// Whether the stored cookies form a signed-in session (legacy `didLogin` rules).
    public private(set) var isLoggedIn: Bool
    /// Bumped every time the cookies may have changed, including changes that keep
    /// `isLoggedIn` as it was (an `igneous` fetch), so screens showing cookies can reload them.
    public private(set) var cookieRevision = 0

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.cookieStore) private var cookies
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.userStore) private var userStore
    @ObservationIgnored @Dependency(\.database) private var database
    @ObservationIgnored @Dependency(\.imageCacheClient) private var imageCache
    @ObservationIgnored @Dependency(\.appLogger) private var logger

    /// The upkeep started by a login. Owned here rather than by the login screen, which is
    /// popped as soon as the login succeeds.
    @ObservationIgnored private(set) var loginUpkeep: Task<Void, Never>?

    // Nonisolated so the nonisolated `DependencyKey` can create the shared instance. Reading
    // the cookie jar is a cheap in-memory lookup; the backing storage is set directly
    // because the observation accessors are main-actor isolated.
    public nonisolated init() {
        @Dependency(\.cookieStore) var cookieStore
        _isLoggedIn = cookieStore.didLogin
    }

    /// Re-reads the cookies. Call after writing cookies anywhere other than through this type.
    public func cookiesDidChange() {
        cookieRevision += 1
        let didLogin = cookies.didLogin
        if didLogin != isLoggedIn {
            isLoggedIn = didLogin
        }
    }

    /// Account upkeep after launch or login. Does nothing when not logged in. Never throws:
    /// failures are logged and left for the next run.
    ///
    /// Fetches `igneous` first when ExHentai has credentials without it, because the
    /// remaining requests go to the selected host, which may be ExHentai. The favourite
    /// category names and the app's settings profile are then fetched concurrently.
    public func refresh() async {
        cookiesDidChange()
        guard isLoggedIn else { return }
        if cookies.shouldFetchIgneous {
            await fetchIgneous()
        }
        async let categories: Void = refreshFavoriteCategories()
        async let profile: Void = pinEhPandaProfile()
        _ = await (categories, profile)
    }

    /// Everything legacy does on logout: forgets the stored user, deletes every cookie, the
    /// stored image URLs and the image disk cache.
    public func logout() async {
        loginUpkeep?.cancel()
        loginUpkeep = nil
        userStore.clear()
        cookies.clearAll()
        cookiesDidChange()
        async let pages: Void = removeStoredImageURLs()
        async let images: Void = imageCache.clearDiskCache()
        _ = await (pages, images)
    }

    /// Call when a login (form or web) has stored its cookies: tidies them like launch does
    /// and starts the account upkeep.
    public func loginDidComplete() {
        cookies.removeYay()
        cookies.syncExCookies()
        cookies.fulfillAnotherHostField()
        cookiesDidChange()
        loginUpkeep?.cancel()
        loginUpkeep = Task { await refresh() }
    }

    /// Points the selected host's `sp` cookie at the settings profile `value`.
    public func selectProfile(_ value: Int) {
        let url = settings.galleryHost.url
        let text = String(value)
        guard cookies.cookie(named: CookieName.selectedProfile, for: url).rawValue != text else { return }
        cookies.setOrEditCookie(for: url, name: CookieName.selectedProfile, value: text)
    }
}

// MARK: Upkeep steps

private extension AccountSession {
    func fetchIgneous() async {
        do {
            try await client.fetchIgneous()
            // The image host needs the new cookie too; launch only copies it on the next run.
            cookies.syncExCookies()
            cookiesDidChange()
        } catch {
            report(error, "Fetching igneous")
        }
    }

    func refreshFavoriteCategories() async {
        do {
            userStore.updateFavoriteCategories(try await client.favoriteCategories())
        } catch {
            report(error, "Fetching favorite categories")
        }
    }

    /// Legacy `fetchEhProfileIndex`: browse with the "EhPanda" profile, creating it if missing.
    func pinEhPandaProfile() async {
        do {
            let response = try await client.verifyEhProfile()
            if let value = response.profileValue {
                selectProfile(value)
            } else if response.isProfileNotFound {
                let setting = try await client.ehProfile(action: .create, name: Self.profileName)
                if let value = setting.ehpandaProfile?.value {
                    selectProfile(value)
                }
            } else {
                logger.error("Found the EhPanda profile but failed to parse its value.", category: Self.logCategory)
            }
        } catch {
            report(error, "Verifying the EhPanda profile")
        }
    }

    func removeStoredImageURLs() async {
        do {
            // A cutoff in the distant future treats every gallery as not opened recently,
            // so every stored page goes.
            try await database.deleteExpiredPages(notOpenedWithin: 0, now: .distantFuture)
        } catch {
            report(error, "Removing stored image URLs")
        }
    }

    func report(_ error: any Error, _ step: String) {
        guard !(error is CancellationError) else { return }
        logger.error("\(step) failed: \(error)", category: Self.logCategory)
    }

    static let profileName = "EhPanda"
    static let logCategory = "Account"
}

// MARK: Dependency

// The key and accessor are nonisolated (the target defaults to the main actor) so the key
// path `\.accountSession` is `Sendable`, as `@Dependency` requires.
nonisolated private enum AccountSessionKey: DependencyKey {
    static let liveValue = AccountSession()
    static var testValue: AccountSession { AccountSession() }
    static var previewValue: AccountSession { AccountSession() }
}

nonisolated extension DependencyValues {
    /// The app's one `AccountSession`.
    public var accountSession: AccountSession {
        get { self[AccountSessionKey.self] }
        set { self[AccountSessionKey.self] = newValue }
    }
}
