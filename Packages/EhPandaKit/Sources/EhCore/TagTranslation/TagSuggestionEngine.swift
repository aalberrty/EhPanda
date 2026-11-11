import EhDatabase
import EhModels
import Foundation

/// Legacy `TagTranslationHandler`: splits the search text into keywords and ranks the
/// translations that match them. Pure apart from the database search it is handed.
public enum TagSuggestionEngine {
    /// Rows fetched from the database per keyword before ranking. The database orders prefix
    /// matches and shorter tags first, so for keywords matching more rows than this the
    /// heaviest legacy matches can be missing (see `TagTranslationService.suggestions`).
    static let candidateLimit = 1500

    /// What legacy wrote back into the search field on every keystroke: runs of spaces
    /// collapsed and full-width colons replaced.
    public static func normalizedSearchText(_ text: String) -> String {
        text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "：", with: ":")
    }

    /// `Defaults.Regex.tagSuggestion` tokens of normalised text.
    static func tokens(of text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(\S+:".+?"|".+?"|\S+:\S+|\S+)"#) else { return [] }
        // Legacy passed `text.count` as the UTF-16 length, cutting off text after emoji.
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    /// The keywords to look up: every suffix of the tokens after the last completed tag (one
    /// ending in `"` or `$`), longest first, each joined with spaces.
    static func keywords(of text: String) -> [String] {
        let tokens = tokens(of: text)
        let lastCompleted = tokens.lastIndex { $0.last == "\"" || $0.last == "$" }
        return ((lastCompleted ?? 0)..<tokens.count).map { tokens[$0...].joined(separator: " ") }
    }

    /// Splits a recognised `namespace:` or abbreviation prefix (`f:`, `Female:`) off `keyword`.
    /// `temp` has no abbreviation and, as in legacy, is not recognised.
    static func namespaceAndTerm(of keyword: String) -> (namespace: TagNamespace?, term: String) {
        guard let colon = keyword.firstIndex(of: ":") else { return (nil, keyword) }
        let prefix = keyword[keyword.startIndex..<colon]
        let match = TagNamespace.abbreviations.first { rawValue, abbreviation in
            rawValue.compare(prefix, options: .caseInsensitive) == .orderedSame
                || abbreviation.compare(prefix, options: .caseInsensitive) == .orderedSame
        }
        guard let rawValue = match?.key, let namespace = TagNamespace(rawValue: rawValue) else {
            return (nil, keyword)
        }
        return (namespace, String(keyword[keyword.index(after: colon)...]))
    }

    /// Ranks `candidates` for one keyword as legacy's `getSuggestions` did: drop other
    /// namespaces, score with `TagTranslation.getSuggestion`, keep positive scores, heaviest
    /// first. Ties keep the candidates' order.
    static func ranked(
        _ candidates: [TagTranslation], term: String, originalKeyword: String, namespace: TagNamespace?
    ) -> [TagSuggestion] {
        let suggestions = candidates
            .filter { namespace == nil || $0.namespace == namespace }
            .map {
                $0.getSuggestion(keyword: term, originalKeyword: originalKeyword, matchesNamespace: namespace != nil)
            }
            .filter { $0.weight > 0 }
        return suggestions.enumerated()
            .sorted { lhs, rhs in
                guard lhs.element.weight != rhs.element.weight else { return lhs.offset < rhs.offset }
                return lhs.element.weight > rhs.element.weight
            }
            .map(\.element)
    }

    /// Legacy's namespace-only suggestions (`f:` with nothing after it): every translation in
    /// the namespace, unweighted.
    static func namespaceOnly(_ candidates: [TagTranslation], originalKeyword: String) -> [TagSuggestion] {
        candidates.map {
            TagSuggestion(
                tag: $0, weight: 0, keyRange: nil, valueRange: nil,
                originalKeyword: originalKeyword, matchesNamespace: true
            )
        }
    }

    /// Appends `suggestions` that are not already present, by search keyword.
    static func merge(_ suggestions: [TagSuggestion], into result: inout [TagSuggestion], seen: inout Set<String>) {
        for suggestion in suggestions where seen.insert(suggestion.tag.searchKeyword).inserted {
            result.append(suggestion)
        }
    }

    /// Legacy `autoComplete`: replaces the typed keyword at the end of `text` with the
    /// suggestion's exact search keyword and a trailing space.
    public static func autoComplete(_ suggestion: TagSuggestion, in text: String) -> String {
        let text = normalizedSearchText(text)
        let dropCount = min(suggestion.originalKeyword.count, text.count)
        return String(text.dropLast(dropCount)) + suggestion.tag.searchKeyword + " "
    }
}
