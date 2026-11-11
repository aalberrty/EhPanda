import EhDatabase
import EhModels
import Foundation
import Testing
@testable import EhCore

@MainActor
@Suite struct TagTranslationImportTests {
    /// The JSON legacy wrote with `JSONEncoder()`: synthesized enum form for the language and
    /// seconds since 2001 for the date.
    static let legacyBlob = Data("""
        {
          "language": {"simplifiedChinese": {}},
          "hasCustomTranslations": false,
          "updatedDate": 700000000,
          "translations": {
            "femalebig breasts": {
              "namespace": "female", "key": "big breasts", "value": "巨乳",
              "description": "乳房较大。", "linksString": "[维基](https://a.b/)"
            },
            "parodytouhou project": {
              "namespace": "parody", "key": "touhou project",
              "value": "![阴阳玉图标](# \\"https://ehgt.org/touhou.webp\\")东方Project"
            }
          }
        }
        """.utf8)

    @Test func validBlobIsStoredWithMetadata() async throws {
        let harness = try await ServiceHarness.make()

        try await harness.service.importLegacyTranslator(Self.legacyBlob)

        let service = harness.service
        #expect(service.metadata == TagTranslationMetadata(
            language: .simplifiedChinese, updatedDate: Date(timeIntervalSinceReferenceDate: 700_000_000)
        ))
        #expect(service.display(forKey: "parodytouhou project") == TagTranslationDisplay(
            displayValue: "东方Project", valueImageURL: URL(string: "https://ehgt.org/touhou.webp")
        ))
        let stored = try await harness.database.tagTranslations(keys: ["femalebig breasts"])
        #expect(stored["femalebig breasts"]?.translation.linksString == "[维基](https://a.b/)")
        #expect(TagTranslationMetadata(defaults: harness.defaults) == service.metadata)
        // The imported date is respected by the next update check.
        let earlier = Date(timeIntervalSinceReferenceDate: 600_000_000)
        harness.remote.publish(.simplifiedChinese, date: earlier, translations: [:])
        await service.fetchUpdates()
        #expect(service.loadingState == .failed(.noUpdates))
    }

    @Test func customFlagSurvivesImport() async throws {
        let harness = try await ServiceHarness.make()
        let blob = Data(#"""
            {"hasCustomTranslations":true,"translations":{"femalea":{"namespace":"female","key":"a","value":"甲"}}}
            """#.utf8)
        try await harness.service.importLegacyTranslator(blob)
        #expect(harness.service.metadata == TagTranslationMetadata(hasCustomTranslations: true))
        #expect(harness.service.lookup(word: "female:a", returnOriginal: false).text == "female:甲")
    }

    @Test func nilBlobDoesNothing() async throws {
        let harness = try await ServiceHarness.make()
        try await harness.service.importLegacyTranslator(nil)
        #expect(harness.service.metadata == TagTranslationMetadata())
        #expect(try await harness.database.tagTranslationCount() == 0)
    }

    @Test func corruptBlobDoesNothing() async throws {
        let harness = try await ServiceHarness.make()
        harness.remote.publish(.simplifiedChinese, date: Samples.releaseDate, translations: Samples.chinese)
        await harness.service.fetchUpdates()

        try await harness.service.importLegacyTranslator(Data("{\"translations\": 42".utf8))

        #expect(harness.service.translations.count == 3)
        #expect(harness.service.language == .simplifiedChinese)
    }
}

@Suite struct TraditionalChineseConversionTests {
    static let source = Samples.keyed([
        Samples.translation(.female, "a", "头发里面为线", description: "头发"),
        Samples.translation(.other, "full color", "full color"),
        Samples.translation(.other, "memory", "内存")
    ])

    private func values(_ languages: [String]) -> [String: String] {
        TagTranslationPreparation.traditionalChineseConverted(Self.source, preferredLanguages: languages)
            .mapValues(\.value)
    }

    @Test func hongKongStandard() {
        let values = values(["zh-Hant-HK"])
        // 為 differs from plain traditionalisation (爲), 裏 from Taiwan (裡).
        #expect(values["femalea"] == "頭髮裏面為線")
        #expect(values["othermemory"] == "內存")
    }

    @Test func taiwanStandardWithIdioms() {
        let values = values(["zh-Hant-TW"])
        #expect(values["femalea"] == "頭髮裡面為線")
        #expect(values["othermemory"] == "記憶體")
    }

    @Test func otherLocalesUsePlainTraditionalisation() {
        let values = values(["zh-Hant"])
        #expect(values["femalea"] == "頭髮裏面爲線")
        #expect(values["othermemory"] == "內存")
    }

    @Test func fullColorFixUpAndUntouchedFields() {
        let converted = TagTranslationPreparation.traditionalChineseConverted(
            Self.source, preferredLanguages: ["zh-Hant"]
        )
        #expect(converted["otherfull color"]?.value == "全彩")
        #expect(converted["femalea"]?.description == "头发")
    }

    @Test func noPreferredLanguageLeavesValuesUnchanged() {
        let unchanged = TagTranslationPreparation.traditionalChineseConverted(Self.source, preferredLanguages: [])
        #expect(unchanged == Self.source)
    }
}
