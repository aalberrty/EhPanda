import EhModels
import Foundation

/// A comment with its body prepared for display, so rows never detect links or join text while
/// scrolling. Built off the main actor with `CommentItem.make(from:)`.
public nonisolated struct CommentItem: Identifiable, Equatable, Sendable {
    public let comment: GalleryComment
    /// The author without the site's trailing no-break spaces.
    public let author: String
    /// The body as legacy laid it out: one block per run, text runs carrying `link` attributes.
    public let blocks: [CommentBlock]
    /// The text and link-text runs in one string, for the detail screen's comment cards.
    public let summary: String

    public var id: String { comment.commentID }

    public init(comment: GalleryComment, detector: NSDataDetector?) {
        self.comment = comment
        author = comment.author.trimmingCharacters(in: .whitespacesAndNewlines)
        blocks = CommentBlock.blocks(for: comment.contents, detector: detector)
        summary = comment.contents
            .filter { [.plainText, .linkedText].contains($0.type) }
            .compactMap(\.text)
            .joined(separator: " ")
    }

    /// Prepares every comment in one pass, off the caller's actor.
    @concurrent
    public static func make(from comments: [GalleryComment]) async -> [CommentItem] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return comments.map { CommentItem(comment: $0, detector: detector) }
    }
}

/// One vertical block of a comment body.
public nonisolated enum CommentBlock: Equatable, Sendable {
    /// Text whose links (detected in plain text, or the run's own link) are `link` attributes.
    case text(AttributedString)
    /// One image (shown at half width) or two side by side (a quarter each), each optionally linked.
    case images([CommentImage])

    static func blocks(for contents: [CommentContent], detector: NSDataDetector?) -> [CommentBlock] {
        contents.compactMap { content in
            switch content.type {
            case .plainText:
                content.text.map { .text(linkified($0, detector: detector)) }
            case .linkedText:
                content.text.map { text in
                    var string = AttributedString(text)
                    string.link = content.link
                    return .text(string)
                }
            case .singleLink:
                content.link.map { link in
                    var string = AttributedString(link.absoluteString)
                    string.link = link
                    return .text(string)
                }
            case .singleImg, .linkedImg, .doubleImg, .doubleLinkedImg:
                images(of: content).map(CommentBlock.images)
            }
        }
    }

    /// Legacy showed two images only when both URLs were present, and linked them only when
    /// both links were.
    private static func images(of content: CommentContent) -> [CommentImage]? {
        guard let first = content.imgURL else { return nil }
        if let second = content.secondImgURL {
            let linked = content.link != nil && content.secondLink != nil
            return [
                CommentImage(imageURL: first, link: linked ? content.link : nil),
                CommentImage(imageURL: second, link: linked ? content.secondLink : nil)
            ]
        }
        return [CommentImage(imageURL: first, link: content.link)]
    }

    private static func linkified(_ text: String, detector: NSDataDetector?) -> AttributedString {
        var string = AttributedString(text)
        guard let detector else { return string }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let url = match.url, let textRange = Range(match.range, in: text),
                  let lower = AttributedString.Index(textRange.lowerBound, within: string),
                  let upper = AttributedString.Index(textRange.upperBound, within: string)
            else { continue }
            string[lower..<upper].link = url
        }
        return string
    }
}

public nonisolated struct CommentImage: Equatable, Sendable {
    public let imageURL: URL
    public let link: URL?

    public init(imageURL: URL, link: URL?) {
        self.imageURL = imageURL
        self.link = link
    }
}
