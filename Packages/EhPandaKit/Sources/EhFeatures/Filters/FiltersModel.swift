import Dependencies
import EhCore
import EhModels
import Observation

/// The Filters sheet: edits one of the three filters in `FilterStore`. Every change is saved
/// at once; open lists are not reloaded, their next load uses the new filter.
@Observable
public final class FiltersModel {
    /// A page-range field.
    public enum Bound: Hashable, Sendable {
        case lower
        case upper
    }

    /// The range being edited. Opens on the range of the list that presented the sheet.
    public var range: FilterRange
    public var focusedBound: Bound?
    public var isResetConfirmationPresented = false

    @ObservationIgnored @Dependency(\.filterStore) private var filterStore

    public init(range: FilterRange) {
        self.range = range
    }

    /// The edited filter, read from and written to the store.
    public var filter: Filter {
        get { filterStore[range] }
        set { filterStore[range] = newValue }
    }

    /// The categories the grid shows, in the site's order.
    public static let categories = Category.allFiltersCases

    /// Excluded categories are left out of results (legacy: dimmed tiles).
    public func isExcluded(_ category: Category) -> Bool {
        guard let keyPath = Self.keyPath(for: category) else { return false }
        return filter[keyPath: keyPath]
    }

    public func toggleExclusion(of category: Category) {
        guard let keyPath = Self.keyPath(for: category) else { return }
        filter[keyPath: keyPath].toggle()
    }

    public func presentResetConfirmation() {
        isResetConfirmationPresented = true
    }

    public func reset() {
        isResetConfirmationPresented = false
        filterStore.reset(range)
    }

    /// The pages-range switch cannot change while a bound is being typed.
    public var isPageRangeToggleDisabled: Bool { focusedBound != nil }

    /// Return in the lower field moves to the upper one; return in the upper one ends editing.
    public func submitBound() {
        switch focusedBound {
        case .lower: focusedBound = .upper
        case .upper, nil: focusedBound = nil
        }
    }

    nonisolated static func keyPath(for category: Category) -> WritableKeyPath<Filter, Bool>? {
        switch category {
        case .doujinshi: \.doujinshi
        case .manga: \.manga
        case .artistCG: \.artistCG
        case .gameCG: \.gameCG
        case .western: \.western
        case .nonH: \.nonH
        case .imageSet: \.imageSet
        case .cosplay: \.cosplay
        case .asianPorn: \.asianPorn
        case .misc: \.misc
        case .private: nil
        }
    }
}
