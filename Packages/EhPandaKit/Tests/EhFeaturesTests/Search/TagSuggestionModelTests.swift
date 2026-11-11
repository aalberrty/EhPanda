import Dependencies
import EhCore
import EhDatabase
import EhTestSupport
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
                suggestions: { [self] text, limit in
                    self.lookups.withLock { $0.append(text) }
                    let all = (0..<15).map { suggestion(key: "\(text)\($0)", value: "\(text) \($0) 😀") }
                    return TagSuggestionResults(items: Array(all.prefix(limit)), matchCount: all.count)
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
            suggestions: { text, _ in
                started.continuation.yield(text)
                if text == "slow" {
                    for await _ in gate.stream { break }
                }
                return TagSuggestionResults(items: [Self.suggestion(key: text, value: text)], matchCount: 1)
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
        #expect(TagSuggestionModel.complete("", with: suggestion) == "f:\"big breasts$\" ")
    }
}

@Suite struct TagSuggestionServiceSourceTests {
    @Test func rendersSuggestionsFromTheDictionary() async throws {
        let database = try await TestDatabase.inMemory()
        let glasses = TagTranslation(namespace: .female, key: "glasses", value: "眼镜")
        let gloves = TagTranslation(namespace: .female, key: "gloves", value: "手套")
        try await database.replaceTagTranslations([
            StoredTagTranslation(
                key: "femaleglasses", translation: glasses, displayValue: "眼镜",
                valueImageURL: URL(string: "https://example.com/g.png")
            ),
            StoredTagTranslation(key: "femalegloves", translation: gloves, displayValue: "手套", valueImageURL: nil)
        ])
        let service = withDependencies { $0.database = database } operation: {
            TagTranslationService.testValue
        }
        let source = TagSuggestionSource.service(service)
        #expect(await source.hasTranslations() == false)

        await service.load()
        #expect(await source.hasTranslations())

        let results = await source.suggestions("f:gl", 1)
        #expect(results.matchCount == 2)
        #expect(results.items.count == 1)
        let first = try #require(results.items.first)
        #expect(first.displayValue == (first.suggestion.tag.key == "glasses" ? "眼镜" : "手套"))
        #expect(TagSuggestionModel.complete("l:english$ f:gl", with: first.suggestion)
            == "l:english$ \(first.suggestion.tag.searchKeyword) ")
    }
}
