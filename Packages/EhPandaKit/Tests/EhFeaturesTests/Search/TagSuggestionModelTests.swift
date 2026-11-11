import Dependencies
import EhCore
@testable import EhFeatures
import EhModels
import Foundation
import Synchronization
import Testing

@Suite struct TagSuggestionModelTests {
    /// Records each lookup and answers with one suggestion per typed text.
    nonisolated final class FakeSource: Sendable {
        let lookups = Mutex<[String]>([])
        let hasTranslations: Bool

        init(hasTranslations: Bool = true) {
            self.hasTranslations = hasTranslations
        }

        var source: TagSuggestionSource {
            TagSuggestionSource(
                hasTranslations: { [hasTranslations] in hasTranslations },
                suggestions: { [self] text in
                    self.lookups.withLock { $0.append(text) }
                    return (0..<15).map { suggestion(key: "\(text)\($0)", value: "\(text) \($0) 😀") }
                }
            )
        }
    }

    nonisolated private static func suggestion(key: String, value: String, original: String = "") -> SearchTagSuggestion {
        let tag = TagTranslation(namespace: .female, key: key, value: value)
        return SearchTagSuggestion(
            suggestion: TagSuggestion(
                tag: tag, weight: 1, keyRange: nil, valueRange: nil,
                originalKeyword: original, matchesNamespace: false
            ),
            displayValue: value, imageURL: URL(string: "https://example.com/a.png")
        )
    }

    private func makeModel(
        source: TagSuggestionSource, clock: some Clock<Duration>,
        configure: (SettingsStore) -> Void = { $0.enablesTagsExtension = true; $0.showsTagsSearchSuggestion = true }
    ) -> TagSuggestionModel {
        withDependencies {
            $0.tagSuggestionSource = source
            $0.continuousClock = clock
            let settings = $0.settings
            configure(settings)
            $0.settings = settings
        } operation: {
            TagSuggestionModel()
        }
    }

    @Test func looksUpOnlyAfterTheDebounce() async throws {
        let fake = FakeSource()
        let clock = ManualClock()
        let model = makeModel(source: fake.source, clock: clock)

        model.textDidChange("a")
        model.textDidChange("ab")
        model.textDidChange("abc")
        // Only the last keystroke's lookup is still waiting.
        try await eventually { clock.sleeperCount == 1 }
        clock.advance(by: TagSuggestionModel.debounce / 2)
        #expect(clock.sleeperCount == 1)
        #expect(fake.lookups.withLock { $0 }.isEmpty)

        clock.advance(by: TagSuggestionModel.debounce)
        try await eventually { !model.suggestions.isEmpty }

        // Earlier keystrokes were cancelled before their lookup ran.
        #expect(fake.lookups.withLock { $0 } == ["abc"])
        #expect(model.suggestions.count == TagSuggestionModel.displayLimit)
        #expect(model.matchCount == 15)
        #expect(model.suggestions.first?.suggestion.tag.key == "abc0")
    }

    @Test func aStaleLookupNeverOverwritesANewerOne() async throws {
        let gate = AsyncStream<Void>.makeStream()
        let started = AsyncStream<String>.makeStream()
        let source = TagSuggestionSource(
            hasTranslations: { true },
            suggestions: { text in
                started.continuation.yield(text)
                if text == "slow" {
                    for await _ in gate.stream { break }
                }
                return [Self.suggestion(key: text, value: text)]
            }
        )
        let model = makeModel(source: source, clock: NoWaitClock())
        var startedTexts = started.stream.makeAsyncIterator()

        model.textDidChange("slow")
        #expect(await startedTexts.next() == "slow")
        model.textDidChange("fast")
        try await eventually { model.suggestions.first?.suggestion.tag.key == "fast" }

        gate.continuation.yield()
        try await Task.sleep(for: .milliseconds(50))
        #expect(model.suggestions.map(\.suggestion.tag.key) == ["fast"])
    }

    @Test func emptyTextClearsSuggestions() async throws {
        let fake = FakeSource()
        let model = makeModel(source: fake.source, clock: NoWaitClock())
        model.textDidChange("a")
        try await eventually { !model.suggestions.isEmpty }

        model.textDidChange("  ")

        #expect(model.suggestions.isEmpty)
        #expect(model.matchCount == 0)
    }

    @Test(arguments: [(true, false), (false, true), (false, false)])
    func settingsTurnSuggestionsOff(extensionOn: Bool, suggestionsOn: Bool) async throws {
        let fake = FakeSource()
        let model = makeModel(source: fake.source, clock: NoWaitClock()) {
            $0.enablesTagsExtension = extensionOn
            $0.showsTagsSearchSuggestion = suggestionsOn
        }
        #expect(!model.isEnabled)

        model.textDidChange("a")
        try await Task.sleep(for: .milliseconds(50))

        #expect(fake.lookups.withLock { $0 }.isEmpty)
        #expect(model.suggestions.isEmpty)
    }

    @Test func noDictionaryMeansNoSuggestions() async throws {
        let fake = FakeSource(hasTranslations: false)
        let model = makeModel(source: fake.source, clock: NoWaitClock())
        #expect(model.isEnabled)

        model.textDidChange("a")
        try await Task.sleep(for: .milliseconds(50))

        #expect(fake.lookups.withLock { $0 }.isEmpty)
        #expect(model.suggestions.isEmpty)
    }

    @Test func imagesAndEmojiFollowTheSetting() async throws {
        let fake = FakeSource()
        let model = makeModel(source: fake.source, clock: NoWaitClock())
        model.textDidChange("a")
        try await eventually { !model.suggestions.isEmpty }
        #expect(model.suggestions.first?.imageURL == nil)
        #expect(model.suggestions.first?.displayValue == "a 0 ")

        let withImages = makeModel(source: fake.source, clock: NoWaitClock()) {
            $0.enablesTagsExtension = true
            $0.showsTagsSearchSuggestion = true
            $0.showsImagesInTags = true
        }
        withImages.textDidChange("a")
        try await eventually { !withImages.suggestions.isEmpty }
        #expect(withImages.suggestions.first?.imageURL != nil)
        #expect(withImages.suggestions.first?.displayValue == "a 0 😀")
    }

    @Test func cancelStopsThePendingLookup() async throws {
        let fake = FakeSource()
        let clock = ManualClock()
        let model = makeModel(source: fake.source, clock: clock)

        model.textDidChange("a")
        model.cancel()
        clock.advance(by: TagSuggestionModel.debounce * 2)
        try await Task.sleep(for: .milliseconds(50))

        #expect(fake.lookups.withLock { $0 }.isEmpty)
    }

    @Test func normalisesSpacesAndFullWidthColons() {
        #expect(TagSuggestionModel.normalize("female：glasses   big  breasts") == "female:glasses big breasts")
        #expect(TagSuggestionModel.normalize("a b") == "a b")
    }

    @Test func completionReplacesTheTypedFragment() {
        let tag = TagTranslation(namespace: .female, key: "big breasts", value: "")
        let suggestion = TagSuggestion(
            tag: tag, weight: 1, keyRange: nil, valueRange: nil,
            originalKeyword: "f:big bre", matchesNamespace: true
        )

        #expect(TagSuggestionModel.complete("l:english$ f:big bre", with: suggestion)
            == "l:english$ f:\"big breasts$\" ")
        // A fragment that no longer ends the text is not cut out.
        #expect(TagSuggestionModel.complete("other", with: suggestion) == "other f:\"big breasts$\" ")
        #expect(TagSuggestionModel.complete("", with: suggestion) == "f:\"big breasts$\" ")
    }
}
