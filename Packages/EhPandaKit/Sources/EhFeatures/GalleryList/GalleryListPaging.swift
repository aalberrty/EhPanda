import EhModels

/// One request for a page of a list.
nonisolated enum PageRequest: Hashable, Sendable {
    /// The list's first page.
    case first
    /// A numbered page (0-based), for `.numbered` lists.
    case page(Int)
    /// The page after a gallery, for `.cursor` lists. Favourites also need the timestamp of the
    /// last item.
    case after(lastID: String, timestamp: String?)

    var lastID: String? {
        if case .after(let lastID, _) = self { lastID } else { nil }
    }
}

/// A page as the client returned it.
nonisolated struct FetchedPage: Sendable {
    var galleries: [Gallery]
    var pageNumber: PageNumber
    var sortOrder: FavoritesSortOrder?
}

/// The paging rules of legacy's list reducers, as pure functions.
nonisolated enum GalleryListPaging {
    /// The request for the page after `page`, or `nil` when there is none.
    ///
    /// Cursor lists continue after the last gallery **of the page just received**. Legacy used
    /// the last gallery of the whole list, which repeats the same request forever when a page
    /// is empty or only holds duplicates. An empty page has no last gallery, so the site's own
    /// "next" link is used instead: on every list but favourites it is `next=<gid>`, which the
    /// parser keeps whole in `lastItemTimestamp` (it splits at `-`, and there is none).
    /// Favourites links are `next=<gid>-<timestamp>`; without a timestamp there is no next page.
    ///
    /// A request identical to the one that produced `page` means no progress, so it ends the list.
    static func nextRequest(
        after page: FetchedPage, of source: GalleryListSource, requested: PageRequest
    ) -> PageRequest? {
        let next: PageRequest?
        switch source.paging {
        case .single:
            next = nil
        case .numbered:
            let pageNumber = page.pageNumber
            next = pageNumber.hasNextPage(isNumericBased: true) ? .page(pageNumber.current + 1) : nil
        case .cursor:
            next = cursorRequest(after: page, of: source, requested: requested)
        }
        return next == requested ? nil : next
    }

    private static func cursorRequest(
        after page: FetchedPage, of source: GalleryListSource, requested: PageRequest
    ) -> PageRequest? {
        guard page.pageNumber.hasNextPage() else { return nil }
        if case .favorites = source {
            guard let timestamp = page.pageNumber.lastItemTimestamp,
                  let lastID = page.galleries.last?.gid ?? requested.lastID
            else { return nil }
            return .after(lastID: lastID, timestamp: timestamp)
        }
        guard let lastID = page.galleries.last?.gid ?? page.pageNumber.lastItemTimestamp else { return nil }
        return .after(lastID: lastID, timestamp: nil)
    }

    /// `galleries` without those whose id is in `existing` or repeats an earlier one.
    static func deduplicated(_ galleries: [Gallery], excluding existing: Set<String>) -> [Gallery] {
        var seen = existing
        return galleries.filter { seen.insert($0.gid).inserted }
    }

    /// Galleries whose title contains `keyword`, ignoring case (legacy local "Filter" search).
    static func filtered(_ galleries: [Gallery], byTitle keyword: String) -> [Gallery] {
        guard !keyword.isEmpty else { return galleries }
        return galleries.filter { $0.title.range(of: keyword, options: .caseInsensitive) != nil }
    }
}
