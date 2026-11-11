import EhModels
import EhParser
import Foundation

extension EhClient {
    /// Resolves one viewer page to its image.
    public func pageImage(pageLink: URL, index: Int) async throws -> PageImage {
        try await perform { builder in
            let data = try await body(builder.galleryNormalImageURL(thumbnailURL: pageLink))
            return try Self.pageImage(data: data, index: index)
        }
    }

    /// Resolves a page again through another image server, for a page whose image failed to
    /// load. Stores the server's skip-server hint in `cookies`.
    ///
    /// Two requests, as in legacy: the viewer page, for its skip-server identifier and image;
    /// the viewer page again with `nl=<identifier>`. The first image wins unless it is
    /// `storedImageURL`, the one that failed. Legacy looked the viewer link up on the preview
    /// page when it had none; a page that has an image to replace has its link, and a page
    /// without one is resolved from `previewPage(galleryURL:pageNumber:)` like any other.
    public func refetchPageImage(index: Int, pageLink link: URL, storedImageURL: URL) async throws -> PageImage {
        try await perform { builder in
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
