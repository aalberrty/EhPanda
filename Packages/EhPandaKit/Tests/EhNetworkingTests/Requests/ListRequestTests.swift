import EhModels
import EhNetworking
import Foundation
import Testing

private typealias T = RequestTesting

@Suite struct ListRequestTests {
    private var categories: Filter {
        var filter = Filter()
        filter.doujinshi = true
        filter.manga = true
        return filter
    }

    // MARK: Front page

    @Test(arguments: GalleryHost.allCases)
    func frontpageWithoutFilterIsTheBareHost(host: GalleryHost) {
        T.expectGET(T.builder(host).frontpageGalleries(filter: Filter()), T.origin(host) + "/")
    }

    @Test(arguments: GalleryHost.allCases)
    func frontpageAppendsFilter(host: GalleryHost) {
        T.expectGET(T.builder(host).frontpageGalleries(filter: categories), T.origin(host) + "/?f_cats=6")
    }

    @Test(arguments: GalleryHost.allCases)
    func moreFrontpagePutsCursorBeforeFilter(host: GalleryHost) {
        T.expectGET(
            T.builder(host).moreFrontpageGalleries(filter: categories, lastID: "2345678"),
            T.origin(host) + "/?next=2345678&f_cats=6"
        )
        T.expectGET(
            T.builder(host).moreFrontpageGalleries(filter: Filter(), lastID: "1"),
            T.origin(host) + "/?next=1"
        )
    }

    // MARK: Search

    @Test(arguments: GalleryHost.allCases)
    func searchSendsKeyword(host: GalleryHost) {
        T.expectGET(
            T.builder(host).searchGalleries(keyword: "artist:abc", filter: Filter()),
            T.origin(host) + "/?f_search=artist:abc"
        )
    }

    @Test func searchSendsEmptyKeyword() {
        T.expectGET(T.eh.searchGalleries(keyword: "", filter: Filter()), "https://e-hentai.org/?f_search=")
    }

    @Test func searchEscapesKeywordLikeURLComponents() {
        // `URLComponents.queryItems` escapes `"`, space, `&`, `=`, `#` and non-ASCII but
        // leaves `+`, `$`, `:` and `/` alone.
        let request = T.eh.searchGalleries(keyword: "f:\"big $\" a+b&c=d#e/中", filter: Filter())
        T.expectGET(request, "https://e-hentai.org/?f_search=f:%22big%20$%22%20a+b%26c%3Dd%23e/%E4%B8%AD")
    }

    @Test func searchPutsKeywordBeforeFilter() {
        T.expectGET(
            T.ex.searchGalleries(keyword: "x", filter: categories),
            "https://exhentai.org/?f_search=x&f_cats=6"
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func moreSearchSendsKeywordThenCursor(host: GalleryHost) {
        T.expectGET(
            T.builder(host).moreSearchGalleries(keyword: "x", filter: categories, lastID: "99"),
            T.origin(host) + "/?f_search=x&next=99&f_cats=6"
        )
        T.expectGET(
            T.builder(host).moreSearchGalleries(keyword: "", filter: Filter(), lastID: "99"),
            T.origin(host) + "/?f_search=&next=99"
        )
    }

    // MARK: Popular and watched

    @Test(arguments: GalleryHost.allCases)
    func popular(host: GalleryHost) {
        T.expectGET(T.builder(host).popularGalleries(filter: Filter()), T.origin(host) + "/popular")
        T.expectGET(T.builder(host).popularGalleries(filter: categories), T.origin(host) + "/popular?f_cats=6")
    }

    @Test(arguments: GalleryHost.allCases)
    func watchedOmitsEmptyKeyword(host: GalleryHost) {
        T.expectGET(T.builder(host).watchedGalleries(filter: Filter()), T.origin(host) + "/watched")
        T.expectGET(T.builder(host).watchedGalleries(filter: Filter(), keyword: ""), T.origin(host) + "/watched")
    }

    @Test(arguments: GalleryHost.allCases)
    func watchedWithKeywordAndFilter(host: GalleryHost) {
        T.expectGET(
            T.builder(host).watchedGalleries(filter: categories, keyword: "a b"),
            T.origin(host) + "/watched?f_search=a%20b&f_cats=6"
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func moreWatchedPutsCursorBeforeKeyword(host: GalleryHost) {
        T.expectGET(
            T.builder(host).moreWatchedGalleries(filter: categories, lastID: "7", keyword: "k"),
            T.origin(host) + "/watched?next=7&f_search=k&f_cats=6"
        )
        T.expectGET(
            T.builder(host).moreWatchedGalleries(filter: Filter(), lastID: "7"),
            T.origin(host) + "/watched?next=7"
        )
    }

    // MARK: Favorites

    @Test(arguments: GalleryHost.allCases)
    func favoritesAllCategories(host: GalleryHost) {
        T.expectGET(T.builder(host).favoritesGalleries(favIndex: -1), T.origin(host) + "/favorites.php?favcat=all")
    }

    @Test(arguments: [0, 3, 9])
    func favoritesOneCategory(favIndex: Int) {
        T.expectGET(
            T.eh.favoritesGalleries(favIndex: favIndex),
            "https://e-hentai.org/favorites.php?favcat=\(favIndex)"
        )
    }

    @Test func favoritesKeywordTurnsOnSearchSwitches() {
        T.expectGET(
            T.ex.favoritesGalleries(favIndex: 2, keyword: "a b"),
            "https://exhentai.org/favorites.php?favcat=2&f_search=a%20b&sn=on&st=on&sf=on"
        )
    }

    @Test(arguments: [
        (FavoritesSortOrder.favoritedTime, "fs_f"),
        (FavoritesSortOrder.lastUpdateTime, "fs_p")
    ])
    func favoritesSortOrder(order: FavoritesSortOrder, value: String) {
        T.expectGET(
            T.eh.favoritesGalleries(favIndex: -1, sortOrder: order),
            "https://e-hentai.org/favorites.php?favcat=all&inline_set=\(value)"
        )
        T.expectGET(
            T.eh.favoritesGalleries(favIndex: 1, keyword: "k", sortOrder: order),
            "https://e-hentai.org/favorites.php?favcat=1&f_search=k&sn=on&st=on&sf=on&inline_set=\(value)"
        )
    }

    @Test(arguments: GalleryHost.allCases)
    func moreFavoritesJoinsCursorWithTimestamp(host: GalleryHost) {
        T.expectGET(
            T.builder(host).moreFavoritesGalleries(favIndex: -1, lastID: "123", lastTimestamp: "1700000000"),
            T.origin(host) + "/favorites.php?next=123-1700000000&favcat=all"
        )
        T.expectGET(
            T.builder(host).moreFavoritesGalleries(favIndex: 4, lastID: "123", lastTimestamp: "17", keyword: "k"),
            T.origin(host) + "/favorites.php?next=123-17&favcat=4&f_search=k&sn=on&st=on&sf=on"
        )
    }

    // MARK: Toplists

    @Test(arguments: GalleryHost.allCases)
    func toplistsAlwaysUseEHentai(host: GalleryHost) {
        T.expectGET(
            T.builder(host).toplistsGalleries(type: .yesterday),
            "https://e-hentai.org/toplist.php?tl=15"
        )
        T.expectGET(
            T.builder(host).toplistsGalleries(type: .allTime, pageNum: 3),
            "https://e-hentai.org/toplist.php?tl=11&p=3"
        )
    }

    @Test(arguments: [
        (ToplistsType.yesterday, 15), (.pastMonth, 13), (.pastYear, 12), (.allTime, 11)
    ])
    func moreToplists(type: ToplistsType, tl: Int) {
        T.expectGET(
            T.ex.moreToplistsGalleries(type: type, pageNum: 2),
            "https://e-hentai.org/toplist.php?tl=\(tl)&p=2"
        )
    }
}
