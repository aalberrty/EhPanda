import EhModels
import Foundation

/// One namespace of the gallery's tags, ready to draw.
public nonisolated struct DetailTagRow: Identifiable, Equatable, Sendable {
    public let tag: GalleryTag
    public let chips: [DetailTagChip]

    public var id: String { tag.rawNamespace }
}

/// One tag with its translation and the keywords its actions use.
public nonisolated struct DetailTagChip: Identifiable, Equatable, Sendable {
    public let content: GalleryTag.Content
    /// Search keyword for a tap (`ns:tag$`).
    public let searchKeyword: String
    /// Keyword for the tag-vote API (`ns:tag`).
    public let voteKeyword: String
    /// The translated text, when the dictionary has the tag.
    public let translation: String?
    /// `translation` without emoji, shown when images in tags are off (legacy `emojisRipped`).
    public let translationWithoutEmoji: String?
    /// The image in the translation, if any.
    public let imageURL: URL?
    /// The tag detail sheet's content, when the translation has a description.
    public let detail: TagDetail?

    public var id: String { content.id }

    /// What the chip shows for the given settings.
    public func text(translates: Bool, showsImages: Bool) -> String {
        guard translates, let translation else { return content.text }
        return showsImages ? translation : translationWithoutEmoji ?? translation
    }

    /// Legacy offered tag votes only to logged-in users: withdraw when voted, else up or down.
    public var hasVote: Bool { content.isVotedUp || content.isVotedDown }

    /// The vote that withdraws the current one.
    public var withdrawVote: Int { content.isVotedUp ? -1 : 1 }
}

/// Translations of one gallery's tags, looked up once when its tags change.
public nonisolated struct TagTranslationSnapshot: Equatable, Sendable {
    public var displays: [String: TagTranslationDisplayValue]
    public var details: [String: TagDetail]

    public static let empty = TagTranslationSnapshot(displays: [:], details: [:])

    public init(displays: [String: TagTranslationDisplayValue], details: [String: TagDetail]) {
        self.displays = displays
        self.details = details
    }

    /// The dictionary key legacy looked a detail-screen tag up with: namespace and text, no colon.
    public static func key(for content: GalleryTag.Content) -> String {
        content.rawNamespace + content.text
    }
}

/// The translated text and image of one tag.
public nonisolated struct TagTranslationDisplayValue: Equatable, Sendable {
    public var text: String
    public var imageURL: URL?

    public init(text: String, imageURL: URL?) {
        self.text = text
        self.imageURL = imageURL
    }
}

extension DetailTagRow {
    nonisolated static func rows(for tags: [GalleryTag], translations: TagTranslationSnapshot) -> [DetailTagRow] {
        tags.map { tag in
            DetailTagRow(tag: tag, chips: tag.contents.map { content in
                let key = TagTranslationSnapshot.key(for: content)
                let display = translations.displays[key]
                return DetailTagChip(
                    content: content,
                    searchKeyword: DetailSearchKeyword.tag(content, in: tag),
                    voteKeyword: content.voteKeyword(tag: tag),
                    translation: display?.text,
                    translationWithoutEmoji: display.map { $0.text.removingEmojiPresentation },
                    imageURL: display?.imageURL,
                    detail: translations.details[key]
                )
            })
        }
    }
}

extension String {
    /// Drops characters that render as emoji by default, like legacy `emojisRipped`.
    nonisolated var removingEmojiPresentation: String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: unicodeScalars.filter { !$0.properties.isEmojiPresentation })
        return String(scalars)
    }
}
