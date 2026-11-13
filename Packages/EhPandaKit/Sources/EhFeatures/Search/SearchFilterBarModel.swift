import Dependencies
import EhCore
import EhModels
import Observation

/// The search filter as the Search tab's chips: a minimum rating, the ten categories and the
/// number of active filters shown on the Filters button.
///
/// The chips edit `FilterStore.searchFilter`, the same filter the Filters sheet edits, and every
/// change is saved at once. Like the sheet, they start no request: the filter is set before a
/// query is sent, and the next search uses it. Rapid toggling therefore cannot load any page.
@Observable
public final class SearchFilterBarModel {
    /// The minimum ratings the site accepts.
    nonisolated public static let ratings = Array(2...5)

    @ObservationIgnored @Dependency(\.filterStore) private var filterStore

    public init() {}

    private var filter: Filter {
        get { filterStore.searchFilter }
        set { filterStore.searchFilter = newValue }
    }

    /// The minimum rating searches use, or `nil` when they use none.
    public var minimumRating: Int? {
        filter.appliedMinimumRating
    }

    /// Sets the minimum rating, or turns it off for `nil`. A rating only applies with the
    /// sheet's advanced settings on, so choosing one turns them on too (with the site's
    /// defaults, which change nothing else); turning it off leaves them as they are.
    public func setMinimumRating(_ rating: Int?) {
        var filter = filter
        if let rating, Self.ratings.contains(rating) {
            filter.advanced = true
            filter.minRatingActivated = true
            filter.minRating = rating
        } else {
            filter.minRatingActivated = false
        }
        self.filter = filter
    }

    /// The switch in the rating menu: on applies the rating last chosen (2 by default).
    public func setMinimumRatingOn(_ isOn: Bool) {
        setMinimumRating(isOn ? filter.minRating : nil)
    }

    /// The categories in the site's order, each with whether results include it.
    public var categories: [SearchCategoryChip] {
        let filter = filter
        return FiltersModel.categories.map { category in
            SearchCategoryChip(category: category, isIncluded: !filter.excludes(category))
        }
    }

    /// Includes an excluded category or excludes an included one.
    public func toggle(_ category: Category) {
        guard let keyPath = FiltersModel.keyPath(for: category) else { return }
        filter[keyPath: keyPath].toggle()
    }

    /// How many filters change the results, as the Filters button's badge counts them.
    public var activeFilterCount: Int {
        filter.activeFilterCount
    }
}

/// A category chip: the category and whether results include it.
nonisolated public struct SearchCategoryChip: Hashable, Identifiable, Sendable {
    public let category: Category
    public let isIncluded: Bool

    public var id: Category { category }

    public init(category: Category, isIncluded: Bool) {
        self.category = category
        self.isIncluded = isIncluded
    }
}

nonisolated extension Filter {
    /// The minimum rating the site receives (see `FilterQuery`), or `nil`.
    var appliedMinimumRating: Int? {
        guard advanced, minRatingActivated, SearchFilterBarModel.ratings.contains(minRating) else { return nil }
        return minRating
    }

    func excludes(_ category: Category) -> Bool {
        guard let keyPath = FiltersModel.keyPath(for: category) else { return false }
        return self[keyPath: keyPath]
    }

    /// One per control of the Filters sheet whose setting reaches the site and differs from
    /// the default: the category grid (only when it leaves some but not all categories out,
    /// as the site ignores the other two), the minimum rating, the pages range, and each
    /// advanced switch. Advanced settings count only while they are on, as only then are they sent.
    var activeFilterCount: Int {
        let excludedCount = Category.allFiltersCases.filter(excludes).count
        var count = (1..<Category.allFiltersCases.count).contains(excludedCount) ? 1 : 0
        guard advanced else { return count }
        if appliedMinimumRating != nil { count += 1 }
        if pageRangeActivated, Int(pageLowerBound) != nil || Int(pageUpperBound) != nil { count += 1 }
        let defaults = Filter()
        let switches: [KeyPath<Filter, Bool>] = [
            \.galleryName, \.galleryTags, \.galleryDesc, \.torrentFilenames, \.onlyWithTorrents,
            \.lowPowerTags, \.downvotedTags, \.expungedGalleries,
            \.disableLanguage, \.disableUploader, \.disableTags
        ]
        count += switches.filter { self[keyPath: $0] != defaults[keyPath: $0] }.count
        return count
    }
}
