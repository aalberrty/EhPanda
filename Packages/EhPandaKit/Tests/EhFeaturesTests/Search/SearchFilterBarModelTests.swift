@testable import EhFeatures
import EhModels
import Testing

@Suite struct SearchFilterBarModelTests {
    @Test func chipsEditTheSearchFilterTheSheetEdits() throws {
        let env = try ListTestEnvironment()
        let model = env.make { SearchFilterBarModel() }
        let sheet = env.make { FiltersModel(range: .search) }

        model.toggle(.manga)
        #expect(env.filterStore.searchFilter.manga)
        #expect(sheet.isExcluded(.manga))
        #expect(!env.filterStore.globalFilter.manga)

        sheet.toggleExclusion(of: .western)
        #expect(model.categories.first { $0.category == .western }?.isIncluded == false)

        model.toggle(.manga)
        #expect(!env.filterStore.searchFilter.manga)
    }

    @Test func categoriesFollowTheSitesOrderWithoutPrivate() throws {
        let env = try ListTestEnvironment()
        env.filterStore.searchFilter.cosplay = true
        let model = env.make { SearchFilterBarModel() }

        #expect(model.categories.map(\.category) == Category.allFiltersCases)
        #expect(model.categories.filter { !$0.isIncluded }.map(\.category) == [.cosplay])
        model.toggle(.private)
        #expect(model.categories.allSatisfy { $0.category != .private })
    }

    @Test func choosingARatingTurnsOnTheAdvancedSettingsItNeeds() throws {
        let env = try ListTestEnvironment()
        let model = env.make { SearchFilterBarModel() }
        #expect(model.minimumRating == nil)

        model.setMinimumRating(4)

        let filter = env.filterStore.searchFilter
        #expect(model.minimumRating == 4)
        #expect(filter.advanced && filter.minRatingActivated && filter.minRating == 4)
        // The advanced switches keep the site's defaults, so only the rating is new.
        #expect(filter.galleryName && filter.galleryTags && !filter.galleryDesc)

        model.setMinimumRating(nil)
        #expect(model.minimumRating == nil)
        #expect(!env.filterStore.searchFilter.minRatingActivated)
        #expect(env.filterStore.searchFilter.advanced)

        model.setMinimumRating(9)
        #expect(model.minimumRating == nil)
    }

    @Test func theRatingSwitchRestoresTheLastRating() throws {
        let env = try ListTestEnvironment()
        let model = env.make { SearchFilterBarModel() }

        model.setMinimumRatingOn(true)
        #expect(model.minimumRating == 2)
        model.setMinimumRating(5)
        model.setMinimumRatingOn(false)
        #expect(model.minimumRating == nil)
        model.setMinimumRatingOn(true)
        #expect(model.minimumRating == 5)
    }

    @Test func aRatingSetWithAdvancedSettingsOffIsNotApplied() throws {
        let env = try ListTestEnvironment()
        env.filterStore.searchFilter.minRatingActivated = true
        env.filterStore.searchFilter.minRating = 3
        let model = env.make { SearchFilterBarModel() }

        #expect(model.minimumRating == nil)
        #expect(model.activeFilterCount == 0)
        env.filterStore.searchFilter.advanced = true
        #expect(model.minimumRating == 3)
        #expect(model.activeFilterCount == 1)
    }

    @Test func activeCountMatchesTheMockup() throws {
        let env = try ListTestEnvironment()
        let model = env.make { SearchFilterBarModel() }
        #expect(model.activeFilterCount == 0)

        model.setMinimumRating(4)
        model.toggle(.manga)

        #expect(model.activeFilterCount == 2)
    }

    @Test func categoriesCountOnceAndOnlyWhenTheSiteFiltersByThem() {
        var filter = Filter()
        filter.manga = true
        filter.western = true
        #expect(filter.activeFilterCount == 1)

        for category in FiltersModel.categories {
            if let keyPath = FiltersModel.keyPath(for: category) { filter[keyPath: keyPath] = true }
        }
        // Every category left out is the same as none: the site applies no category filter.
        #expect(filter.activeFilterCount == 0)
    }

    @Test func advancedSettingsCountEachChangedControlWhileOn() {
        var filter = Filter()
        filter.galleryDesc = true
        filter.disableTags = true
        filter.pageRangeActivated = true
        filter.pageLowerBound = "10"
        #expect(filter.activeFilterCount == 0)

        filter.advanced = true
        #expect(filter.activeFilterCount == 3)

        filter.galleryName = false
        #expect(filter.activeFilterCount == 4)

        // A pages range without a bound sends nothing.
        filter.pageLowerBound = ""
        #expect(filter.activeFilterCount == 3)
    }

    @Test func togglingManyTimesStaysInSyncAndLoadsNothing() throws {
        let env = try ListTestEnvironment()
        let model = env.make { SearchFilterBarModel() }

        for _ in 0..<25 {
            model.toggle(.doujinshi)
        }

        #expect(env.filterStore.searchFilter.doujinshi)
        #expect(model.activeFilterCount == 1)
        #expect(env.transport.requests.isEmpty)
    }
}
