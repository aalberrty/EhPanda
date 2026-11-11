import EhModels
import Foundation

// Bodies are implemented by the client task; until then every operation fails.
extension EhClient {
    /// Frontpage. Pass the last gallery id of the previous page as `lastID` to continue.
    public func frontpage(filter: Filter, after lastID: String? = nil) async throws -> GalleryListPage {
        throw AppError.unknown
    }

    public func popular(filter: Filter) async throws -> [Gallery] {
        throw AppError.unknown
    }

    /// Watched tags list. Requires login.
    public func watched(
        filter: Filter, keyword: String = "", after lastID: String? = nil
    ) async throws -> GalleryListPage {
        throw AppError.unknown
    }

    public func search(
        keyword: String, filter: Filter, after lastID: String? = nil
    ) async throws -> GalleryListPage {
        throw AppError.unknown
    }

    /// First page of a favorites category (`-1` is "all"). A non-nil `sortOrder` asks the
    /// server to switch to that order.
    public func favorites(
        category: Int, keyword: String = "", sortOrder: FavoritesSortOrder? = nil
    ) async throws -> FavoritesPage {
        throw AppError.unknown
    }

    /// Next page of a favorites category. `lastTimestamp` is `PageNumber.lastItemTimestamp`
    /// of the previous page.
    public func moreFavorites(
        category: Int, keyword: String = "", lastID: String, lastTimestamp: String
    ) async throws -> FavoritesPage {
        throw AppError.unknown
    }

    /// Toplists are always served by e-hentai.org. `pageNumber` is 0-based; nil is the first page.
    public func toplists(type: ToplistsType, pageNumber: Int? = nil) async throws -> GalleryListPage {
        throw AppError.unknown
    }
}
