import EhModels
import EhParser
import Foundation

// Each list page is parsed once for both its galleries and its paging.
extension EhClient {
    /// Frontpage. Pass the last gallery id of the previous page as `lastID` to continue.
    public func frontpage(filter: Filter, after lastID: String? = nil) async throws -> GalleryListPage {
        try await perform { builder in
            try await listPage(lastID.map { builder.moreFrontpageGalleries(filter: filter, lastID: $0) }
                ?? builder.frontpageGalleries(filter: filter))
        }
    }

    public func popular(filter: Filter) async throws -> [Gallery] {
        try await perform { builder in
            let data = try await body(builder.popularGalleries(filter: filter))
            let document = try Parser.htmlDocument(data: data)
            return try Parser.parseGalleries(doc: document)
        }
    }

    /// Watched tags list. Requires login.
    public func watched(
        filter: Filter, keyword: String = "", after lastID: String? = nil
    ) async throws -> GalleryListPage {
        try await perform { builder in
            try await listPage(
                lastID.map { builder.moreWatchedGalleries(filter: filter, lastID: $0, keyword: keyword) }
                    ?? builder.watchedGalleries(filter: filter, keyword: keyword)
            )
        }
    }

    public func search(
        keyword: String, filter: Filter, after lastID: String? = nil
    ) async throws -> GalleryListPage {
        try await perform { builder in
            try await listPage(
                lastID.map { builder.moreSearchGalleries(keyword: keyword, filter: filter, lastID: $0) }
                    ?? builder.searchGalleries(keyword: keyword, filter: filter)
            )
        }
    }

    /// First page of a favorites category (`-1` is "all"). A non-nil `sortOrder` asks the
    /// server to switch to that order.
    public func favorites(
        category: Int, keyword: String = "", sortOrder: FavoritesSortOrder? = nil
    ) async throws -> FavoritesPage {
        try await perform { builder in
            try await favoritesPage(
                builder.favoritesGalleries(favIndex: category, keyword: keyword, sortOrder: sortOrder)
            )
        }
    }

    /// Next page of a favorites category. `lastTimestamp` is `PageNumber.lastItemTimestamp`
    /// of the previous page.
    public func moreFavorites(
        category: Int, keyword: String = "", lastID: String, lastTimestamp: String
    ) async throws -> FavoritesPage {
        try await perform { builder in
            try await favoritesPage(builder.moreFavoritesGalleries(
                favIndex: category, lastID: lastID, lastTimestamp: lastTimestamp, keyword: keyword
            ))
        }
    }

    /// Toplists are always served by e-hentai.org. `pageNumber` is 0-based; nil is the first page.
    public func toplists(type: ToplistsType, pageNumber: Int? = nil) async throws -> GalleryListPage {
        try await perform { builder in
            try await listPage(builder.toplistsGalleries(type: type, pageNum: pageNumber))
        }
    }
}

private extension EhClient {
    func listPage(_ request: URLRequest) async throws -> GalleryListPage {
        let data = try await body(request)
        let document = try Parser.htmlDocument(data: data)
        let pageNumber = Parser.parsePageNum(doc: document)
        return GalleryListPage(galleries: try Parser.parseGalleries(doc: document), pageNumber: pageNumber)
    }

    func favoritesPage(_ request: URLRequest) async throws -> FavoritesPage {
        let data = try await body(request)
        let document = try Parser.htmlDocument(data: data)
        return FavoritesPage(
            galleries: try Parser.parseGalleries(doc: document),
            pageNumber: Parser.parsePageNum(doc: document),
            sortOrder: Parser.parseFavoritesSortOrder(doc: document)
        )
    }
}
