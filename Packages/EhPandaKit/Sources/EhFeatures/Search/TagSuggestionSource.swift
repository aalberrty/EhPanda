import Dependencies
import EhModels
import Foundation

/// A tag suggestion ready to show: the match, plus the plain-text and image renderings of the
/// translation's Markdown value.
nonisolated public struct SearchTagSuggestion: Hashable, Identifiable, Sendable {
    public let suggestion: TagSuggestion
    /// `tag.value` as plain text.
    public let displayValue: String
    public let imageURL: URL?

    public init(suggestion: TagSuggestion, displayValue: String, imageURL: URL?) {
        self.suggestion = suggestion
        self.displayValue = displayValue
        self.imageURL = imageURL
    }

    /// Suggestions are de-duplicated by the keyword they insert, so it is a stable identity.
    public var id: String { suggestion.tag.searchKeyword }

    /// For "Shows images in tags" off: no image, and emoji removed from the text as in legacy.
    public func withoutImages() -> SearchTagSuggestion {
        let text = String(String.UnicodeScalarView(displayValue.unicodeScalars.filter {
            !$0.properties.isEmojiPresentation
        }))
        return SearchTagSuggestion(suggestion: suggestion, displayValue: text, imageURL: nil)
    }
}

/// Where the search fields get their tag suggestions.
///
/// This is the only place search touches tag translations. Both closures run off the main actor.
nonisolated public struct TagSuggestionSource: Sendable {
    /// Whether a translation dictionary is installed (legacy hid suggestions without one).
    public var hasTranslations: @Sendable () async -> Bool
    /// Ranked, de-duplicated suggestions for everything typed after the last completed tag.
    public var suggestions: @Sendable (_ text: String) async -> [SearchTagSuggestion]

    public init(
        hasTranslations: @escaping @Sendable () async -> Bool,
        suggestions: @escaping @Sendable (_ text: String) async -> [SearchTagSuggestion]
    ) {
        self.hasTranslations = hasTranslations
        self.suggestions = suggestions
    }

    public static let unavailable = TagSuggestionSource(hasTranslations: { false }, suggestions: { _ in [] })
}

nonisolated enum TagSuggestionSourceKey: DependencyKey {
    // TODO: Back this with `TagTranslationService` (EhCore) once it lands: `hasTranslations`
    // from its dictionary and `suggestions` from its ranking. Until then search shows none.
    static let liveValue = TagSuggestionSource.unavailable
    static let testValue = TagSuggestionSource.unavailable
    static let previewValue = TagSuggestionSource.unavailable
}

nonisolated extension DependencyValues {
    public var tagSuggestionSource: TagSuggestionSource {
        get { self[TagSuggestionSourceKey.self] }
        set { self[TagSuggestionSourceKey.self] = newValue }
    }
}
