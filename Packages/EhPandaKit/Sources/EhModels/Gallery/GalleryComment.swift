import Foundation

public struct GalleryComment: Identifiable, Codable, Sendable, Hashable {
    public var id: String { commentID }

    public var votedUp: Bool
    public var votedDown: Bool
    public let votable: Bool
    public let editable: Bool

    public let score: String?
    public let author: String
    public let contents: [CommentContent]
    public let commentID: String
    public let commentDate: Date

    public init(
        votedUp: Bool,
        votedDown: Bool,
        votable: Bool,
        editable: Bool,
        score: String?,
        author: String,
        contents: [CommentContent],
        commentID: String,
        commentDate: Date
    ) {
        self.votedUp = votedUp
        self.votedDown = votedDown
        self.votable = votable
        self.editable = editable
        self.score = score
        self.author = author
        self.contents = contents
        self.commentID = commentID
        self.commentDate = commentDate
    }

    /// The comment's text with links spelled out, as used to prefill an edit.
    public var plainTextContent: String {
        contents
            .filter { [.plainText, .linkedText, .singleLink].contains($0.type) }
            .compactMap { $0.type == .singleLink ? $0.link?.absoluteString : $0.text }
            .joined()
    }
}

extension GalleryComment: DateFormattable {
    public var originalDate: Date { commentDate }
}
