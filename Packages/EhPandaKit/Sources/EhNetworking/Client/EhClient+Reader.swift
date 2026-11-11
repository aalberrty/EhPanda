import EhModels
import EhParser
import Foundation

extension EhClient {
    /// Links to the viewer pages listed on one page of the gallery's preview grid, by 1-based
    /// page index. `pageNumber` is the 0-based preview page. A link may be a multi-page-viewer
    /// URL (`EhURL.isMPVURL`), in which case the gallery is read through the MPV operations.
    public func pageLinks(galleryURL: URL, pageNumber: Int) async throws -> [Int: URL] {
        try await perform { builder in
            try await pageLinks(builder.thumbnailURLs(galleryURL: galleryURL, pageNum: pageNumber))
        }
    }

    /// Resolves one viewer page to its image.
    public func pageImage(pageLink: URL, index: Int) async throws -> PageImage {
        try await perform { builder in
            let data = try await body(builder.galleryNormalImageURL(thumbnailURL: pageLink))
            return try Self.pageImage(data: data, index: index)
        }
    }

    /// Resolves a page again through another image server, for a page whose image failed to
    /// load. When `pageLink` is nil it is looked up on preview page `pageNumber` first.
    /// Stores the server's skip-server hint in `cookies`.
    ///
    /// Up to three requests, as in legacy: the preview page (only without `pageLink`); the
    /// viewer page, for its skip-server identifier and image; the viewer page again with
    /// `nl=<identifier>`. The first image wins unless it is `storedImageURL`, the one that
    /// failed. Throws `AppError.notFound` when the preview page does not list `index`.
    public func refetchPageImage(
        index: Int, pageNumber: Int, galleryURL: URL, pageLink: URL?, storedImageURL: URL
    ) async throws -> PageImage {
        try await perform { builder in
            var link = pageLink
            if link == nil {
                link = try await pageLinks(builder.thumbnailURLs(galleryURL: galleryURL, pageNum: pageNumber))[index]
            }
            guard let link else { throw AppError.notFound }

            let first = try await viewerPage(builder.galleryNormalImageURL(thumbnailURL: link), index: index)
            let reloadRequest = builder.galleryNormalImageURLRefetch(
                thumbnailURL: link, skipServerIdentifier: first.skipServerIdentifier
            )
            let reloadResponse = try await send(reloadRequest)
            let reloaded = try Self.pageImage(data: reloadResponse.data, index: index)
            cookies.setSkipServer(response: reloadResponse.response, host: builder.host)

            let imageURL = Parser.refetchedImageURL(
                first: first.image.imageURL, reloaded: reloaded.imageURL, storedImageURL: storedImageURL
            )
            // Legacy kept the old original-image URL; this takes the one shown with the chosen image.
            return imageURL == first.image.imageURL ? first.image : reloaded
        }
    }

    public func mpvKeys(mpvURL: URL) async throws -> MPVKeys {
        try await perform { builder in
            let data = try await body(builder.mpvKeys(mpvURL: mpvURL))
            let document = try Parser.htmlDocument(data: data)
            let (mpvKey, imageKeys) = try Parser.parseMPVKeys(doc: document)
            return MPVKeys(mpvKey: mpvKey, imageKeys: imageKeys)
        }
    }

    public func mpvPageImage(
        gid: String, index: Int, mpvKey: String, imageKey: String,
        skipServerIdentifier: String? = nil
    ) async throws -> MPVPageImage {
        try await perform { builder in
            let request = builder.galleryMPVImageURL(
                gid: try number(gid), index: index, mpvKey: mpvKey, mpvImageKey: imageKey,
                skipServerIdentifier: skipServerIdentifier
            )
            let data = try await body(request)
            let (imageURL, originalImageURL, identifier) = try Parser.parseGalleryMPVImageURL(
                data: data, host: builder.host
            )
            return MPVPageImage(
                image: PageImage(index: index, imageURL: imageURL, originalImageURL: originalImageURL),
                skipServerIdentifier: identifier
            )
        }
    }
}

private extension EhClient {
    func pageLinks(_ request: URLRequest) async throws -> [Int: URL] {
        let data = try await body(request)
        let document = try Parser.htmlDocument(data: data)
        return try Parser.parseThumbnailURLs(doc: document)
    }

    /// A viewer page's image and its "reload broken image" identifier.
    func viewerPage(
        _ request: URLRequest, index: Int
    ) async throws -> (image: PageImage, skipServerIdentifier: String) {
        let data = try await body(request)
        let document = try Parser.htmlDocument(data: data)
        let identifier = try Parser.parseSkipServerIdentifier(doc: document)
        let (_, imageURL, originalImageURL) = try Parser.parseGalleryNormalImageURL(doc: document, index: index)
        return (PageImage(index: index, imageURL: imageURL, originalImageURL: originalImageURL), identifier)
    }

    static func pageImage(data: Data, index: Int) throws -> PageImage {
        let document = try Parser.htmlDocument(data: data)
        let (_, imageURL, originalImageURL) = try Parser.parseGalleryNormalImageURL(doc: document, index: index)
        return PageImage(index: index, imageURL: imageURL, originalImageURL: originalImageURL)
    }
}
