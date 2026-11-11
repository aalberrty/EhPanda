@testable import EhCore
import EhModels
import Foundation
import Testing

@MainActor @Suite struct UserStoreTests {
    private static let day = Date(timeIntervalSinceReferenceDate: 700_000_000)

    private func reload(_ store: UserStore, _ storage: PreferenceStorage) -> UserStore {
        store.waitForPendingWrites()
        return UserStore(storage: storage)
    }

    @Test func emptyDefaultsLoadAnEmptyUser() {
        #expect(UserStore(storage: .ephemeral()).user == User())
    }

    @Test func applyPersistsTheWholeUser() {
        let storage = PreferenceStorage.ephemeral()
        let store = UserStore(storage: storage)
        let user = User(
            displayName: "panda", avatarURL: URL(string: "https://e-hentai.org/a.png"), apikey: "key",
            credits: "1,000", galleryPoints: "2,000",
            greeting: Greeting(gainedEXP: 10, updateTime: Self.day), favoriteCategories: [0: "Mine"]
        )
        store.apply(user)
        #expect(store.user == user)
        #expect(reload(store, storage).user == user)
        #expect(storage.contains("user"))
    }

    @Test func updateGreetingKeepsTheNewestOne() {
        let storage = PreferenceStorage.ephemeral()
        let store = UserStore(storage: storage)
        let first = Greeting(gainedEXP: 1, updateTime: Self.day)
        store.updateGreeting(first)
        #expect(store.greeting == first)

        store.updateGreeting(Greeting(gainedEXP: 2, updateTime: Self.day.addingTimeInterval(-60)))
        #expect(store.greeting == first)

        let newer = Greeting(gainedEXP: 3, updateTime: Self.day.addingTimeInterval(86_400))
        store.updateGreeting(newer)
        #expect(store.greeting == newer)
        #expect(reload(store, storage).greeting == newer)
    }

    @Test func updateGreetingIgnoresAGreetingWithoutDate() {
        let store = UserStore(storage: .ephemeral())
        store.updateGreeting(Greeting(gainedEXP: 1))
        #expect(store.greeting == nil)
    }

    @Test func galleryFundsUpdateMemoryAndStorage() {
        let storage = PreferenceStorage.ephemeral()
        let store = UserStore(storage: storage)
        store.apply(User(displayName: "panda", greeting: Greeting(updateTime: Self.day)))
        store.updateGalleryFunds(galleryPoints: "500", credits: "700")
        #expect(store.galleryPoints == "500" && store.credits == "700")
        // A later, unrelated update must not overwrite the funds (legacy bug).
        store.updateFavoriteCategories([1: "Stories"])
        let reloaded = reload(store, storage)
        #expect(reloaded.galleryPoints == "500" && reloaded.credits == "700")
        #expect(reloaded.displayName == "panda" && reloaded.greeting?.updateTime == Self.day)
        #expect(reloaded.favoriteCategories == [1: "Stories"])
    }

    @Test func favoriteCategoriesAndAPIKey() {
        let storage = PreferenceStorage.ephemeral()
        let store = UserStore(storage: storage)
        store.updateFavoriteCategories([0: "Favorites 0", 2: "Stories"])
        store.updateAPIKey("abc")
        #expect(store.customFavoriteCategoryName(index: 0) == nil)
        #expect(store.customFavoriteCategoryName(index: 2) == "Stories")
        let reloaded = reload(store, storage)
        #expect(reloaded.apikey == "abc")
        #expect(reloaded.favoriteCategories == [0: "Favorites 0", 2: "Stories"])
    }

    @Test func clearForgetsTheUser() {
        let storage = PreferenceStorage.ephemeral()
        let store = UserStore(storage: storage)
        store.apply(User(displayName: "panda", apikey: "abc", favoriteCategories: [0: "x"]))
        store.clear()
        #expect(store.user == User())
        #expect(reload(store, storage).user == User())
    }

    @Test func unreadableStoredUserFallsBackToEmpty() {
        let storage = PreferenceStorage.ephemeral()
        storage.defaults.set(json(#"{"displayName": 42}"#), forKey: "user")
        #expect(UserStore(storage: storage).user == User())
    }

    @Test func observationIsPerField() {
        let store = UserStore(storage: .ephemeral())
        #expect(!changeIsObserved(reading: { _ = store.favoriteCategories }, after: {
            store.updateGreeting(Greeting(updateTime: Self.day))
        }))
        #expect(!changeIsObserved(reading: { _ = store.displayName }, after: {
            store.updateGalleryFunds(galleryPoints: "1", credits: "2")
        }))
        #expect(changeIsObserved(reading: { _ = store.favoriteCategories }, after: {
            store.updateFavoriteCategories([0: "x"])
        }))
        #expect(changeIsObserved(reading: { _ = store.credits }, after: { store.clear() }))
    }
}
