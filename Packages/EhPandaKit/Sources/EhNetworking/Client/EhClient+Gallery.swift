import EhModels
import EhParser
import Foundation

extension EhClient {
    /// The gallery page with all comments: detail, tags, previews, comments, the API key and
    /// the daily greeting when the page carries one.
    public func galleryDetail(gid: String, galleryURL: URL) async throws -> GalleryDetailResponse {
        throw AppError.unknown
    }

    /// Resolves a gallery link or an image-page link (deep link, clipboard, comment link)
    /// to its gallery.
    public func gallery(from url: URL) async throws -> Gallery {
        throw AppError.unknown
    }

    public func archive(archiveURL: URL) async throws -> ArchiveInfo {
        throw AppError.unknown
    }

    /// The account's funds, read through e-hentai.org when the archive page did not show them.
    public func archiveFunds(galleryURL: URL) async throws -> GalleryFunds {
        throw AppError.unknown
    }

    /// Asks the user's Hentai@Home client to download an archive. Returns the server's message.
    public func sendDownloadCommand(
        archiveURL: URL, resolution: ArchiveResolution
    ) async throws -> String {
        throw AppError.unknown
    }

    public func torrents(gid: String, token: String) async throws -> [GalleryTorrent] {
        throw AppError.unknown
    }

    /// Preview thumbnails of one page of the gallery's preview grid, by 1-based page index.
    /// `pageNumber` is the 0-based preview page.
    public func previewURLs(galleryURL: URL, pageNumber: Int) async throws -> [Int: URL] {
        throw AppError.unknown
    }

    /// Raw bytes of a URL (torrent files).
    public func data(from url: URL) async throws -> Data {
        throw AppError.unknown
    }
}
