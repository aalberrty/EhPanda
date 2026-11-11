import EhModels
import Foundation
import Observation

/// The three gallery filters (`FilterRange`), each its own observable property, persisted as
/// JSON under one key per range: `"filters.search"`, `"filters.global"`, `"filters.watched"`.
///
/// Every change is validated the way legacy `FiltersReducer` did (`Filter.fixInvalidData()`
/// clears page bounds that are not whole numbers; `Filter` itself keeps low-power and
/// downvoted tags exclusive).
@MainActor @Observable
public final class FilterStore {
    @ObservationIgnored private let writer: JSONPreferenceWriter

    public var searchFilter: Filter { didSet { filterDidChange(.search, from: oldValue) } }
    public var globalFilter: Filter { didSet { filterDidChange(.global, from: oldValue) } }
    public var watchedFilter: Filter { didSet { filterDidChange(.watched, from: oldValue) } }

    /// Loads the filters from `defaults`; a missing or unreadable one starts as `Filter()`.
    public nonisolated convenience init(defaults: UserDefaults) {
        self.init(storage: PreferenceStorage(defaults))
    }

    nonisolated init(storage: PreferenceStorage) {
        writer = JSONPreferenceWriter(storage: storage)
        // See `SettingsStore.init(storage:)` for why the backing storage is set directly.
        _searchFilter = Self.load(.search, from: storage)
        _globalFilter = Self.load(.global, from: storage)
        _watchedFilter = Self.load(.watched, from: storage)
    }

    public subscript(range: FilterRange) -> Filter {
        get {
            switch range {
            case .search: searchFilter
            case .global: globalFilter
            case .watched: watchedFilter
            }
        }
        set {
            switch range {
            case .search: searchFilter = newValue
            case .global: globalFilter = newValue
            case .watched: watchedFilter = newValue
            }
        }
    }

    /// Restores `range` to `Filter()`. Legacy: `FiltersReducer` `.resetFilters`.
    public func reset(_ range: FilterRange) {
        self[range] = Filter()
    }

    /// Blocks until queued writes have reached `UserDefaults`. Tests only.
    func waitForPendingWrites() {
        writer.waitUntilIdle()
    }

    nonisolated static func key(for range: FilterRange) -> String {
        switch range {
        case .search: "filters.search"
        case .global: "filters.global"
        case .watched: "filters.watched"
        }
    }

    private nonisolated static func load(_ range: FilterRange, from storage: PreferenceStorage) -> Filter {
        var filter = JSONPreferenceWriter.read(Filter.self, forKey: key(for: range), from: storage) ?? Filter()
        filter.fixInvalidData()
        return filter
    }

    private func filterDidChange(_ range: FilterRange, from oldValue: Filter) {
        var fixed = self[range]
        fixed.fixInvalidData()
        if fixed != self[range] {
            // Re-enters `didSet`, which persists the fixed value.
            self[range] = fixed
            return
        }
        guard fixed != oldValue else { return }
        writer.write(fixed, forKey: Self.key(for: range))
    }
}
