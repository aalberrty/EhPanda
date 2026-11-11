import EhModels
import Foundation

extension EhClient {
    /// Links to the viewer pages listed on one page of the gallery's preview grid, by 1-based
    /// page index. `pageNumber` is the 0-based preview page. A link may be a multi-page-viewer
    /// URL (`EhURL.isMPVURL`), in which case the gallery is read through the MPV operations.
    public func pageLinks(galleryURL: URL, pageNumber: Int) async throws -> [Int: URL] {
        throw AppError.unknown
    }

    /// Resolves one viewer page to its image.
    public func pageImage(pageLink: URL, index: Int) async throws -> PageImage {
        throw AppError.unknown
    }

    /// Resolves a page again through another image server, for a page whose image failed to
    /// load. When `pageLink` is nil it is looked up on preview page `pageNumber` first.
    /// Stores the server's skip-server hint in `cookies`.
    public func refetchPageImage(
        index: Int, pageNumber: Int, galleryURL: URL, pageLink: URL?, storedImageURL: URL
    ) async throws -> PageImage {
        throw AppError.unknown
    }

    public func mpvKeys(mpvURL: URL) async throws -> MPVKeys {
        throw AppError.unknown
    }

    public func mpvPageImage(
        gid: String, index: Int, mpvKey: String, imageKey: String,
        skipServerIdentifier: String? = nil
    ) async throws -> MPVPageImage {
        throw AppError.unknown
    }
}
