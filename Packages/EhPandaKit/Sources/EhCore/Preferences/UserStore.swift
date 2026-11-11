import EhModels
import Foundation
import Observation

/// The signed-in user's profile, persisted as JSON under `"user"`.
///
/// Each field is its own observable property so, for example, the favourites tab re-renders
/// when the folder names change but not when the greeting arrives. Fields change only through
/// the mutators below, each of which persists once. Being the only copy of the user, this store
/// cannot repeat the legacy bug where archive funds and the greeting were written to storage
/// behind the in-memory user's back and later overwritten by it.
@MainActor @Observable
public final class UserStore {
    @ObservationIgnored private let writer: JSONPreferenceWriter

    public private(set) var displayName: String?
    public private(set) var avatarURL: URL?
    public private(set) var apikey: String?
    public private(set) var credits: String?
    public private(set) var galleryPoints: String?
    public private(set) var greeting: Greeting?
    /// The user's names for favourite folders 0–9.
    public private(set) var favoriteCategories: [Int: String]?

    public nonisolated convenience init(defaults: UserDefaults) {
        self.init(storage: PreferenceStorage(defaults))
    }

    nonisolated init(storage: PreferenceStorage) {
        writer = JSONPreferenceWriter(storage: storage)
        let user = JSONPreferenceWriter.read(User.self, forKey: Self.key, from: storage) ?? User()
        // See `SettingsStore.init(storage:)` for why the backing storage is set directly.
        _displayName = user.displayName
        _avatarURL = user.avatarURL
        _apikey = user.apikey
        _credits = user.credits
        _galleryPoints = user.galleryPoints
        _greeting = user.greeting
        _favoriteCategories = user.favoriteCategories
    }

    nonisolated static let key = "user"

    /// The whole profile as one value. Reading it observes every field.
    public var user: User {
        User(
            displayName: displayName, avatarURL: avatarURL, apikey: apikey,
            credits: credits, galleryPoints: galleryPoints,
            greeting: greeting, favoriteCategories: favoriteCategories
        )
    }

    /// The user's own name for favourite folder `index`, or `nil` for the site's default name.
    public func customFavoriteCategoryName(index: Int) -> String? {
        guard let name = favoriteCategories?[index], name != "Favorites \(index)" else { return nil }
        return name
    }

    // MARK: Mutators

    /// Stores a greeting if it is the first one or newer than the stored one; a greeting without
    /// an update time is ignored. Legacy: `SettingReducer.State.setGreeting(_:)`.
    public func updateGreeting(_ greeting: Greeting) {
        guard let newDate = greeting.updateTime else { return }
        update { user in
            if let stored = user.greeting {
                if let storedDate = stored.updateTime, storedDate < newDate {
                    user.greeting = greeting
                }
            } else {
                user.greeting = greeting
            }
        }
    }

    /// Legacy: `DatabaseClient.updateGalleryFunds(galleryPoints:credits:)` (from Archives).
    public func updateGalleryFunds(galleryPoints: String, credits: String) {
        update { user in
            user.galleryPoints = galleryPoints
            user.credits = credits
        }
    }

    /// Legacy: `SettingReducer` `.fetchFavoriteCategoriesDone`.
    public func updateFavoriteCategories(_ categories: [Int: String]) {
        update { $0.favoriteCategories = categories }
    }

    public func updateAPIKey(_ apikey: String) {
        update { $0.apikey = apikey }
    }

    /// Replaces the whole profile (legacy import, tests).
    public func apply(_ user: User) {
        update { $0 = user }
    }

    /// Forgets the profile on logout. Legacy: `SettingReducer` `.account(.onLogoutConfirmButtonTapped)`.
    public func clear() {
        update { $0 = User() }
    }

    /// Blocks until queued writes have reached `UserDefaults`. Tests only.
    func waitForPendingWrites() {
        writer.waitUntilIdle()
    }

    /// Applies `change` to the current profile, assigns only the fields that changed (so
    /// observers of the others are not invalidated) and persists once if anything changed.
    private func update(_ change: (inout User) -> Void) {
        let old = user
        var new = old
        change(&new)
        guard new != old else { return }
        if new.displayName != old.displayName { displayName = new.displayName }
        if new.avatarURL != old.avatarURL { avatarURL = new.avatarURL }
        if new.apikey != old.apikey { apikey = new.apikey }
        if new.credits != old.credits { credits = new.credits }
        if new.galleryPoints != old.galleryPoints { galleryPoints = new.galleryPoints }
        if new.greeting != old.greeting { greeting = new.greeting }
        if new.favoriteCategories != old.favoriteCategories { favoriteCategories = new.favoriteCategories }
        writer.write(new, forKey: Self.key)
    }
}
