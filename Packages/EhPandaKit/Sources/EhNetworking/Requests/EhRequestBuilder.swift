import EhModels
import Foundation

/// Builds every request the app sends to the site, for one selected `GalleryHost`.
///
/// Pure: it reads no globals, cookies or user defaults. Anything an operation needs
/// beyond the host (api key, member id, gallery id and token, cursors, …) is a parameter.
/// A few endpoints only exist on one site and ignore the host; see `EhEndpoints`.
public struct EhRequestBuilder: Sendable, Hashable {
    public let host: GalleryHost

    public init(host: GalleryHost) {
        self.host = host
    }
}

// MARK: Host-relative endpoints

extension EhRequestBuilder {
    /// `https://e-hentai.org/` or `https://exhentai.org/`; the front page.
    public var hostURL: URL { host.url }
    /// The tag watching / hiding page, shown in a web view.
    public var myTagsURL: URL { hostURL.appendingPathComponent("mytags") }
    /// The torrents page of a gallery; also shown to the user as a copyable link.
    public func galleryTorrentsURL(gid: String, token: String) -> URL {
        RequestEncoding.appending(
            [RequestEncoding.item(.gid, gid), RequestEncoding.item(.token, token)],
            to: galleryTorrentsPage
        )
    }

    var apiURL: URL { hostURL.appendingPathComponent("api.php") }
    var uConfigURL: URL { hostURL.appendingPathComponent("uconfig.php") }
    var galleryPopupsURL: URL { hostURL.appendingPathComponent("gallerypopups.php") }
    var popularURL: URL { hostURL.appendingPathComponent("popular") }
    var watchedURL: URL { hostURL.appendingPathComponent("watched") }
    var favoritesURL: URL { hostURL.appendingPathComponent("favorites.php") }
    private var galleryTorrentsPage: URL { hostURL.appendingPathComponent("gallerytorrents.php") }
}

/// Endpoints that do not follow the selected host.
public enum EhEndpoints {
    public static let ehentai = GalleryHost.ehentai.url
    public static let exhentai = GalleryHost.exhentai.url

    // Static URLs that are valid by construction.
    public static let forum = URL(string: "https://forums.e-hentai.org/index.php")!
    /// The forum login form; the site answers a successful login with cookies.
    public static let login = RequestEncoding.appending(
        [RequestEncoding.item(.act, RequestQueryValue.loginAct),
         RequestEncoding.item(.code, RequestQueryValue.zeroOne)],
        to: forum
    )
    /// The forum login page opened in a web view.
    public static let webLogin = RequestEncoding.appending(
        [RequestEncoding.item(.act, RequestQueryValue.loginAct)], to: forum
    )
    /// News page: only e-hentai.org shows the daily greeting.
    public static let news = ehentai.appendingPathComponent("news.php")
    /// Toplists exist only on e-hentai.org.
    public static let toplist = ehentai.appendingPathComponent("toplist.php")

    static let github = URL(string: "https://github.com/")!
    static let githubAPI = URL(string: "https://api.github.com/repos/")!
}
