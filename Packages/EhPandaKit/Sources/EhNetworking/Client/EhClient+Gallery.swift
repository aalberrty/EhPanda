import EhModels
import EhParser
import Foundation

extension EhClient {
    /// The gallery page with all comments: detail, tags, previews, comments, the API key and
    /// the daily greeting when the page carries one.
    public func galleryDetail(gid: String, galleryURL: URL) async throws -> GalleryDetailResponse {
        try await perform { builder in
            let data = try await body(builder.galleryDetail(galleryURL: galleryURL))
            // Some galleries carry invalid UTF-8 in their titles or comments.
            let document = try Parser.htmlDocument(data: data, recoversInvalidUTF8: true)
            return try Parser.parseGalleryDetailResponse(doc: document, gid: gid)
        }
    }

    /// Resolves a gallery link or an image-page link (deep link, clipboard, comment link)
    /// to its gallery.
    ///
    /// An image-page link is loaded first to find its gallery URL; the gallery page is then
    /// loaded plainly (without `hc=1`). Throws `AppError.parseFailed` when that page is not a
    /// gallery, where legacy failed with `.unknown`.
    public func gallery(from url: URL) async throws -> Gallery {
        try await perform { builder in
            var galleryURL = url
            if EhURL.analyze(url).isGalleryImageURL {
                let data = try await body(builder.galleryReverse(url: url))
                let document = try Parser.htmlDocument(data: data)
                galleryURL = try Parser.parseGalleryURL(doc: document)
            }
            let data = try await body(builder.galleryReverse(url: galleryURL))
            let document = try Parser.htmlDocument(data: data)
            guard let gallery = Parser.parseGallery(doc: document, galleryURL: galleryURL)
            else { throw AppError.parseFailed }
            return gallery
        }
    }

    public func archive(archiveURL: URL) async throws -> ArchiveInfo {
        try await perform { builder in
            let data = try await body(builder.galleryArchive(archiveURL: archiveURL))
            let document = try Parser.htmlDocument(data: data)
            let response = try Parser.parseGalleryArchiveResponse(doc: document)
            let funds = response.galleryPoints.flatMap { galleryPoints in
                response.credits.map { GalleryFunds(galleryPoints: galleryPoints, credits: $0) }
            }
            return ArchiveInfo(archive: response.archive, funds: funds)
        }
    }

    /// The account's funds, read through e-hentai.org when the archive page did not show them.
    ///
    /// Two steps, as in legacy: the gallery page on e-hentai.org for its archive URL, then
    /// that archive page for the funds. A gallery page without an archive link throws
    /// `AppError.notFound`.
    public func archiveFunds(galleryURL: URL) async throws -> GalleryFunds {
        try await perform { builder in
            guard let detailRequest = builder.galleryArchiveFunds(galleryURL: galleryURL)
            else { throw AppError.unknown }
            let archiveURL = try await archiveURL(detailRequest, gid: EhURL.galleryID(of: galleryURL) ?? "")

            let data = try await body(builder.galleryArchive(archiveURL: archiveURL))
            let document = try Parser.htmlDocument(data: data)
            let (galleryPoints, credits) = try Parser.parseCurrentFunds(doc: document)
            return GalleryFunds(galleryPoints: galleryPoints, credits: credits)
        }
    }

    /// Asks the user's Hentai@Home client to download an archive. Returns the server's message.
    public func sendDownloadCommand(
        archiveURL: URL, resolution: ArchiveResolution
    ) async throws -> String {
        try await perform { builder in
            let request = builder.sendDownloadCommand(archiveURL: archiveURL, resolution: resolution.parameter)
            let data = try await body(request)
            let document = try Parser.htmlDocument(data: data)
            return try Parser.parseDownloadCommandResponse(doc: document)
        }
    }

    public func torrents(gid: String, token: String) async throws -> [GalleryTorrent] {
        try await perform { builder in
            let data = try await body(builder.galleryTorrents(gid: gid, token: token))
            let document = try Parser.htmlDocument(data: data)
            return Parser.parseGalleryTorrents(doc: document)
        }
    }

    /// Preview thumbnails of one page of the gallery's preview grid, by 1-based page index.
    /// `pageNumber` is the 0-based preview page.
    public func previewURLs(galleryURL: URL, pageNumber: Int) async throws -> [Int: URL] {
        try await perform { builder in
            let data = try await body(builder.galleryPreviewURLs(galleryURL: galleryURL, pageNum: pageNumber))
            let document = try Parser.htmlDocument(data: data)
            return try Parser.parsePreviewURLs(doc: document)
        }
    }

    /// Raw bytes of a URL (torrent files).
    public func data(from url: URL) async throws -> Data {
        try await perform { builder in
            try await body(builder.data(url: url))
        }
    }
}

private extension EhClient {
    /// The archive link on a gallery page. Legacy failed the chain without a value (shown as
    /// `.unknown`) both when the page did not parse and when it had no link; this reports the
    /// parser's error and `notFound` respectively.
    func archiveURL(_ request: URLRequest, gid: String) async throws -> URL {
        let data = try await body(request)
        let document = try Parser.htmlDocument(data: data)
        guard let archiveURL = try Parser.parseGalleryDetail(doc: document, gid: gid).0.archiveURL
        else { throw AppError.notFound }
        return archiveURL
    }
}
