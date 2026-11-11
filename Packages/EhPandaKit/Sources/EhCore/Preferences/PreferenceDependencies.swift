import Dependencies
import Foundation

// The stores are main-actor classes, so they are `Sendable`; their nonisolated initializers
// let these nonisolated `DependencyKey` requirements create them from any context.
// Live values use `UserDefaults.standard`; test and preview values each get private, empty,
// in-memory defaults (see `PreferenceStorage.ephemeral()`).

enum SettingsStoreKey: DependencyKey {
    static let liveValue = SettingsStore(defaults: .standard)
    static var testValue: SettingsStore { SettingsStore(storage: .ephemeral()) }
    static var previewValue: SettingsStore { SettingsStore(storage: .ephemeral()) }
}

enum FilterStoreKey: DependencyKey {
    static let liveValue = FilterStore(defaults: .standard)
    static var testValue: FilterStore { FilterStore(storage: .ephemeral()) }
    static var previewValue: FilterStore { FilterStore(storage: .ephemeral()) }
}

enum UserStoreKey: DependencyKey {
    static let liveValue = UserStore(defaults: .standard)
    static var testValue: UserStore { UserStore(storage: .ephemeral()) }
    static var previewValue: UserStore { UserStore(storage: .ephemeral()) }
}

extension DependencyValues {
    public var settings: SettingsStore {
        get { self[SettingsStoreKey.self] }
        set { self[SettingsStoreKey.self] = newValue }
    }

    public var filterStore: FilterStore {
        get { self[FilterStoreKey.self] }
        set { self[FilterStoreKey.self] = newValue }
    }

    public var userStore: UserStore {
        get { self[UserStoreKey.self] }
        set { self[UserStoreKey.self] = newValue }
    }
}
