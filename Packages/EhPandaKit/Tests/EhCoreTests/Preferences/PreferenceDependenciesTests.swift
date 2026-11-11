import Dependencies
@testable import EhCore
import Foundation
import Testing

@MainActor @Suite struct PreferenceDependenciesTests {
    @Test func testValuesUseThrowawayDefaults() {
        @Dependency(\.settings) var settings
        @Dependency(\.filterStore) var filters
        @Dependency(\.userStore) var user
        #expect(settings.storage.defaults !== UserDefaults.standard)
        #expect(settings.setting == .init())
        settings.showsTagsInList = true
        #expect(UserDefaults.standard.object(forKey: "settings.showsTagsInList") == nil)
        #expect(filters.searchFilter == .init())
        #expect(user.user == .init())
    }

    @Test func dependencyIsSharedWithinAContext() {
        @Dependency(\.settings) var first
        @Dependency(\.settings) var second
        first.prefetchLimit = 18
        #expect(second.prefetchLimit == 18)
    }

    @Test func storesCanBeOverridden() {
        let store = SettingsStore(storage: .ephemeral())
        store.prefetchLimit = 6
        withDependencies {
            $0.settings = store
        } operation: {
            @Dependency(\.settings) var settings
            #expect(settings.prefetchLimit == 6)
        }
    }

    @Test func ephemeralSuitesAreIndependent() {
        let first = PreferenceStorage.ephemeral()
        let second = PreferenceStorage.ephemeral()
        first.defaults.set(true, forKey: "flag")
        #expect(second.defaults.object(forKey: "flag") == nil)
    }
}
