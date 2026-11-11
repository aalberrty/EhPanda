import Dependencies
import EhCore
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
        SearchTagSuggestion(suggestion: suggestion, displayValue: displayValue.removingEmojiPresentation, imageURL: nil)
    }
}

/// The first suggestions for a text, and how many matched in all.
nonisolated public struct TagSuggestionResults: Sendable, Equatable {
    public let items: [SearchTagSuggestion]
    public let matchCount: Int

    public init(items: [SearchTagSuggestion], matchCount: Int) {
        self.items = items
        self.matchCount = matchCount
    }

    public static let none = TagSuggestionResults(items: [], matchCount: 0)
}

/// Where the search fields get their tag suggestions. Ranking runs off the main actor.
nonisolated public struct TagSuggestionSource: Sendable {
    /// Whether a translation dictionary is installed (legacy hid suggestions without one).
    public var hasTranslations: @Sendable () async -> Bool
    /// Ranked, de-duplicated suggestions for everything typed after the last completed tag;
    /// at most `limit` items, with the total count.
    public var suggestions: @Sendable (_ text: String, _ limit: Int) async -> TagSuggestionResults

    public init(
        hasTranslations: @escaping @Sendable () async -> Bool,
        suggestions: @escaping @Sendable (_ text: String, _ limit: Int) async -> TagSuggestionResults
    ) {
        self.hasTranslations = hasTranslations
        self.suggestions = suggestions
    }

    public static let unavailable = TagSuggestionSource(hasTranslations: { false }, suggestions: { _, _ in .none })

    /// Suggestions from the tag translation dictionary.
    public static func service(_ service: TagTranslationService) -> TagSuggestionSource {
        TagSuggestionSource(
            hasTranslations: { await !service.isEmpty },
            suggestions: { text, limit in await results(for: text, limit: limit, service: service) }
        )
    }

    @MainActor
    private static func results(
        for text: String, limit: Int, service: TagTranslationService
    ) async -> TagSuggestionResults {
        // `suggestions(for:)` ranks off the main actor; only the shown rows are looked up here.
        let found = await service.suggestions(for: text)
        let items = found.prefix(limit).map { suggestion in
            let key = TagTranslationService.key(namespace: suggestion.tag.namespace, tag: suggestion.tag.key)
            let display = service.display(forKey: key)
            return SearchTagSuggestion(
                suggestion: suggestion,
                displayValue: display?.displayValue ?? suggestion.tag.value,
                imageURL: display?.valueImageURL
            )
        }
        return TagSuggestionResults(items: items, matchCount: found.count)
    }
}

nonisolated enum TagSuggestionSourceKey: DependencyKey {
    static var liveValue: TagSuggestionSource {
        @Dependency(\.tagTranslationService) var service
        return .service(service)
    }

    static let testValue = TagSuggestionSource.unavailable
    static let previewValue = TagSuggestionSource.unavailable
}

nonisolated extension DependencyValues {
    public var tagSuggestionSource: TagSuggestionSource {
        get { self[TagSuggestionSourceKey.self] }
        set { self[TagSuggestionSourceKey.self] = newValue }
    }
}
