import EhModels
import Foundation

// Gallery lists. "More" variants load the page after the gallery `lastID`, the site's
// cursor (`next`); toplists page by number instead.
extension EhRequestBuilder {
    public func searchGalleries(keyword: String, filter: Filter) -> URLRequest {
        list(hostURL, [item(.fSearch, keyword)], filter: filter)
    }

    public func moreSearchGalleries(keyword: String, filter: Filter, lastID: String) -> URLRequest {
        list(hostURL, [item(.fSearch, keyword), item(.next, lastID)], filter: filter)
    }

    public func frontpageGalleries(filter: Filter) -> URLRequest {
        list(hostURL, [], filter: filter)
    }

    public func moreFrontpageGalleries(filter: Filter, lastID: String) -> URLRequest {
        list(hostURL, [item(.next, lastID)], filter: filter)
    }

    public func popularGalleries(filter: Filter) -> URLRequest {
        list(popularURL, [], filter: filter)
    }

    /// Unlike search, an empty keyword sends no `f_search` at all.
    public func watchedGalleries(filter: Filter, keyword: String = "") -> URLRequest {
        list(watchedURL, keywordItems(keyword), filter: filter)
    }

    public func moreWatchedGalleries(filter: Filter, lastID: String, keyword: String = "") -> URLRequest {
        list(watchedURL, [item(.next, lastID)] + keywordItems(keyword), filter: filter)
    }

    /// - Parameters:
    ///   - favIndex: The favorites category, 0–9, or -1 for all categories.
    ///   - sortOrder: When set, also switches the account's favorites sort order
    ///     (`inline_set`), which the site remembers for later pages.
    public func favoritesGalleries(
        favIndex: Int, keyword: String = "", sortOrder: FavoritesSortOrder? = nil
    ) -> URLRequest {
        var items = favoritesItems(favIndex: favIndex, keyword: keyword)
        if let sortOrder {
            let value = sortOrder == .favoritedTime
                ? RequestQueryValue.sortOrderByFavoritedTime : RequestQueryValue.sortOrderByUpdateTime
            items.append(item(.inlineSet, value))
        }
        return RequestEncoding.get(RequestEncoding.appending(items, to: favoritesURL))
    }

    /// The favorites cursor pairs the last gallery with its sort timestamp: `next=<gid>-<timestamp>`.
    public func moreFavoritesGalleries(
        favIndex: Int, lastID: String, lastTimestamp: String, keyword: String = ""
    ) -> URLRequest {
        let cursor = item(.next, [lastID, lastTimestamp].joined(separator: "-"))
        let items = [cursor] + favoritesItems(favIndex: favIndex, keyword: keyword)
        return RequestEncoding.get(RequestEncoding.appending(items, to: favoritesURL))
    }

    /// Always e-hentai.org. A `nil` page sends no `p`, which the site treats as the first page.
    public func toplistsGalleries(type: ToplistsType, pageNum: Int? = nil) -> URLRequest {
        var items = [item(.topcat, String(type.categoryIndex))]
        if let pageNum {
            items.append(item(.letterP, String(pageNum)))
        }
        return RequestEncoding.get(RequestEncoding.appending(items, to: EhEndpoints.toplist))
    }

    /// Always e-hentai.org.
    public func moreToplistsGalleries(type: ToplistsType, pageNum: Int) -> URLRequest {
        toplistsGalleries(type: type, pageNum: pageNum)
    }
}

private extension EhRequestBuilder {
    func item(_ key: RequestQueryKey, _ value: String) -> URLQueryItem {
        RequestEncoding.item(key, value)
    }

    func list(_ base: URL, _ items: [URLQueryItem], filter: Filter) -> URLRequest {
        RequestEncoding.get(RequestEncoding.appending(items + FilterQuery.items(for: filter), to: base))
    }

    func keywordItems(_ keyword: String) -> [URLQueryItem] {
        keyword.isEmpty ? [] : [item(.fSearch, keyword)]
    }

    func favoritesItems(favIndex: Int, keyword: String) -> [URLQueryItem] {
        var items = [item(.favcat, favIndex == -1 ? RequestQueryValue.all : String(favIndex))]
        if !keyword.isEmpty {
            // The favorites search only applies the keyword with these switches on.
            items.append(item(.fSearch, keyword))
            items += [RequestQueryKey.sn, .st, .sf].map { item($0, RequestQueryValue.filterOn) }
        }
        return items
    }
}
