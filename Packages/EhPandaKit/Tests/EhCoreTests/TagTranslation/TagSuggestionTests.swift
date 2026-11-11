import EhDatabase
import EhModels
import Foundation
import Testing
@testable import EhCore

/// Expected orders follow legacy's weight, `namespace.weight * (keyword.count + 1) / text.count`,
/// doubled for a prefix match, summed over the key and the raw value.
@MainActor
@Suite struct TagSuggestionTests {
    static let translations = Samples.keyed([
        Samples.translation(.female, "big breasts", "巨乳"),
        Samples.translation(.female, "big ass", "大屁股"),
        Samples.translation(.female, "breast feeding", "哺乳"),
        Samples.translation(.female, "lolicon", "萝莉"),
        Samples.translation(.male, "big penis", "大阴茎"),
        Samples.translation(.artist, "bigbang", "大爆炸"),
        Samples.translation(.language, "chinese", "汉语"),
        Samples.translation(.parody, "touhou project", "![阴阳玉图标](https://ehgt.org/touhou.webp)东方Project")
    ])

    private func makeService() async throws -> TagTranslationService {
        let harness = try await ServiceHarness.make()
        let prepared = await TagTranslationService.prepare(Self.translations, traditionalChineseFor: nil)
        try await harness.database.replaceTagTranslations(prepared.rows)
        await harness.service.load()
        return harness.service
    }

    private func keys(_ suggestions: [TagSuggestion]) -> [String] {
        suggestions.map { $0.tag.namespace.rawValue + ":" + $0.tag.key }
    }

    @Test func singleWordIsRankedByWeight() async throws {
        let service = try await makeService()
        let suggestions = await service.suggestions(for: "big")
        // big ass 10.29, big penis 7.56, big breasts 6.55, bigbang 2.86.
        #expect(keys(suggestions) == ["female:big ass", "male:big penis", "female:big breasts", "artist:bigbang"])
        #expect(suggestions.allSatisfy { $0.originalKeyword == "big" && !$0.matchesNamespace })
        #expect(suggestions.first?.keyRange == "big ass".range(of: "big"))
    }

    @Test func namespacePrefixAndAbbreviationFilter() async throws {
        let service = try await makeService()
        for text in ["f:big", "female:big", "F:big", "f：big"] {
            let suggestions = await service.suggestions(for: text)
            #expect(keys(suggestions) == ["female:big ass", "female:big breasts"], "\(text)")
            #expect(suggestions.allSatisfy { $0.matchesNamespace })
        }
        // `temp` has no abbreviation, so legacy treated `temp:` as part of the keyword.
        #expect(await service.suggestions(for: "temp:big").isEmpty)
    }

    @Test func namespaceAloneListsTheNamespace() async throws {
        let service = try await makeService()
        let suggestions = await service.suggestions(for: "f:")
        #expect(keys(suggestions) == [
            "female:big ass", "female:big breasts", "female:breast feeding", "female:lolicon"
        ])
        #expect(suggestions.allSatisfy { $0.weight == 0 && $0.matchesNamespace })
    }

    @Test func wordsAreJoinedThenSearchedAlone() async throws {
        let service = try await makeService()
        let suggestions = await service.suggestions(for: "big br")
        // "big br" matches big breasts (11.45); then "br": breast feeding (3.86), big breasts (dropped as seen).
        #expect(keys(suggestions) == ["female:big breasts", "female:breast feeding"])
        #expect(suggestions.map(\.originalKeyword) == ["big br", "br"])
    }

    @Test func completedTagsAreIgnored() async throws {
        let service = try await makeService()
        #expect(keys(await service.suggestions(for: #"f:"big breasts$" lol"#)) == ["female:lolicon"])
        #expect(keys(await service.suggestions(for: "female:big$ chi")) == ["language:chinese"])
        #expect(await service.suggestions(for: #"f:"big breasts$""#).isEmpty)
    }

    @Test func translatedTextMatches() async throws {
        let service = try await makeService()
        #expect(keys(await service.suggestions(for: "巨")) == ["female:big breasts"])
        #expect(keys(await service.suggestions(for: "东方")) == ["parody:touhou project"])
    }

    @Test func emptyTableHasNoSuggestions() async throws {
        let harness = try await ServiceHarness.make()
        #expect(await harness.service.suggestions(for: "big").isEmpty)
    }

    @Test func normalisationAndTokens() {
        #expect(TagSuggestionEngine.normalizedSearchText("big   breasts  f：x") == "big breasts f:x")
        #expect(TagSuggestionEngine.tokens(of: #"a:"b c" "d e" f:g h"#) == [#"a:"b c""#, #""d e""#, "f:g", "h"])
        #expect(TagSuggestionEngine.keywords(of: "a b c") == ["a b c", "b c", "c"])
        #expect(TagSuggestionEngine.keywords(of: "a$ b c") == ["a$ b c", "b c", "c"])
    }

    @Test func autoCompleteReplacesTheTypedKeyword() async throws {
        let service = try await makeService()
        let text = "search f:big b"
        let suggestions = await service.suggestions(for: text)
        let bigBreasts = try #require(suggestions.first {
            $0.tag.key == "big breasts" && $0.originalKeyword == "f:big b"
        })
        #expect(TagSuggestionEngine.autoComplete(bigBreasts, in: text) == #"search f:"big breasts$" "#)

        let chinese = try #require(await service.suggestions(for: "chi").first)
        #expect(TagSuggestionEngine.autoComplete(chinese, in: "chi") == "l:chinese$ ")
    }
}
