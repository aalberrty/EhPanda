import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

struct ListClientTests {
    private let filter = Filter()

    @Test func frontpageParsesGalleriesAndPagingFromOnePage() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.list("FrontPageCompactList")))

        let page = try await harness.client.frontpage(filter: filter)

        let request = try harness.onlyRequest()
        #expect(request.url == harness.builder.frontpageGalleries(filter: filter).url)
        #expect(request.url?.host() == "e-hentai.org" && request.url?.path() == "/")
        #expect(page.galleries.count == 100)
        #expect(page.galleries.first?.gid == "2668617")
        #expect(page.pageNumber.isNextButtonEnabled)
        #expect(page.pageNumber.lastItemTimestamp == "2668517")
    }

    @Test func frontpageContinuesAfterLastID() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.list("FrontPageCompactList")))

        _ = try await harness.client.frontpage(filter: filter, after: "2668517")

        let request = try harness.onlyRequest()
        #expect(request.url == harness.builder.moreFrontpageGalleries(filter: filter, lastID: "2668517").url)
        #expect(request.url?.query()?.contains("next=2668517") == true)
    }

    @Test func popular() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.list("PopularCompactList")))

        let galleries = try await harness.client.popular(filter: filter)

        let request = try harness.onlyRequest()
        #expect(request.url == harness.builder.popularGalleries(filter: filter).url)
        #expect(request.url?.path() == "/popular")
        #expect(galleries.count == 100)
    }

    @Test func watchedFirstAndNextPage() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .fixture(ClientFixture.list("WatchedCompactList")))

        let first = try await harness.client.watched(filter: filter, keyword: "tag")
        _ = try await harness.client.watched(filter: filter, keyword: "tag", after: "2592671")

        let requests = harness.requests
        #expect(requests.map(\.url) == [
            harness.builder.watchedGalleries(filter: filter, keyword: "tag").url,
            harness.builder.moreWatchedGalleries(filter: filter, lastID: "2592671", keyword: "tag").url
        ])
        #expect(requests.allSatisfy { $0.url?.host() == "exhentai.org" && $0.url?.path() == "/watched" })
        #expect(first.galleries.count == 100)
        #expect(first.pageNumber.lastItemTimestamp == "2592671")
    }

    @Test func searchFirstAndNextPage() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.list("FrontPageMinimalList")))

        let page = try await harness.client.search(keyword: "mks", filter: filter)
        _ = try await harness.client.search(keyword: "mks", filter: filter, after: "1")

        #expect(harness.requests.map(\.url) == [
            harness.builder.searchGalleries(keyword: "mks", filter: filter).url,
            harness.builder.moreSearchGalleries(keyword: "mks", filter: filter, lastID: "1").url
        ])
        #expect(harness.requests.first?.url?.query()?.contains("f_search=mks") == true)
        #expect(page.galleries.count == 100)
    }

    @Test func favoritesReadsSortOrderAndTimestampCursor() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.list("FavoritesCompactList")))

        let page = try await harness.client.favorites(category: 3, sortOrder: .lastUpdateTime)

        let request = try harness.onlyRequest()
        #expect(request.url == harness.builder.favoritesGalleries(favIndex: 3, sortOrder: .lastUpdateTime).url)
        #expect(request.url?.path() == "/favorites.php")
        #expect(page.galleries.first?.gid == "2636342")
        #expect(page.galleries.count == 100)
        #expect(page.pageNumber.lastItemTimestamp == "1610434311")
        // This page has no sort toggle.
        #expect(page.sortOrder == nil)
    }

    @Test func favoritesSortOrderComesFromTheSamePage() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .html(
            ##"<div class="ido"><div><div><a href="#">Use Posted</a></div></div></div>"##
        ))

        let page = try await harness.client.favorites(category: -1)

        #expect(page.sortOrder == .favoritedTime)
        #expect(page.galleries.isEmpty)
    }

    @Test func moreFavorites() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.list("FavoritesCompactList")))

        let page = try await harness.client.moreFavorites(
            category: -1, keyword: "miku", lastID: "1452536", lastTimestamp: "1610434311"
        )

        let request = try harness.onlyRequest()
        #expect(request.url == harness.builder.moreFavoritesGalleries(
            favIndex: -1, lastID: "1452536", lastTimestamp: "1610434311", keyword: "miku"
        ).url)
        #expect(request.url?.query()?.contains("next=1452536-1610434311") == true)
        #expect(page.galleries.count == 100)
    }

    @Test func toplistsStayOnEhentaiWhateverTheHost() async throws {
        let harness = ClientHarness(host: .exhentai)
        harness.transport.on(.any, reply: .fixture(ClientFixture.list("ToplistsCompactList")))

        let page = try await harness.client.toplists(type: .allTime, pageNumber: 2)

        let request = try harness.onlyRequest()
        #expect(request.url == harness.builder.toplistsGalleries(type: .allTime, pageNum: 2).url)
        #expect(request.url?.host() == "e-hentai.org" && request.url?.path() == "/toplist.php")
        #expect(page.galleries.count == 50)
        #expect(page.galleries.first?.gid == "596447")
        #expect(page.pageNumber.current == 0)
    }

    @Test func ipBannedListPage() async throws {
        let harness = ClientHarness()
        harness.transport.on(.any, reply: .fixture(ClientFixture.ipBanned))

        let error = await thrownError { try await harness.client.frontpage(filter: filter) }

        #expect(error as? AppError == .ipBanned(.minutes(59, seconds: 48)))
    }
}
