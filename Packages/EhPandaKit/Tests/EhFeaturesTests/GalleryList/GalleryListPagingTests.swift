@testable import EhFeatures
import EhModels
import Testing

@Suite struct GalleryListPagingTests {
    private func page(_ gids: [String], _ pageNumber: PageNumber) -> FetchedPage {
        FetchedPage(galleries: gids.map { Gallery.stub($0) }, pageNumber: pageNumber)
    }

    @Test func sourcesUseTheirFilterRange() {
        #expect(GalleryListSource.frontpage.filterRange == .global)
        #expect(GalleryListSource.popular.filterRange == .global)
        #expect(GalleryListSource.watched(keyword: "").filterRange == .watched)
        #expect(GalleryListSource.search(keyword: "a").filterRange == .search)
        #expect(GalleryListSource.favorites(category: -1, keyword: "", sortOrder: nil).filterRange == nil)
        #expect(GalleryListSource.toplists(.allTime).filterRange == nil)
    }

    @Test func sourcesDeclarePagingAndLogin() {
        #expect(GalleryListSource.popular.paging == .single)
        #expect(GalleryListSource.toplists(.yesterday).paging == .numbered)
        #expect(GalleryListSource.toplists(.yesterday).supportsPageJump)
        #expect(!GalleryListSource.frontpage.supportsPageJump)
        #expect(GalleryListSource.frontpage.paging == .cursor)
        #expect(GalleryListSource.watched(keyword: "").requiresLogin)
        #expect(GalleryListSource.favorites(category: 1, keyword: "", sortOrder: nil).requiresLogin)
        #expect(!GalleryListSource.frontpage.requiresLogin)
        #expect(!GalleryListSource.toplists(.yesterday).requiresLogin)
    }

    @Test func singlePageListsHaveNoNextPage() {
        let next = GalleryListPaging.nextRequest(
            after: page(["1"], PageNumber(isNextButtonEnabled: true)), of: .popular, requested: .first
        )
        #expect(next == nil)
    }

    @Test func numberedListsAskForTheFollowingPage() {
        let source = GalleryListSource.toplists(.pastYear)
        #expect(GalleryListPaging.nextRequest(
            after: page(["1"], PageNumber(current: 2, maximum: 5)), of: source, requested: .page(2)
        ) == .page(3))
        #expect(GalleryListPaging.nextRequest(
            after: page(["1"], PageNumber(current: 5, maximum: 5)), of: source, requested: .page(5)
        ) == nil)
    }

    @Test func cursorListsContinueAfterTheLastGalleryOfThePage() {
        let next = GalleryListPaging.nextRequest(
            after: page(["9", "8", "7"], PageNumber(lastItemTimestamp: "7", isNextButtonEnabled: true)),
            of: .frontpage, requested: .first
        )
        #expect(next == .after(lastID: "7", timestamp: nil))
    }

    @Test func cursorListsWithoutNextLinkEnd() {
        let next = GalleryListPaging.nextRequest(
            after: page(["9"], PageNumber(isNextButtonEnabled: false)), of: .frontpage, requested: .first
        )
        #expect(next == nil)
    }

    @Test func emptyCursorPageContinuesFromTheNextLink() {
        let next = GalleryListPaging.nextRequest(
            after: page([], PageNumber(lastItemTimestamp: "500", isNextButtonEnabled: true)),
            of: .watched(keyword: ""), requested: .after(lastID: "600", timestamp: nil)
        )
        #expect(next == .after(lastID: "500", timestamp: nil))
    }

    @Test func aRequestThatWouldRepeatEndsTheList() {
        let next = GalleryListPaging.nextRequest(
            after: page(["7"], PageNumber(lastItemTimestamp: "7", isNextButtonEnabled: true)),
            of: .frontpage, requested: .after(lastID: "7", timestamp: nil)
        )
        #expect(next == nil)
    }

    @Test func favoritesCursorPairsLastIDAndTimestamp() {
        let source = GalleryListSource.favorites(category: -1, keyword: "", sortOrder: nil)
        #expect(GalleryListPaging.nextRequest(
            after: page(["5", "4"], PageNumber(lastItemTimestamp: "1700", isNextButtonEnabled: true)),
            of: source, requested: .first
        ) == .after(lastID: "4", timestamp: "1700"))
        // Legacy: no "load more" when the timestamp could not be parsed.
        #expect(GalleryListPaging.nextRequest(
            after: page(["5", "4"], PageNumber(isNextButtonEnabled: true)), of: source, requested: .first
        ) == nil)
        // An empty page keeps the previous gallery and takes the new timestamp.
        #expect(GalleryListPaging.nextRequest(
            after: page([], PageNumber(lastItemTimestamp: "1600", isNextButtonEnabled: true)),
            of: source, requested: .after(lastID: "4", timestamp: "1700")
        ) == .after(lastID: "4", timestamp: "1600"))
    }

    @Test func deduplicationDropsKnownAndRepeatedGalleries() {
        let galleries = ["1", "2", "2", "3"].map { Gallery.stub($0) }
        #expect(GalleryListPaging.deduplicated(galleries, excluding: ["1"]).map(\.gid) == ["2", "3"])
    }

    @Test func titleFilterIgnoresCase() {
        let galleries = [Gallery.stub("1", title: "Blue Sky"), .stub("2", title: "Red")]
        #expect(GalleryListPaging.filtered(galleries, byTitle: "sKY").map(\.gid) == ["1"])
        #expect(GalleryListPaging.filtered(galleries, byTitle: "").count == 2)
    }
}
