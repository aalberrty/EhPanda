@testable import EhCore
import EhModels
import Foundation
import Testing

@MainActor @Suite struct FilterStoreTests {
    private func sampleFilter() -> Filter {
        var filter = Filter()
        filter.doujinshi = true
        filter.advanced = true
        filter.minRatingActivated = true
        filter.minRating = 4
        filter.pageRangeActivated = true
        filter.pageLowerBound = "10"
        filter.pageUpperBound = "200"
        return filter
    }

    @Test func emptyDefaultsLoadDefaultFilters() {
        let store = FilterStore(storage: .ephemeral())
        for range in FilterRange.allCases {
            #expect(store[range] == Filter())
        }
    }

    @Test(arguments: FilterRange.allCases)
    func eachRangePersistsUnderItsOwnKey(range: FilterRange) {
        let storage = PreferenceStorage.ephemeral()
        let store = FilterStore(storage: storage)
        store[range] = sampleFilter()
        store.waitForPendingWrites()

        let reloaded = FilterStore(storage: storage)
        #expect(reloaded[range] == sampleFilter())
        for other in FilterRange.allCases where other != range {
            #expect(reloaded[other] == Filter())
            #expect(!storage.contains(FilterStore.key(for: other)))
        }
    }

    @Test func keysAreOnePerRange() {
        #expect(FilterRange.allCases.map(FilterStore.key(for:)) == [
            "filters.search", "filters.global", "filters.watched"
        ])
    }

    @Test func editingAFieldPersists() {
        let storage = PreferenceStorage.ephemeral()
        let store = FilterStore(storage: storage)
        store.globalFilter.nonH = true
        store.waitForPendingWrites()
        #expect(FilterStore(storage: storage).globalFilter.nonH)
    }

    @Test func invalidPageBoundsAreCleared() {
        let storage = PreferenceStorage.ephemeral()
        let store = FilterStore(storage: storage)
        store.searchFilter.pageLowerBound = "12"
        store.searchFilter.pageUpperBound = "abc"
        #expect(store.searchFilter.pageLowerBound == "12")
        #expect(store.searchFilter.pageUpperBound == "")
        store.waitForPendingWrites()
        #expect(FilterStore(storage: storage).searchFilter.pageUpperBound == "")
    }

    @Test func lowPowerAndDownvotedTagsStayExclusive() {
        let store = FilterStore(storage: .ephemeral())
        store.watchedFilter.lowPowerTags = true
        store.watchedFilter.downvotedTags = true
        #expect(!store.watchedFilter.lowPowerTags && store.watchedFilter.downvotedTags)
    }

    @Test func resetRestoresOnlyThatRange() {
        let storage = PreferenceStorage.ephemeral()
        let store = FilterStore(storage: storage)
        for range in FilterRange.allCases {
            store[range] = sampleFilter()
        }
        store.reset(.global)
        #expect(store.globalFilter == Filter())
        #expect(store.searchFilter == sampleFilter() && store.watchedFilter == sampleFilter())
        store.waitForPendingWrites()
        let reloaded = FilterStore(storage: storage)
        #expect(reloaded.globalFilter == Filter())
        #expect(reloaded.searchFilter == sampleFilter())
    }

    @Test func unreadableStoredFilterFallsBackToDefault() {
        let storage = PreferenceStorage.ephemeral()
        storage.defaults.set(json("not json"), forKey: "filters.search")
        storage.defaults.set("a string", forKey: "filters.global")
        storage.defaults.set(json(#"{"pageLowerBound": "x", "manga": true}"#), forKey: "filters.watched")
        let store = FilterStore(storage: storage)
        #expect(store.searchFilter == Filter())
        #expect(store.globalFilter == Filter())
        #expect(store.watchedFilter.manga && store.watchedFilter.pageLowerBound == "")
    }

    @Test func observationIsPerRange() {
        let store = FilterStore(storage: .ephemeral())
        #expect(!changeIsObserved(reading: { _ = store.searchFilter }, after: { store.globalFilter.misc = true }))
        #expect(changeIsObserved(reading: { _ = store.searchFilter }, after: { store.searchFilter.misc = true }))
        store.watchedFilter.misc = true
        #expect(changeIsObserved(reading: { _ = store.watchedFilter }, after: { store.reset(.watched) }))
        #expect(!changeIsObserved(reading: { _ = store.globalFilter }, after: { store.reset(.watched) }))
    }
}
