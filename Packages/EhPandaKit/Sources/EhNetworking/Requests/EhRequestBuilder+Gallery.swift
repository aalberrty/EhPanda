import EhModels
import Foundation

// Gallery pages. Gallery URLs come from parsed lists or links and keep their own host.
extension EhRequestBuilder {
    /// `hc=1` asks the site to include every comment, not just the first few.
    public func galleryDetail(galleryURL: URL) -> URLRequest {
        RequestEncoding.get(appending([RequestEncoding.item(.showComments, RequestQueryValue.one)], to: galleryURL))
    }

    /// Reverse lookup from a link. For an image-page link, first load the image page to
    /// find its gallery URL; then load the gallery URL itself (plain, without `hc=1`).
    /// Both steps are this plain GET.
    public func galleryReverse(url: URL) -> URLRequest {
        RequestEncoding.get(url)
    }

    /// The archive page (`archiver.php`); its URL comes from the parsed gallery detail.
    public func galleryArchive(archiveURL: URL) -> URLRequest {
        RequestEncoding.get(archiveURL)
    }

    /// First step of reading the user's GP and credits: the gallery page on e-hentai.org,
    /// whatever the gallery URL's host (legacy always read funds there).
    /// Parse its archive URL and load that with `galleryArchive(archiveURL:)`.
    /// Returns `nil` when the URL cannot be rewritten.
    public func galleryArchiveFunds(galleryURL: URL) -> URLRequest? {
        EhURL.replacingHost(of: galleryURL, with: .ehentai).map(RequestEncoding.get)
    }

    public func galleryTorrents(gid: String, token: String) -> URLRequest {
        RequestEncoding.get(galleryTorrentsURL(gid: gid, token: token))
    }

    /// A page of the gallery's previews. `pageNum` is the site's 0-based `p`.
    public func galleryPreviewURLs(galleryURL: URL, pageNum: Int) -> URLRequest {
        detailPage(galleryURL: galleryURL, pageNum: pageNum)
    }

    /// The same detail page as `galleryPreviewURLs`, parsed for image-page links instead.
    public func thumbnailURLs(galleryURL: URL, pageNum: Int) -> URLRequest {
        detailPage(galleryURL: galleryURL, pageNum: pageNum)
    }

    private func detailPage(galleryURL: URL, pageNum: Int) -> URLRequest {
        RequestEncoding.get(appending([RequestEncoding.item(.letterP, String(pageNum))], to: galleryURL))
    }

    private func appending(_ items: [URLQueryItem], to url: URL) -> URL {
        RequestEncoding.appending(items, to: url)
    }
}
