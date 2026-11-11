import Dependencies
import EhCore
import EhModels
import Foundation
import Observation

/// Tag suggestions under a server search field.
///
/// Keystrokes are debounced and each new one cancels the lookup in flight, so only the text
/// the user paused on is ranked, and the ranking runs off the main actor in the source.
@Observable
public final class TagSuggestionModel {
    /// Legacy lists at most 10 suggestions.
    public static let displayLimit = 10
    public static let debounce: Duration = .milliseconds(200)

    /// The first ``displayLimit`` suggestions for the current text.
    public private(set) var suggestions: [SearchTagSuggestion] = []
    /// How many suggestions matched in total (the "N matches" header).
    public private(set) var matchCount = 0

    @ObservationIgnored private var lookup: Task<Void, Never>?
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.tagSuggestionSource) private var source
    @ObservationIgnored @Dependency(\.continuousClock) private var clock

    public init() {}

    /// The settings that turn suggestions on. A missing dictionary is checked per lookup.
    public var isEnabled: Bool {
        settings.enablesTagsExtension && settings.showsTagsSearchSuggestion
    }

    /// Call with the normalised field text after every change.
    public func textDidChange(_ text: String) {
        lookup?.cancel()
        guard isEnabled, !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            lookup = nil
            clear()
            return
        }
        let source = source
        let clock = clock
        lookup = Task { [weak self] in
            do {
                try await clock.sleep(for: Self.debounce)
            } catch {
                return
            }
            let hasTranslations = await source.hasTranslations()
            let found = hasTranslations ? await source.suggestions(text) : []
            guard !Task.isCancelled, let self else { return }
            let showsImages = settings.showsImagesInTags
            suggestions = found.prefix(Self.displayLimit).map { showsImages ? $0 : $0.withoutImages() }
            matchCount = found.count
        }
    }

    /// Stops the lookup in flight, e.g. when the field goes away.
    public func cancel() {
        lookup?.cancel()
        lookup = nil
    }

    private func clear() {
        if !suggestions.isEmpty { suggestions = [] }
        if matchCount != 0 { matchCount = 0 }
    }

    // MARK: Text

    /// Legacy normalisation while typing: runs of spaces become one, and the full-width colon
    /// that CJK keyboards type becomes `:`.
    nonisolated public static func normalize(_ text: String) -> String {
        text.replacing(/\ {2,}/, with: " ").replacing("：", with: ":")
    }

    /// `text` with the fragment `suggestion` matched replaced by its tag keyword and a space.
    nonisolated public static func complete(_ text: String, with suggestion: TagSuggestion) -> String {
        var kept = text
        while kept.last?.isWhitespace == true { kept.removeLast() }
        if kept.hasSuffix(suggestion.originalKeyword) {
            kept.removeLast(suggestion.originalKeyword.count)
        } else if !kept.isEmpty {
            kept += " "
        }
        return kept + suggestion.tag.searchKeyword + " "
    }
}
