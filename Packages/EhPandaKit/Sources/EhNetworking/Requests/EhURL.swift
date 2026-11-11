import EhModels
import Foundation

/// What a gallery or image-page link points at (legacy `URLClient.analyzeURL`).
public struct EhLinkAnalysis: Sendable, Equatable {
    /// An image page (`/s/<key>/<gid>-<page>`) rather than a gallery page.
    public var isGalleryImageURL: Bool
    /// The page number in an image-page link, as written in the link (1-based).
    public var pageIndex: Int?
    /// The comment a gallery link jumps to (`#c<id>`).
    public var commentID: String?

    public init(isGalleryImageURL: Bool, pageIndex: Int? = nil, commentID: String? = nil) {
        self.isGalleryImageURL = isGalleryImageURL
        self.pageIndex = pageIndex
        self.commentID = commentID
    }
}

/// Pure helpers for recognising and rewriting the site's URLs, for deep links,
/// clipboard detection and links inside comments.
public enum EhURL {
    /// Rewrites the app's own `ehpanda://` scheme to `https://`; other URLs are returned as is.
    public static func resolvingAppScheme(_ url: URL) -> URL {
        guard url.scheme == "ehpanda" else { return url }
        return replacing(url) { $0.scheme = "https" } ?? url
    }

    /// Whether the app can open the link: an `https` gallery (`/g/<gid>/<token>`) or image
    /// page (`/s/<key>/<gid>-<page>`) on e-hentai.org or exhentai.org.
    ///
    /// Legacy matched the URL string against `https://e-hentai.org/` and
    /// `https://exhentai.org/`; checking scheme and host accepts the same links without
    /// also accepting ones that merely mention the site in a query.
    public static func isHandleable(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", galleryHost(of: url) != nil else { return false }
        let components = url.pathComponents
        return components.count >= 4 && ["g", "s"].contains(components[1])
            && !components[2].isEmpty && !components[3].isEmpty
    }

    /// Whether the link opens the multi-page viewer (`/mpv/…`).
    public static func isMPVURL(_ url: URL?) -> Bool {
        guard let components = url?.pathComponents, components.count >= 2 else { return false }
        return components[1] == "mpv"
    }

    /// The gallery id of a handleable link: the second path component of a gallery link,
    /// or the part before `-` in an image-page link. `nil` when the path is too short.
    public static func galleryID(of url: URL) -> String? {
        let components = url.pathComponents
        guard components.count >= 4 else { return nil }
        let last = components[3]
        if let range = last.range(of: "-") {
            return String(last[..<range.lowerBound])
        }
        return components[2]
    }

    /// The gid and token of a gallery link (`/g/<gid>/<token>/`).
    public static func galleryIdentifiers(of url: URL) -> (gid: String, token: String)? {
        let components = url.pathComponents
        guard components.count >= 4, components[1] == "g",
              !components[2].isEmpty, !components[3].isEmpty
        else { return nil }
        return (components[2], components[3])
    }

    /// Classifies a link the app can open; a link it cannot open is reported as a plain
    /// gallery link with no page or comment.
    public static func analyze(_ url: URL) -> EhLinkAnalysis {
        guard isHandleable(url) else { return EhLinkAnalysis(isGalleryImageURL: false) }
        var analysis = EhLinkAnalysis(isGalleryImageURL: false)

        let last = url.pathComponents[3]
        if let range = last.range(of: "-") {
            analysis.pageIndex = Int(last[range.upperBound...])
            analysis.isGalleryImageURL = true
        }
        // A comment anchor after the token wins over the image-page reading.
        let string = url.absoluteString
        if let range = string.range(of: last + "/") {
            let tail = string[range.upperBound...]
            if let anchor = tail.range(of: "#c") {
                analysis.commentID = String(tail[anchor.upperBound...])
                analysis.isGalleryImageURL = false
            }
        }
        return analysis
    }

    /// The site a URL belongs to, by exact host.
    public static func galleryHost(of url: URL) -> GalleryHost? {
        GalleryHost.allCases.first { $0.url.host() == url.host()?.lowercased() }
    }

    /// The same URL on the other site, e.g. to open an exhentai.org link on e-hentai.org.
    public static func replacingHost(of url: URL, with host: GalleryHost) -> URL? {
        replacing(url) { $0.host = host.url.host() }
    }

    /// Whether a page the login web view reached is the forum's post-login page
    /// (`CODE=01` in its query), meaning the session cookies are now set.
    public static func isLoginCompletionURL(_ url: URL) -> Bool {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return items.contains {
            $0.name == RequestQueryKey.code.rawValue && $0.value == RequestQueryValue.zeroOne
        }
    }

    private static func replacing(_ url: URL, _ change: (inout URLComponents) -> Void) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        change(&components)
        return components.url
    }
}
