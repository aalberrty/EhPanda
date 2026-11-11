import EhModels
import Foundation
import GRDB

/// What is known about one page of a gallery. Every field but the key is optional because
/// the URLs come from different requests and are merged as they arrive.
public struct GalleryPage: Sendable, Hashable {
    public var gid: String
    /// 1-based, as on the site.
    public var index: Int
    /// The page's HTML viewer page (legacy `thumbnailURLs`).
    public var pageURL: URL?
    public var imageURL: URL?
    public var originalImageURL: URL?
    public var previewURL: URL?
    /// The image's pixel size, recorded once it has loaded so the reader's layout is stable
    /// the next time the gallery is opened.
    public var imageWidth: Int?
    public var imageHeight: Int?

    public init(
        gid: String,
        index: Int,
        pageURL: URL? = nil,
        imageURL: URL? = nil,
        originalImageURL: URL? = nil,
        previewURL: URL? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil
    ) {
        self.gid = gid
        self.index = index
        self.pageURL = pageURL
        self.imageURL = imageURL
        self.originalImageURL = originalImageURL
        self.previewURL = previewURL
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }

    init(row: Row) {
        self.init(
            gid: row["gid"],
            index: row["pageIndex"],
            pageURL: row["pageURL"],
            imageURL: row["imageURL"],
            originalImageURL: row["originalImageURL"],
            previewURL: row["previewURL"],
            imageWidth: row["imageWidth"],
            imageHeight: row["imageHeight"]
        )
    }

    /// One page for every gallery page a preview page lists, with its viewer link and its
    /// thumbnail, ready for `AppDatabase.upsertPages`.
    public static func pages(gid: String, listedOn previewPage: PreviewPage) -> [GalleryPage] {
        previewPage.indices.sorted().map { index in
            GalleryPage(
                gid: gid, index: index,
                pageURL: previewPage.pageURLs[index], previewURL: previewPage.previewURLs[index]
            )
        }
    }

    var databaseArguments: StatementArguments {
        [
            gid, index,
            pageURL?.absoluteString, imageURL?.absoluteString,
            originalImageURL?.absoluteString, previewURL?.absoluteString,
            imageWidth, imageHeight
        ]
    }
}
