import Foundation

/// A gallery as it appears in a list.
///
/// Equality and hashing cover every field, so a refreshed gallery with a new title, rating or
/// tags is a change that Observation and SwiftUI act on. "The same gallery" is `gid` (its `id`);
/// compare that explicitly where a different version of the gallery must still match.
public struct Gallery: Identifiable, Codable, Sendable, Hashable, CustomStringConvertible {
    public var id: String { gid }
    public let gid: String
    public let token: String

    public var title: String
    public var rating: Float
    public var tags: [GalleryTag]
    public let category: Category
    public var uploader: String?
    public var pageCount: Int
    public let postedDate: Date
    public let coverURL: URL?
    public let galleryURL: URL?
    public var lastOpenDate: Date?

    public init(
        gid: String,
        token: String,
        title: String,
        rating: Float,
        tags: [GalleryTag],
        category: Category,
        uploader: String? = nil,
        pageCount: Int,
        postedDate: Date,
        coverURL: URL?,
        galleryURL: URL?,
        lastOpenDate: Date? = nil
    ) {
        self.gid = gid
        self.token = token
        self.title = title
        self.rating = rating
        self.tags = tags
        self.category = category
        self.uploader = uploader
        self.pageCount = pageCount
        self.postedDate = postedDate
        self.coverURL = coverURL
        self.galleryURL = galleryURL
        self.lastOpenDate = lastOpenDate
    }

    public var description: String {
        "Gallery(\(gid))"
    }
}

extension Gallery {
    public static var empty: Gallery {
        .init(
            gid: UUID().uuidString, token: "", title: "", rating: 0, tags: [],
            category: .doujinshi, uploader: "", pageCount: 1, postedDate: .now,
            coverURL: nil, galleryURL: nil
        )
    }

    public static let preview = Gallery(
        gid: UUID().uuidString, token: "", title: "Preview", rating: 3.5, tags: [],
        category: .doujinshi, uploader: "Anonymous", pageCount: 1, postedDate: .now,
        coverURL: URL(string: "https://github.com/EhPanda-Team/Imageset/blob/main/JPGs/2.jpg?raw=true"),
        galleryURL: nil
    )

    public static func mockGalleries(count: Int, randomID: Bool = true) -> [Gallery] {
        guard randomID, count > 0 else {
            return Array(repeating: .empty, count: count)
        }
        return (0...count).map { _ in .empty }
    }

    /// The title up to the first `|`, with bracketed groups removed.
    public var trimmedTitle: String {
        TitleTrimming.trimmed(title)
    }

    /// The first recognised language among the gallery's `language:` tags.
    public var language: Language? {
        let rawValue = tags
            .first(where: { $0.namespace == .language })?.contents
            .first(where: { Language(rawValue: $0.firstLetterCapitalizedText) != nil })
            .map(\.firstLetterCapitalizedText) ?? ""
        return .init(rawValue: rawValue)
    }

    /// All tag contents, capped at `maximum` when it is positive.
    public func tagContents(maximum: Int) -> [GalleryTag.Content] {
        let tagContents = tags.flatMap(\.contents)
        guard maximum > 0 else { return tagContents }
        return Array(tagContents.prefix(maximum))
    }

    public var filledCount: Int { Int(rating) }
    public var halfFilledCount: Int { Int(rating - 0.5) == filledCount ? 1 : 0 }
    public var notFilledCount: Int { 5 - filledCount - halfFilledCount }
}

extension Gallery: DateFormattable {
    public var originalDate: Date { postedDate }
}
