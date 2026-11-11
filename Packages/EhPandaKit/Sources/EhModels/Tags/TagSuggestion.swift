import Foundation

/// A tag translation that matched a search keyword, with where it matched.
public struct TagSuggestion: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let tag: TagTranslation
    public let weight: Float
    /// Where the keyword matched in `tag.key`.
    public let keyRange: Range<String.Index>?
    /// Where the keyword matched in `tag.value`.
    public let valueRange: Range<String.Index>?
    public let originalKeyword: String
    public let matchesNamespace: Bool

    public init(
        id: UUID = .init(),
        tag: TagTranslation,
        weight: Float,
        keyRange: Range<String.Index>?,
        valueRange: Range<String.Index>?,
        originalKeyword: String,
        matchesNamespace: Bool
    ) {
        self.id = id
        self.tag = tag
        self.weight = weight
        self.keyRange = keyRange
        self.valueRange = valueRange
        self.originalKeyword = originalKeyword
        self.matchesNamespace = matchesNamespace
    }
}

extension TagSuggestion {
    /// `string` split into the parts before, inside and after `range`, for highlighting.
    ///
    /// `range` may come from a different rendering of the same text, so each part is
    /// bounds-checked on its own: whatever cannot be cut cleanly is dropped or kept whole.
    public static func segments(
        of string: String, around range: Range<String.Index>?
    ) -> (before: String, match: String, after: String) {
        guard let range else { return (string, "", "") }

        let before = string.endIndex >= range.lowerBound
            ? String(string[string.startIndex..<range.lowerBound]) : string
        let match = range.upperBound <= string.endIndex && range.lowerBound >= string.startIndex
            ? String(string[range]) : ""
        let after = range.upperBound < string.endIndex
            ? String(string[range.upperBound..<string.endIndex]) : ""
        return (before, match, after)
    }
}
