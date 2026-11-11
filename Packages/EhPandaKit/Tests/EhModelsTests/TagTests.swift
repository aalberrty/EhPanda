import EhModels
import Foundation
import Testing

@Suite struct TagTests {
    static func content(_ namespace: String, _ text: String) -> (GalleryTag, GalleryTag.Content) {
        let content = GalleryTag.Content(
            rawNamespace: namespace, text: text, isVotedUp: false, isVotedDown: false, backgroundColor: nil
        )
        return (GalleryTag(rawNamespace: namespace, contents: [content]), content)
    }

    @Test(arguments: [
        ("female", "big breasts", #"f:"big breasts$""#, "f:big breasts"),
        ("cosplayer", "someone", "cos:someone$", "cos:someone"),
        ("temp", "two words", #""two words$""#, "two words"),
        ("Unknown", "thing", "unknown:thing$", "unknown:thing")
    ])
    func galleryTagKeywords(namespace: String, text: String, search: String, vote: String) {
        let (tag, content) = Self.content(namespace, text)
        #expect(content.searchKeyword(tag: tag) == search)
        #expect(content.voteKeyword(tag: tag) == vote)
    }

    @Test func galleryTagIdentity() {
        let (tag, content) = Self.content("language", "english")
        #expect(tag.id == "language" && tag.namespace == .language)
        #expect(content.id == "languageenglish")
        #expect(content.firstLetterCapitalizedText == "English")
    }

    @Test func translationSearchKeyword() {
        #expect(TagTranslation(namespace: .female, key: "big breasts", value: "").searchKeyword == #"f:"big breasts$""#)
        #expect(TagTranslation(namespace: .temp, key: "x", value: "").searchKeyword == "temp:x$")
    }

    @Test func suggestionWeighting() {
        let translation = TagTranslation(namespace: .female, key: "big breasts", value: "巨乳")
        let prefix = translation.getSuggestion(keyword: "big", originalKeyword: "f:big", matchesNamespace: true)
        #expect(prefix.weight == Float(9) * 4 / 11 * 2)
        #expect(prefix.keyRange.map { String(translation.key[$0]) } == "big")
        #expect(prefix.valueRange == nil)
        #expect(prefix.originalKeyword == "f:big" && prefix.matchesNamespace)

        let infix = translation.getSuggestion(keyword: "BREASTS", originalKeyword: "", matchesNamespace: false)
        #expect(infix.weight == Float(9) * 8 / 11)

        let both = translation.getSuggestion(keyword: "乳", originalKeyword: "", matchesNamespace: false)
        #expect(both.keyRange == nil)
        #expect(both.weight == Float(9) * 2 / 2)

        let none = translation.getSuggestion(keyword: "zzz", originalKeyword: "", matchesNamespace: false)
        #expect(none.weight == 0)
    }

    @Test func suggestionSegments() {
        let text = "big breasts"
        let range = text.range(of: "bre")
        let parts = TagSuggestion.segments(of: text, around: range)
        #expect(parts.before == "big " && parts.match == "bre" && parts.after == "asts")

        let whole = TagSuggestion.segments(of: text, around: nil)
        #expect(whole.before == text && whole.match.isEmpty && whole.after.isEmpty)

        let end = TagSuggestion.segments(of: text, around: text.range(of: "asts"))
        #expect(end.before == "big bre" && end.match == "asts" && end.after.isEmpty)
    }

    @Test func translatorLookup() {
        let translation = TagTranslation(namespace: .female, key: "big breasts", value: "巨乳")
        let translator = TagTranslator(translations: ["femalebig breasts": translation])
        let display: (TagTranslation) -> String = { $0.value }

        let prefixed = translator.lookup(word: "female:big breasts", returnOriginal: false, display: display)
        #expect(prefixed.0 == "female:巨乳" && prefixed.1 == translation)

        let original = translator.lookup(word: "female:big breasts", returnOriginal: true, display: display)
        #expect(original.0 == "female:big breasts" && original.1 == nil)

        let bare = translator.lookup(word: "big breasts", returnOriginal: false, display: display)
        #expect(bare.0 == "big breasts" && bare.1 == nil)
    }

    @Test func namespaceAbbreviations() {
        #expect(TagNamespace.abbreviations["female"] == "f")
        #expect(TagNamespace.abbreviations["cosplayer"] == "cos")
        #expect(TagNamespace.abbreviations["temp"] == nil)
        #expect(TagNamespace.abbreviations.count == TagNamespace.allCases.count - 1)
    }

    @Test func translatableLanguageMatching() {
        #expect(TranslatableLanguage.matching(preferredLanguage: "zh-Hans-CN") == .simplifiedChinese)
        #expect(TranslatableLanguage.matching(preferredLanguage: "zh-Hant-TW") == .traditionalChinese)
        #expect(TranslatableLanguage.matching(preferredLanguage: "ja-JP") == .japanese)
        #expect(TranslatableLanguage.matching(preferredLanguage: "en-GB") == .english)
        #expect(TranslatableLanguage.matching(preferredLanguage: "de-DE") == nil)
        #expect(TranslatableLanguage.traditionalChinese.repoName == "EhTagTranslation/Database")
    }

    @Test func databaseResponse() throws {
        let json = """
        { "data": [
            { "namespace": "female", "data": {
                "big breasts": { "name": "巨乳", "intro": "intro", "links": "links" },
                "glasses": { "name": "眼镜" } } },
            { "namespace": "rows", "data": { "female": { "name": "女性" } } }
        ] }
        """
        let response = try decodeJSON(EhTagTranslationDatabaseResponse.self, json)
        let translations = response.tagTranslations
        #expect(translations.count == 3 - 1)
        #expect(translations["femalebig breasts"] == TagTranslation(
            namespace: .female, key: "big breasts", value: "巨乳", description: "intro", linksString: "links"
        ))
        #expect(translations["femaleglasses"]?.description == nil)
    }
}
