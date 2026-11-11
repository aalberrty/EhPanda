import EhModels

/// What a `GalleryListModel` loads.
nonisolated public enum GalleryListSource: Hashable, Sendable {
    case frontpage
    /// A single page, no pagination.
    case popular
    /// The watched-tags list. Requires login.
    case watched(keyword: String)
    /// A favourites folder (`-1` is every folder). Requires login. A non-nil `sortOrder` asks the
    /// server to switch to that order, which changes the account's own setting.
    case favorites(category: Int, keyword: String, sortOrder: FavoritesSortOrder?)
    /// Always loaded from e-hentai.org, whichever host is selected.
    case toplists(ToplistsType)
    case search(keyword: String)

    /// How a list asks for its next page.
    public enum Paging: Hashable, Sendable {
        /// One page only.
        case single
        /// `next=<last gid>` (favourites: `next=<last gid>-<last item timestamp>`).
        case cursor
        /// `p=<0-based page>`; supports jumping to a page.
        case numbered
    }

    public var paging: Paging {
        switch self {
        case .popular: .single
        case .toplists: .numbered
        case .frontpage, .watched, .favorites, .search: .cursor
        }
    }

    public var supportsPageJump: Bool { paging == .numbered }

    /// The filter the list's requests use. Favourites and toplists take none.
    public var filterRange: FilterRange? {
        switch self {
        case .frontpage, .popular: .global
        case .watched: .watched
        case .search: .search
        case .favorites, .toplists: nil
        }
    }

    public var requiresLogin: Bool {
        switch self {
        case .watched, .favorites: true
        case .frontpage, .popular, .toplists, .search: false
        }
    }
}
