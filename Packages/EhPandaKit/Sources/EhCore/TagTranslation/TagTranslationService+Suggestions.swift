import EhDatabase
import EhModels
import Foundation

extension TagTranslationService {
    /// Ranked tag suggestions for the search text being typed (legacy `TagTranslationHandler`),
    /// computed off the main actor. Cancel the calling task when the text changes.
    ///
    /// Each keyword is looked up with the database's contains-search instead of scanning every
    /// translation, then ranked with legacy's weights. Results match legacy whenever a keyword
    /// matches at most `TagSuggestionEngine.candidateLimit` rows; beyond that only the rows the
    /// database ranks first (prefix matches, then shorter tags) are weighed.
    ///
    /// Show `TagSuggestionEngine.normalizedSearchText(text)` in the search field, as legacy did.
    public func suggestions(for text: String) async -> [TagSuggestion] {
        guard !translations.isEmpty, let database = try? await database() else { return [] }
        return await Self.suggestions(for: text, database: database, keys: translations)
    }

    @concurrent
    nonisolated static func suggestions(
        for text: String, database: AppDatabase, keys table: [String: TagTranslationDisplay]
    ) async -> [TagSuggestion] {
        var result = [TagSuggestion]()
        var seen = Set<String>()
        for keyword in TagSuggestionEngine.keywords(of: TagSuggestionEngine.normalizedSearchText(text)) {
            guard !Task.isCancelled else { return [] }
            let (namespace, term) = TagSuggestionEngine.namespaceAndTerm(of: keyword)
            let suggestions: [TagSuggestion]
            do {
                if let namespace, term.isEmpty {
                    let candidates = try await translations(in: namespace, database: database, keys: table)
                    suggestions = TagSuggestionEngine.namespaceOnly(candidates, originalKeyword: keyword)
                } else {
                    let candidates = try await database.searchTagTranslations(
                        matching: term, limit: TagSuggestionEngine.candidateLimit
                    )
                    suggestions = TagSuggestionEngine.ranked(
                        candidates.map(\.translation), term: term, originalKeyword: keyword, namespace: namespace
                    )
                }
            } catch {
                return []
            }
            TagSuggestionEngine.merge(suggestions, into: &result, seen: &seen)
        }
        return result
    }

    /// The first `candidateLimit` translations of `namespace` by key. Legacy listed the whole
    /// namespace in dictionary (random) order.
    private nonisolated static func translations(
        in namespace: TagNamespace, database: AppDatabase, keys table: [String: TagTranslationDisplay]
    ) async throws -> [TagTranslation] {
        // No namespace's raw value is a prefix of another's, so the key prefix is unambiguous.
        let keys = table.keys.filter { $0.hasPrefix(namespace.rawValue) }.sorted()
            .prefix(TagSuggestionEngine.candidateLimit)
        let stored = try await database.tagTranslations(keys: Array(keys))
        return keys.compactMap { stored[$0]?.translation }.filter { $0.namespace == namespace }
    }
}
