import EhCore
import EhModels
import EhNetworking
import Foundation

/// "Redirects links to the selected host" for every gallery link the app opens itself: deep,
/// clipboard and shared links (`DeepLinkModel`) and links tapped in comments (`CommentsModel`).
nonisolated struct LinkRedirection: Sendable {
    /// The host links are moved to; `nil` when the setting is off.
    let host: GalleryHost?

    init(host: GalleryHost?) {
        self.host = host
    }

    @MainActor init(settings: SettingsStore) {
        host = settings.redirectsLinksToSelectedHost ? settings.galleryHost : nil
    }

    /// The same link on the selected host when it names the other site.
    func redirect(_ url: URL) -> URL {
        guard let host, let linkHost = EhURL.galleryHost(of: url), linkHost != host else { return url }
        return EhURL.replacingHost(of: url, with: host) ?? url
    }

    /// `gallery` with its gallery URL on the selected host.
    func redirect(_ gallery: Gallery) -> Gallery {
        guard let galleryURL = gallery.galleryURL else { return gallery }
        let redirected = redirect(galleryURL)
        guard redirected != galleryURL else { return gallery }
        return Gallery(
            gid: gallery.gid, token: gallery.token, title: gallery.title, rating: gallery.rating,
            tags: gallery.tags, category: gallery.category, uploader: gallery.uploader,
            pageCount: gallery.pageCount, postedDate: gallery.postedDate, coverURL: gallery.coverURL,
            galleryURL: redirected, lastOpenDate: gallery.lastOpenDate
        )
    }
}
