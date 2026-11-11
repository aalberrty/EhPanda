import Foundation

/// The tags of one namespace on a gallery, e.g. every `female:` tag.
public struct GalleryTag: Codable, Sendable, Hashable, Identifiable {
    public var id: String { rawNamespace }
    public var namespace: TagNamespace? { .init(rawValue: rawNamespace) }

    public let rawNamespace: String
    public let contents: [Content]

    public init(rawNamespace: String, contents: [Content]) {
        self.rawNamespace = rawNamespace
        self.contents = contents
    }
}

extension GalleryTag {
    public struct Content: Codable, Sendable, Hashable, Identifiable {
        public var id: String { rawNamespace + text }

        public let rawNamespace: String
        public let text: String
        public let isVotedUp: Bool
        public let isVotedDown: Bool
        /// The highlight colour the site gives watched tags. The text colour is derived
        /// from it (see `RGBColor.isLight`), so it is not stored.
        public let backgroundColor: RGBColor?

        public init(
            rawNamespace: String,
            text: String,
            isVotedUp: Bool,
            isVotedDown: Bool,
            backgroundColor: RGBColor?
        ) {
            self.rawNamespace = rawNamespace
            self.text = text
            self.isVotedUp = isVotedUp
            self.isVotedDown = isVotedDown
            self.backgroundColor = backgroundColor
        }

        public var firstLetterCapitalizedText: String {
            text.firstLetterCapitalized
        }

        /// The keyword the site's tag-vote API expects, e.g. `f:big breasts`.
        public func voteKeyword(tag: GalleryTag) -> String {
            tag.namespace == .temp ? text : [tag.keywordNamespace, text].joined(separator: ":")
        }

        /// An exact-match search keyword, e.g. `f:"big breasts$"`.
        public func searchKeyword(tag: GalleryTag) -> String {
            let keyword = text.contains(" ") ? "\"\(text)$\"" : "\(text)$"
            return tag.namespace == .temp ? keyword : [tag.keywordNamespace, keyword].joined(separator: ":")
        }
    }

    private var keywordNamespace: String {
        namespace?.abbreviation ?? namespace?.rawValue ?? rawNamespace.lowercased()
    }
}

// MARK: Legacy decoding

extension GalleryTag.Content {
    // `textColor` is still present in legacy JSON; it is ignored when decoding.
    private enum CodingKeys: String, CodingKey {
        case rawNamespace, text, isVotedUp, isVotedDown, backgroundColor
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawNamespace = try container.decode(String.self, forKey: .rawNamespace)
        text = try container.decode(String.self, forKey: .text)
        isVotedUp = try container.decodeIfPresent(Bool.self, forKey: .isVotedUp) ?? false
        isVotedDown = try container.decodeIfPresent(Bool.self, forKey: .isVotedDown) ?? false
        // The legacy colour encoder could write an empty object; treat that as no colour
        // rather than losing the whole tag list.
        backgroundColor = try? container.decodeIfPresent(RGBColor.self, forKey: .backgroundColor)
    }
}
