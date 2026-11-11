@testable import EhDatabase
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct TagTranslationTests {
    static func entry(
        _ namespace: TagNamespace, _ tag: String, _ display: String, image: String? = nil
    ) -> StoredTagTranslation {
        StoredTagTranslation(
            key: namespace.rawValue + tag,
            translation: TagTranslation(
                namespace: namespace, key: tag, value: image.map { "![](\($0))\(display)" } ?? display,
                description: "about \(tag)", linksString: "[wiki](https://example.org/\(tag))"
            ),
            displayValue: display,
            valueImageURL: image.flatMap(URL.init(string:))
        )
    }

    static let samples = [
        entry(.female, "big breasts", "巨乳"),
        entry(.female, "glasses", "眼镜", image: "https://example.org/g.png"),
        entry(.male, "glasses", "眼镜男"),
        entry(.language, "chinese", "中文"),
        entry(.artist, "100%_artist", "百分")
    ]

    @Test func replaceStoresAndReplacesEverything() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.replaceTagTranslations(Self.samples)
        #expect(try await database.tagTranslationCount() == 5)

        try await database.replaceTagTranslations([Self.entry(.parody, "original", "原创")])
        #expect(try await database.tagTranslationCount() == 1)
        #expect(try await database.tagTranslations(keys: ["femaleglasses"]).isEmpty)
    }

    @Test func lookupHasDisplayDataForEveryKey() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.replaceTagTranslations(Self.samples)
        let lookup = try await database.tagTranslationLookup()
        #expect(lookup.count == 5)
        #expect(lookup["femaleglasses"] == TagTranslationDisplay(
            displayValue: "眼镜", valueImageURL: URL(string: "https://example.org/g.png")
        ))
        #expect(lookup["femalebig breasts"] == TagTranslationDisplay(displayValue: "巨乳", valueImageURL: nil))
    }

    @Test func fetchesFullRecordsByKey() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.replaceTagTranslations(Self.samples)
        let records = try await database.tagTranslations(keys: ["femaleglasses", "languagechinese", "missing"])
        #expect(records.count == 2)
        #expect(records["femaleglasses"] == Self.samples[1])
        #expect(records["languagechinese"] == Self.samples[3])
        #expect(try await database.tagTranslations(keys: []).isEmpty)
    }

    @Test func fetchesManyKeysAcrossChunks() async throws {
        let database = try await TestDatabase.inMemory()
        let entries = (0..<1_200).map { Self.entry(.female, "tag\($0)", "值\($0)") }
        try await database.replaceTagTranslations(entries)
        let records = try await database.tagTranslations(keys: entries.map(\.key))
        #expect(records.count == 1_200)
    }

    @Test func searchMatchesTagOrDisplayValue() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.replaceTagTranslations(Self.samples)

        let byTag = try await database.searchTagTranslations(matching: "GLASS", limit: 10)
        #expect(Set(byTag.map(\.key)) == ["femaleglasses", "maleglasses"])

        let byDisplay = try await database.searchTagTranslations(matching: "眼镜", limit: 10)
        #expect(Set(byDisplay.map(\.key)) == ["femaleglasses", "maleglasses"])

        let limited = try await database.searchTagTranslations(matching: "s", limit: 2)
        #expect(limited.count == 2)

        #expect(try await database.searchTagTranslations(matching: "", limit: 10).isEmpty)
        #expect(try await database.searchTagTranslations(matching: "glasses", limit: 0).isEmpty)
    }

    @Test func searchRanksPrefixMatchesFirst() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.replaceTagTranslations([
            Self.entry(.female, "sole dickgirl", "a"),
            Self.entry(.female, "dickgirl on male", "b"),
            Self.entry(.female, "dickgirl", "c")
        ])
        let results = try await database.searchTagTranslations(matching: "dickgirl", limit: 10)
        #expect(results.map(\.translation.key) == ["dickgirl", "dickgirl on male", "sole dickgirl"])
    }

    @Test func searchTreatsWildcardsLiterally() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.replaceTagTranslations(Self.samples)
        let percent = try await database.searchTagTranslations(matching: "100%", limit: 10)
        #expect(percent.map(\.key) == ["artist100%_artist"])
        #expect(try await database.searchTagTranslations(matching: "%", limit: 10).count == 1)
        #expect(try await database.searchTagTranslations(matching: "_", limit: 10).count == 1)
    }

    @Test func deleteAllEmptiesTable() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.replaceTagTranslations(Self.samples)
        try await database.deleteAllTagTranslations()
        #expect(try await database.tagTranslationCount() == 0)
        #expect(try await database.tagTranslationLookup().isEmpty)
    }

    @Test func escapesLikePattern() {
        #expect(AppDatabase.escapeLikePattern(#"a%b_c\d"#) == #"a\%b\_c\\d"#)
    }
}
