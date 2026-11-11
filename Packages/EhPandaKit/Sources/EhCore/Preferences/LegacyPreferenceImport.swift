import EhModels
import Foundation

/// The raw JSON blobs of the legacy Core Data `AppEnvMO` row, exactly as stored.
public struct LegacyPreferenceBlobs: Sendable {
    public var setting: Data?
    public var user: Data?
    public var searchFilter: Data?
    public var globalFilter: Data?
    public var watchedFilter: Data?

    public init(
        setting: Data? = nil, user: Data? = nil,
        searchFilter: Data? = nil, globalFilter: Data? = nil, watchedFilter: Data? = nil
    ) {
        self.setting = setting
        self.user = user
        self.searchFilter = searchFilter
        self.globalFilter = globalFilter
        self.watchedFilter = watchedFilter
    }
}

/// Parts of the legacy preferences.
public struct LegacyPreferenceParts: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let setting = Self(rawValue: 1 << 0)
    public static let user = Self(rawValue: 1 << 1)
    public static let searchFilter = Self(rawValue: 1 << 2)
    public static let globalFilter = Self(rawValue: 1 << 3)
    public static let watchedFilter = Self(rawValue: 1 << 4)

    public static let all: Self = [.setting, .user, .searchFilter, .globalFilter, .watchedFilter]

    static func filter(_ range: FilterRange) -> Self {
        switch range {
        case .search: .searchFilter
        case .global: .globalFilter
        case .watched: .watchedFilter
        }
    }
}

public struct LegacyPreferenceImportReport: Sendable, Equatable {
    /// Parts that decoded and were applied to the stores.
    public var imported: LegacyPreferenceParts = []
    /// Parts that were present but could not be decoded; the stores keep their values.
    public var failed: LegacyPreferenceParts = []
    // Parts in neither set were absent (nil).
}

extension LegacyPreferenceBlobs {
    /// Decodes whatever it can off the main actor and applies it to the stores.
    ///
    /// Safe on a fresh install (all blobs nil: nothing changes) and part by part: a corrupt
    /// blob never prevents the others from importing. Run it once, preferably after
    /// `SettingsStore.registerDefaultListDisplayMode(_:)` so a blob without a display mode
    /// keeps the device default; an imported display mode is stored either way.
    ///
    /// Two settings keep their current value when the store already has one, matching legacy:
    /// - `galleryHost`: legacy let the `"galleryHost"` `UserDefaults` key override the blob at
    ///   launch, and that key is the one the store uses.
    /// - `listDisplayMode`, when the blob has no valid value for it: legacy then fell back to its
    ///   device-dependent default, which the app has registered on the store.
    @MainActor
    public func apply(
        to settings: SettingsStore, filters: FilterStore, user userStore: UserStore
    ) async -> LegacyPreferenceImportReport {
        let decoded = await decode()
        var report = LegacyPreferenceImportReport()

        func record(_ part: LegacyPreferenceParts, present: Bool, imported: Bool) {
            if imported {
                report.imported.insert(part)
            } else if present {
                report.failed.insert(part)
            }
        }

        if var setting = decoded.setting {
            if settings.hasStoredValue(for: .galleryHost) {
                setting.galleryHost = settings.galleryHost
            }
            if !decoded.settingHasListDisplayMode {
                setting.listDisplayMode = settings.listDisplayMode
            }
            settings.apply(setting)
            if decoded.settingHasListDisplayMode {
                // `apply` skips a value equal to the current one; store it anyway so a later
                // `registerDefaultListDisplayMode` cannot replace the imported choice.
                settings.storeListDisplayMode()
            }
        }
        record(.setting, present: self.setting != nil, imported: decoded.setting != nil)

        if let user = decoded.user {
            userStore.apply(user)
        }
        record(.user, present: self.user != nil, imported: decoded.user != nil)

        for range in FilterRange.allCases {
            if let filter = decoded.filters[range] {
                filters[range] = filter
            }
            record(.filter(range), present: blob(for: range) != nil, imported: decoded.filters[range] != nil)
        }
        return report
    }

    private func blob(for range: FilterRange) -> Data? {
        switch range {
        case .search: searchFilter
        case .global: globalFilter
        case .watched: watchedFilter
        }
    }

    private struct Decoded: Sendable {
        var setting: Setting?
        var settingHasListDisplayMode = false
        var user: User?
        var filters: [FilterRange: Filter] = [:]
    }

    /// JSON decoding stays off the main actor (performance rule 1).
    @concurrent
    private func decode() async -> Decoded {
        var decoded = Decoded()
        // `Setting` and `Filter` decode tolerantly (any field may be missing or wrong), so only
        // a blob that is not a JSON object at all counts as corrupt.
        if let object = Self.jsonObject(setting), let setting {
            decoded.setting = try? JSONDecoder().decode(Setting.self, from: setting)
            decoded.settingHasListDisplayMode = (object["listDisplayMode"] as? Int)
                .flatMap(ListDisplayMode.init(rawValue:)) != nil
        }
        if let user {
            decoded.user = try? JSONDecoder().decode(User.self, from: user)
        }
        for range in FilterRange.allCases {
            if Self.jsonObject(blob(for: range)) != nil, let data = blob(for: range) {
                decoded.filters[range] = try? JSONDecoder().decode(Filter.self, from: data)
            }
        }
        return decoded
    }

    private static func jsonObject(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
