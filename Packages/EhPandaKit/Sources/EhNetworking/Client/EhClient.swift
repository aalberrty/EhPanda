import EhModels
import EhParser
import Foundation

/// Typed access to every server operation of the app.
///
/// Each method builds a request (`EhRequestBuilder`), sends it through the `HTTPTransport`
/// and parses the response (`EhParser`), all off the caller's actor.
///
/// **Errors.** Every method throws `AppError`, or `CancellationError` when the calling task
/// was cancelled. No other error type escapes.
///
/// **Host.** The target site is read from `host` for each call, so switching between
/// E-Hentai and ExHentai needs no new client.
public struct EhClient: Sendable {
    let transport: any HTTPTransport
    /// Cookies of the session. Operations that receive credentials or a skip-server hint
    /// store them here.
    public let cookies: CookieStore
    let host: @Sendable () -> GalleryHost

    public init(
        transport: any HTTPTransport,
        cookies: CookieStore,
        host: @escaping @Sendable () -> GalleryHost
    ) {
        self.transport = transport
        self.cookies = cookies
        self.host = host
    }
}

// MARK: Result types

/// One page of a gallery list and the paging information to request the next one.
public struct GalleryListPage: Sendable {
    public var galleries: [Gallery]
    public var pageNumber: PageNumber

    public init(galleries: [Gallery], pageNumber: PageNumber) {
        self.galleries = galleries
        self.pageNumber = pageNumber
    }
}

/// One page of the favorites list. `sortOrder` is the order the server reports on the first page.
public struct FavoritesPage: Sendable {
    public var galleries: [Gallery]
    public var pageNumber: PageNumber
    public var sortOrder: FavoritesSortOrder?

    public init(galleries: [Gallery], pageNumber: PageNumber, sortOrder: FavoritesSortOrder?) {
        self.galleries = galleries
        self.pageNumber = pageNumber
        self.sortOrder = sortOrder
    }
}

/// The download options of a gallery, with the account's funds when the page shows them.
public struct ArchiveInfo: Sendable {
    public var archive: GalleryArchive
    public var funds: GalleryFunds?

    public init(archive: GalleryArchive, funds: GalleryFunds?) {
        self.archive = archive
        self.funds = funds
    }
}

public struct GalleryFunds: Sendable, Hashable {
    public var galleryPoints: String
    public var credits: String

    public init(galleryPoints: String, credits: String) {
        self.galleryPoints = galleryPoints
        self.credits = credits
    }
}

/// The image of one gallery page, resolved from its viewer page.
public struct PageImage: Sendable, Hashable {
    /// 1-based page index.
    public var index: Int
    public var imageURL: URL
    /// The full-resolution image, when the site offers one.
    public var originalImageURL: URL?

    public init(index: Int, imageURL: URL, originalImageURL: URL?) {
        self.index = index
        self.imageURL = imageURL
        self.originalImageURL = originalImageURL
    }
}

/// Keys of a gallery that uses the multi-page viewer.
public struct MPVKeys: Sendable, Hashable {
    public var mpvKey: String
    /// Image key per 1-based page index.
    public var imageKeys: [Int: String]

    public init(mpvKey: String, imageKeys: [Int: String]) {
        self.mpvKey = mpvKey
        self.imageKeys = imageKeys
    }
}

/// The image of one page of a multi-page-viewer gallery.
public struct MPVPageImage: Sendable, Hashable {
    public var image: PageImage
    /// Pass this back when reloading the page to make the site pick another image server.
    public var skipServerIdentifier: String

    public init(image: PageImage, skipServerIdentifier: String) {
        self.image = image
        self.skipServerIdentifier = skipServerIdentifier
    }
}
