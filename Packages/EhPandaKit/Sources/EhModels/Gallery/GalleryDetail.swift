import Foundation

/// Everything the detail page shows about a gallery beyond its list entry.
public struct GalleryDetail: Codable, Sendable, Equatable {
    public let gid: String
    public var title: String
    public var jpnTitle: String?
    public var isFavorited: Bool
    public var visibility: GalleryVisibility
    public var rating: Float
    public var userRating: Float
    public var ratingCount: Int
    public let category: Category
    public let language: Language
    public let uploader: String
    public let postedDate: Date
    public let coverURL: URL?
    public var archiveURL: URL?
    public var parentURL: URL?
    public var favoritedCount: Int
    public var pageCount: Int
    public var sizeCount: Float
    public var sizeType: String
    public var torrentCount: Int

    public init(
        gid: String,
        title: String,
        jpnTitle: String? = nil,
        isFavorited: Bool,
        visibility: GalleryVisibility,
        rating: Float,
        userRating: Float,
        ratingCount: Int,
        category: Category,
        language: Language,
        uploader: String,
        postedDate: Date,
        coverURL: URL?,
        archiveURL: URL? = nil,
        parentURL: URL? = nil,
        favoritedCount: Int,
        pageCount: Int,
        sizeCount: Float,
        sizeType: String,
        torrentCount: Int
    ) {
        self.gid = gid
        self.title = title
        self.jpnTitle = jpnTitle
        self.isFavorited = isFavorited
        self.visibility = visibility
        self.rating = rating
        self.userRating = userRating
        self.ratingCount = ratingCount
        self.category = category
        self.language = language
        self.uploader = uploader
        self.postedDate = postedDate
        self.coverURL = coverURL
        self.archiveURL = archiveURL
        self.parentURL = parentURL
        self.favoritedCount = favoritedCount
        self.pageCount = pageCount
        self.sizeCount = sizeCount
        self.sizeType = sizeType
        self.torrentCount = torrentCount
    }
}

extension GalleryDetail {
    public static let empty = GalleryDetail(
        gid: "", title: "", isFavorited: false, visibility: .yes, rating: 0, userRating: 0,
        ratingCount: 0, category: .private, language: .japanese, uploader: "", postedDate: .now,
        coverURL: nil, favoritedCount: 0, pageCount: 0, sizeCount: 0, sizeType: "", torrentCount: 0
    )

    public static let preview = GalleryDetail(
        gid: "", title: "Preview", jpnTitle: "プレビュー", isFavorited: true, visibility: .yes,
        rating: 3.5, userRating: 4.0, ratingCount: 1919, category: .doujinshi, language: .japanese,
        uploader: "Anonymous", postedDate: .distantPast,
        coverURL: URL(string: "https://github.com/EhPanda-Team/Imageset/blob/main/JPGs/2.jpg?raw=true"),
        favoritedCount: 514, pageCount: 114, sizeCount: 514, sizeType: "MB", torrentCount: 101
    )

    /// The title up to the first `|`, with bracketed groups removed.
    public var trimmedTitle: String {
        TitleTrimming.trimmed(title)
    }

    /// The title the app shows: the Japanese title when preferred and the gallery has one.
    public func title(prefersJapanese: Bool) -> String {
        prefersJapanese ? jpnTitle ?? title : title
    }
}

extension GalleryDetail: DateFormattable {
    public var originalDate: Date { postedDate }
}
