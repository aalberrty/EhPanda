import EhModels
import Foundation

// Image URLs for the reader: normal image pages (`/s/…`) and the multi-page viewer (`/mpv/…`).
extension EhRequestBuilder {
    /// The multi-page viewer page, parsed for the MPV key and per-page image keys.
    public func mpvKeys(mpvURL: URL) -> URLRequest {
        RequestEncoding.get(mpvURL)
    }

    /// One image page (a thumbnail link), parsed for the image and original image URLs.
    /// Legacy fanned these out, one per thumbnail.
    public func galleryNormalImageURL(thumbnailURL: URL) -> URLRequest {
        RequestEncoding.get(thumbnailURL)
    }

    /// Refetching an image that failed to load takes up to three steps:
    /// `thumbnailURLs(galleryURL:pageNum:)` when the image page link is unknown, then
    /// `galleryNormalImageURL(thumbnailURL:)` to read the skip-server identifier, then this,
    /// which reloads the image page with `nl=<identifier>` so the site picks another server.
    public func galleryNormalImageURLRefetch(thumbnailURL: URL, skipServerIdentifier: String) -> URLRequest {
        RequestEncoding.get(RequestEncoding.appending(
            [RequestEncoding.item(.skipServerIdentifier, skipServerIdentifier)], to: thumbnailURL
        ))
    }

    /// The `imagedispatch` API call that resolves one MPV page to an image URL.
    ///
    /// - Parameters:
    ///   - index: The page number as the site counts it (1-based).
    ///   - skipServerIdentifier: The `s` value of a previous dispatch for this page; sending
    ///     it as `nl` asks for a different image server.
    public func galleryMPVImageURL(
        gid: Int, index: Int, mpvKey: String, mpvImageKey: String, skipServerIdentifier: String?
    ) -> URLRequest {
        RequestEncoding.postJSON(apiURL, body: MPVImageDispatchBody(
            method: "imagedispatch", gid: gid, page: index,
            imgkey: mpvImageKey, mpvkey: mpvKey, nl: skipServerIdentifier
        ))
    }

    /// The original image URL from an `imagedispatch` response's `lf` path, which is
    /// relative to the selected host.
    public func mpvOriginalImageURL(path: String) -> URL {
        hostURL.appendingPathComponent(path)
    }
}

private struct MPVImageDispatchBody: Encodable {
    let method: String
    let gid: Int
    let page: Int
    let imgkey: String
    let mpvkey: String
    /// Omitted when `nil`, as legacy did.
    let nl: String?
}
