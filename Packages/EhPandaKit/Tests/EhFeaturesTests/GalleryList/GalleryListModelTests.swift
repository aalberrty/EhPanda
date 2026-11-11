@testable import EhFeatures
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct GalleryListModelTests {
    @Test func firstLoadShowsTheFirstPage() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        let model = env.make { GalleryListModel(source: .frontpage) }
        #expect(model.phase == .loading)

        await model.loadIfNeeded()

        #expect(model.phase == .content)
        #expect(!model.galleries.isEmpty)
        #expect(model.galleries.last?.gid == ListFixture.frontpageLastID)
        #expect(model.visibleGalleries == model.galleries)
        #expect(model.footerPhase == .idle)
        #expect(env.query("next", ofRequest: 0) == nil)

        // Already loaded: appearing again requests nothing.
        await model.loadIfNeeded()
        #expect(env.transport.requests.count == 1)
    }

    @Test func loadMoreSendsTheLastGalleryAndAppends() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        env.transport.on(.query("next", ListFixture.frontpageLastID), reply: .fixture(ListFixture.popular))
        let model = env.make { GalleryListModel(source: .frontpage) }
        await model.loadIfNeeded()
        let firstCount = model.galleries.count
        let trigger = model.paginationTrigger

        await model.loadMore()

        #expect(env.query("next", ofRequest: 1) == ListFixture.frontpageLastID)
        #expect(model.galleries.count > firstCount)
        #expect(Set(model.galleries.map(\.gid)).count == model.galleries.count)
        #expect(model.paginationTrigger != trigger)
        // The popular page has no "Next" link.
        #expect(model.footerPhase == .end)
        await model.loadMore()
        #expect(env.transport.requests.count == 2)
    }

    @Test func appendedDuplicatesAreDropped() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        let model = env.make { GalleryListModel(source: .frontpage) }
        await model.loadIfNeeded()
        let galleries = model.galleries

        await model.loadMore()

        #expect(model.galleries == galleries)
        // The same page again would repeat the same request forever, so the list ends.
        #expect(!model.hasNextPage)
    }

    @Test func emptyFirstPageIsSkipped() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: ListFixture.emptyPage(nextID: "900"))
        env.transport.on(.query("next", "900"), reply: .fixture(ListFixture.frontpage))
        let model = env.make { GalleryListModel(source: .frontpage) }

        await model.loadIfNeeded()

        #expect(env.transport.requests.count == 2)
        #expect(env.query("next", ofRequest: 1) == "900")
        #expect(model.phase == .content)
    }

    @Test func emptyPagesAreSkippedWhenLoadingMore() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        env.transport.on(.query("next", ListFixture.frontpageLastID), reply: ListFixture.emptyPage(nextID: "900"))
        env.transport.on(.query("next", "900"), reply: .fixture(ListFixture.popular))
        let model = env.make { GalleryListModel(source: .frontpage) }
        await model.loadIfNeeded()
        let firstCount = model.galleries.count

        await model.loadMore()

        #expect(env.transport.requests.count == 3)
        #expect(model.galleries.count > firstCount)
        #expect(model.footerPhase == .end)
    }

    @Test func emptyResultIsNotFound() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: ListFixture.lastEmptyPage)
        let model = env.make { GalleryListModel(source: .frontpage) }

        await model.loadIfNeeded()

        #expect(model.phase == .failed(.notFound))
    }

    @Test func failedFirstPageCanBeRetried() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(
            .any, replies: .error(URLError(.notConnectedToInternet)), .fixture(ListFixture.frontpage)
        )
        let model = env.make { GalleryListModel(source: .frontpage) }

        await model.loadIfNeeded()
        #expect(model.phase == .failed(.networkingFailed))

        let request = model.loadRequest
        model.retry()
        #expect(model.loadRequest != request)
        await model.loadIfNeeded()
        #expect(model.phase == .content)
    }

    @Test func failedNextPageCanBeRetried() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        env.transport.on(
            .query("next", ListFixture.frontpageLastID),
            replies: .error(URLError(.timedOut)), .fixture(ListFixture.popular)
        )
        let model = env.make { GalleryListModel(source: .frontpage) }
        await model.loadIfNeeded()

        await model.loadMore()
        #expect(model.footerPhase == .failed)
        #expect(model.phase == .content)

        let trigger = model.paginationTrigger
        model.retryLoadMore()
        #expect(model.paginationTrigger != trigger)
        await model.loadMore()
        #expect(model.footerPhase == .end)
    }

    @Test func cancelledFirstLoadLeavesStateUntouched() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .suspendUntilCancelled)
        let model = env.make { GalleryListModel(source: .frontpage) }

        let task = Task { await model.loadIfNeeded() }
        await waitUntil { model.loadingState == .loading }
        task.cancel()
        await task.value

        #expect(model.loadingState == .idle)
        #expect(model.galleries.isEmpty)

        // The next appearance loads again.
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        await model.loadIfNeeded()
        #expect(model.phase == .content)
    }

    @Test func cancelledLoadMoreLeavesStateUntouched() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        env.transport.on(.query("next", ListFixture.frontpageLastID), reply: .suspendUntilCancelled)
        let model = env.make { GalleryListModel(source: .frontpage) }
        await model.loadIfNeeded()
        let galleries = model.galleries

        let task = Task { await model.loadMore() }
        await waitUntil { model.footerState == .loading }
        task.cancel()
        await task.value

        #expect(model.footerState == .idle)
        #expect(model.galleries == galleries)
        #expect(model.hasNextPage)
    }

    @Test func refreshReplacesTheList() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, replies: .fixture(ListFixture.frontpage), .fixture(ListFixture.popular))
        let model = env.make { GalleryListModel(source: .frontpage) }
        await model.loadIfNeeded()

        await model.refresh()

        #expect(model.galleries.last?.gid != ListFixture.frontpageLastID)
        #expect(env.query("next", ofRequest: 1) == nil)
    }

    @Test func requestsUseTheFilterOfTheirRange() async throws {
        let env = try ListTestEnvironment()
        env.filterStore.globalFilter.doujinshi = true
        env.filterStore.watchedFilter.manga = true
        env.filterStore.searchFilter.misc = true
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))

        for source in [GalleryListSource.frontpage, .watched(keyword: ""), .search(keyword: "a"),
                       .favorites(category: -1, keyword: "", sortOrder: nil), .toplists(.allTime)] {
            await env.make { GalleryListModel(source: source) }.loadIfNeeded()
        }

        #expect(env.query("f_cats", ofRequest: 0) == String(Category.doujinshi.filterValue))
        #expect(env.query("f_cats", ofRequest: 1) == String(Category.manga.filterValue))
        #expect(env.query("f_cats", ofRequest: 2) == String(Category.misc.filterValue))
        #expect(env.query("f_cats", ofRequest: 3) == nil)
        #expect(env.query("f_cats", ofRequest: 4) == nil)
    }

    @Test func listsThatNeedLoginRequestNothingUntilLoggedIn() async throws {
        let env = try ListTestEnvironment(loggedIn: false)
        env.transport.on(.any, reply: .fixture(ListFixture.watched))
        let model = env.make { GalleryListModel(source: .watched(keyword: "")) }

        await model.loadIfNeeded()
        await model.refresh()
        #expect(model.phase == .notLoggedIn)
        #expect(env.transport.requests.isEmpty)

        env.logIn()
        await model.loadIfNeeded()
        #expect(model.phase == .content)
    }

    @Test func titleFilterNarrowsVisibleGalleries() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        let model = env.make { GalleryListModel(source: .frontpage) }
        await model.loadIfNeeded()
        let title = try #require(model.galleries.first?.title)

        model.titleFilter = title.uppercased()
        #expect(!model.visibleGalleries.isEmpty)
        #expect(model.visibleGalleries.count < model.galleries.count)
        model.titleFilter = ""
        #expect(model.visibleGalleries == model.galleries)
    }

    @Test func resetSwitchesSourceAndLoadsAgain() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.watched))
        let model = env.make { WatchedModel() }
        await model.list.loadIfNeeded()
        let request = model.list.loadRequest

        model.keyword = "language:english"
        model.submitKeyword()
        #expect(model.list.galleries.isEmpty)
        #expect(model.list.loadRequest != request)
        await model.list.loadIfNeeded()

        #expect(env.query("f_search", ofRequest: 1) == "language:english")
        #expect(model.list.phase == .content)
        await model.list.loadMore()
        #expect(env.query("next", ofRequest: 2) == ListFixture.watchedLastID)
        #expect(env.query("f_search", ofRequest: 2) == "language:english")
    }

    @Test func quickSearchReplacesTheKeyword() async throws {
        let env = try ListTestEnvironment()
        let model = env.make { WatchedModel() }
        model.quickSearch("artist:a")
        #expect(model.keyword == "artist:a")
        #expect(model.list.source == .watched(keyword: "artist:a"))
    }
}
