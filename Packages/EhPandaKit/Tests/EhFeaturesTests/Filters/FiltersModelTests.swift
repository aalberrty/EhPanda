@testable import EhFeatures
import EhModels
import Testing

@Suite struct FiltersModelTests {
    @Test func opensOnTheCallersRange() throws {
        let env = try ListTestEnvironment()
        #expect(env.make { FiltersModel(range: .watched) }.range == .watched)
        #expect(env.make { FiltersModel(range: .global) }.range == .global)
    }

    @Test func categoryTilesToggleExclusionOfTheEditedRange() throws {
        let env = try ListTestEnvironment()
        let model = env.make { FiltersModel(range: .global) }
        #expect(FiltersModel.categories.count == 10)
        #expect(!FiltersModel.categories.contains(.private))

        model.toggleExclusion(of: .western)
        #expect(model.isExcluded(.western))
        #expect(env.filterStore.globalFilter.western)
        #expect(!env.filterStore.searchFilter.western)

        model.range = .search
        #expect(!model.isExcluded(.western))
        for category in FiltersModel.categories {
            model.toggleExclusion(of: category)
            #expect(model.isExcluded(category))
        }
        model.toggleExclusion(of: .misc)
        #expect(!env.filterStore.searchFilter.misc)
    }

    @Test func everyCategoryMapsToItsOwnFlag() {
        var filter = Filter()
        for category in FiltersModel.categories {
            if let keyPath = FiltersModel.keyPath(for: category) { filter[keyPath: keyPath] = true }
        }
        #expect(filter.doujinshi && filter.manga && filter.artistCG && filter.gameCG && filter.western)
        #expect(filter.nonH && filter.imageSet && filter.cosplay && filter.asianPorn && filter.misc)
        #expect(FiltersModel.keyPath(for: .private) == nil)
    }

    @Test func resetRestoresDefaultsOfTheRangeOnly() throws {
        let env = try ListTestEnvironment()
        let model = env.make { FiltersModel(range: .watched) }
        model.filter.advanced = true
        model.filter.galleryName = false
        env.filterStore.globalFilter.advanced = true

        model.presentResetConfirmation()
        #expect(model.isResetConfirmationPresented)
        model.reset()

        #expect(!model.isResetConfirmationPresented)
        #expect(model.filter == Filter())
        #expect(env.filterStore.globalFilter.advanced)
    }

    @Test func lowPowerAndDownvotedTagsAreExclusive() throws {
        let env = try ListTestEnvironment()
        let model = env.make { FiltersModel(range: .search) }
        model.filter.lowPowerTags = true
        model.filter.downvotedTags = true
        #expect(!model.filter.lowPowerTags)
        model.filter.lowPowerTags = true
        #expect(!model.filter.downvotedTags)
    }

    @Test func pageBoundsMustBeNumbers() throws {
        let env = try ListTestEnvironment()
        let model = env.make { FiltersModel(range: .search) }
        model.filter.pageLowerBound = "12"
        model.filter.pageUpperBound = "x"
        #expect(model.filter.pageLowerBound == "12")
        #expect(model.filter.pageUpperBound == "")
    }

    @Test func returnMovesFromLowerToUpperBoundThenEndsEditing() throws {
        let env = try ListTestEnvironment()
        let model = env.make { FiltersModel(range: .search) }
        #expect(!model.isPageRangeToggleDisabled)

        model.focusedBound = .lower
        #expect(model.isPageRangeToggleDisabled)
        model.submitBound()
        #expect(model.focusedBound == .upper)
        model.submitBound()
        #expect(model.focusedBound == nil)
        #expect(!model.isPageRangeToggleDisabled)
    }

    @Test func minimumRatingIsKeptPerRange() throws {
        let env = try ListTestEnvironment()
        let model = env.make { FiltersModel(range: .search) }
        model.filter.minRatingActivated = true
        model.filter.minRating = 4
        #expect(env.filterStore.searchFilter.minRating == 4)
        #expect(env.filterStore.globalFilter.minRating == 2)
    }
}
