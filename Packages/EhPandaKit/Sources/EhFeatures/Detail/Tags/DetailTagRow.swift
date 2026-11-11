import EhDatabase
import EhModels
import Foundation

/// One namespace of the gallery's tags, ready to draw.
public nonisolated struct DetailTagRow: Identifiable, Equatable, Sendable {
    public let tag: GalleryTag
    public let chips: [DetailTagChip]

    public var id: String { tag.rawNamespace }
}

/// One tag with the keywords its actions use and its translation's detail sheet.
public nonisolated struct DetailTagChip: Identifiable, Equatable, Sendable {
    public let content: GalleryTag.Content
    /// Search keyword for a tap (`ns:tag$`).
    public let searchKeyword: String
    /// Keyword for the tag-vote API (`ns:tag`).
    public let voteKeyword: String
    /// The key legacy looked a detail-screen tag up with: namespace and text, no colon.
    public let translationKey: String
    /// The tag detail sheet's content, when the tag's translation has a description.
    public let detail: TagDetail?

    public var id: String { content.id }

    /// Legacy offered tag votes only to logged-in users: withdraw when voted, else up or down.
    public var hasVote: Bool { content.isVotedUp || content.isVotedDown }

    /// The vote that withdraws the current one.
    public var withdrawVote: Int { content.isVotedUp ? -1 : 1 }

    static func key(for content: GalleryTag.Content) -> String {
        content.rawNamespace + content.text
    }
}

extension DetailTagRow {
    nonisolated static func rows(for tags: [GalleryTag], details: [String: TagDetail]) -> [DetailTagRow] {
        tags.map { tag in
            DetailTagRow(tag: tag, chips: tag.contents.map { content in
                let key = DetailTagChip.key(for: content)
                return DetailTagChip(
                    content: content,
                    searchKeyword: DetailSearchKeyword.tag(content, in: tag),
                    voteKeyword: content.voteKeyword(tag: tag),
                    translationKey: key,
                    detail: details[key]
                )
            })
        }
    }

    /// Every translation key of `tags`.
    nonisolated static func translationKeys(of tags: [GalleryTag]) -> [String] {
        tags.flatMap(\.contents).map(DetailTagChip.key(for:))
    }
}
