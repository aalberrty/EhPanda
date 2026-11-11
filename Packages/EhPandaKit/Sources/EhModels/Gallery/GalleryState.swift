import Foundation

/// Per-gallery state that outlives a visit: tags, comments, reading progress and the
/// image URLs discovered so far, keyed by 1-based page index.
public struct GalleryState: Codable, Sendable, Equatable, CustomStringConvertible {
    public let gid: String
    public var tags: [GalleryTag]
    public var readingProgress: Int
    public var previewURLs: [Int: URL]
    public var previewConfig: PreviewConfig?
    public var comments: [GalleryComment]
    public var imageURLs: [Int: URL]
    public var originalImageURLs: [Int: URL]
    public var thumbnailURLs: [Int: URL]

    public init(
        gid: String,
        tags: [GalleryTag] = [],
        readingProgress: Int = 0,
        previewURLs: [Int: URL] = [:],
        previewConfig: PreviewConfig? = nil,
        comments: [GalleryComment] = [],
        imageURLs: [Int: URL] = [:],
        originalImageURLs: [Int: URL] = [:],
        thumbnailURLs: [Int: URL] = [:]
    ) {
        self.gid = gid
        self.tags = tags
        self.readingProgress = readingProgress
        self.previewURLs = previewURLs
        self.previewConfig = previewConfig
        self.comments = comments
        self.imageURLs = imageURLs
        self.originalImageURLs = originalImageURLs
        self.thumbnailURLs = thumbnailURLs
    }

    public static let empty = GalleryState(gid: "")
    public static let preview = GalleryState(gid: "")

    public var description: String {
        let params: [String: Any] = [
            "gid": gid,
            "tagsCount": tags.count,
            "readingProgress": readingProgress,
            "previewURLsCount": previewURLs.count,
            "previewConfig": String(describing: previewConfig),
            "commentsCount": comments.count,
            "imageURLsCount": imageURLs.count,
            "originalImageURLsCount": originalImageURLs.count,
            "thumbnailURLsCount": thumbnailURLs.count
        ]
        return "GalleryState(\(params))"
    }
}
