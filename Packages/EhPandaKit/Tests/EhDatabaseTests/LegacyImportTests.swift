@testable import EhDatabase
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct LegacyImportTests {
    func snapshot() async throws -> LegacySnapshot {
        let builder = try LegacyStoreBuilder()
        defer { builder.removeDirectory() }
        try LegacyFixtures.populateComplete(builder)
        builder.close()
        return try await LegacyStore(url: builder.url).readSnapshot()
    }

    func keywords(_ database: AppDatabase) async throws -> [String] {
        try await observe(database.observeSearchHistory(), changes: []).first ?? []
    }

    func words(_ database: AppDatabase) async throws -> [QuickSearchWord] {
        try await observe(database.observeQuickSearchWords(), changes: []).first ?? []
    }

    func history(_ database: AppDatabase) async throws -> [Gallery] {
        try await observe(database.observeHistory(), changes: []).first ?? []
    }

    @Test func importsHistoryProgressKeywordsAndQuickSearchWords() async throws {
        let database = try await TestDatabase.inMemory()
        let snapshot = try await snapshot()
        try await database.importLegacyData(snapshot, at: SampleData.date(800_000_000))

        let history = try await history(database)
        #expect(history.map(\.gid) == ["200", "300", "100"])
        let imported = try #require(try await database.gallery(gid: "100"))
        #expect(imported.title == "Title 100")
        #expect(imported.tags.first?.contents.first?.text == "glasses")
        #expect(imported.lastOpenDate == Date(timeIntervalSinceReferenceDate: 700_000_100))
        #expect(try await database.state(gid: "100")?.readingProgress == 12)
        #expect(try await database.state(gid: "200") == nil)

        #expect(try await keywords(database) == ["newest", "middle", "oldest"])
        let id = try #require(UUID(uuidString: LegacyFixtures.quickSearchWordID))
        #expect(try await words(database) == [QuickSearchWord(id: id, name: "Mine", content: "f:glasses$")])

        // Disposable caches are not imported.
        #expect(try await database.rowCount("galleryDetail") == 0)
        #expect(try await database.rowCount("galleryPage") == 0)
    }

    @Test func secondImportIsHarmless() async throws {
        let database = try await TestDatabase.inMemory()
        let snapshot = try await snapshot()
        try await database.importLegacyData(snapshot, at: SampleData.date(800_000_000))
        try await database.importLegacyData(snapshot, at: SampleData.date(800_000_100))

        #expect(try await database.rowCount("gallery") == 3)
        #expect(try await database.rowCount("galleryState") == 1)
        #expect(try await keywords(database) == ["newest", "middle", "oldest"])
        #expect(try await words(database).count == 1)
    }

    @Test func existingDataWins() async throws {
        let database = try await TestDatabase.inMemory()
        // Used in v2 before a (repeated) import.
        try await database.recordOpened(SampleData.gallery("100", title: "Fresh"), at: SampleData.date(900_000_000))
        try await database.updateReadingProgress(gid: "100", progress: 20)
        try await database.recordSearchKeyword("MIDDLE", at: SampleData.date(900_000_000))

        try await database.importLegacyData(try await snapshot(), at: SampleData.date(800_000_000))

        let gallery = try #require(try await database.gallery(gid: "100"))
        #expect(gallery.title == "Fresh")
        #expect(gallery.lastOpenDate == SampleData.date(900_000_000))
        #expect(try await database.state(gid: "100")?.readingProgress == 20)
        #expect(try await keywords(database) == ["MIDDLE", "newest", "oldest"])
    }

    @Test func olderV2OpenDateIsMovedForward() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordOpened(SampleData.gallery("100"), at: SampleData.date(1))
        try await database.importLegacyData(try await snapshot())
        #expect(try await database.gallery(gid: "100")?.lastOpenDate == Date(timeIntervalSinceReferenceDate: 700_000_100))
    }

    @Test func emptyAndUndecodableSnapshotsImportNothing() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.importLegacyData(LegacySnapshot())
        try await database.importLegacyData(LegacySnapshot(appEnvironment: .init(
            historyKeywords: Data("{".utf8), quickSearchWords: Data("[1]".utf8)
        )))
        for table in ["gallery", "galleryState", "searchHistory", "quickSearchWord"] {
            #expect(try await database.rowCount(table) == 0, "\(table)")
        }
    }

    @Test func importKeepsSearchHistoryLimit() async throws {
        let database = try await TestDatabase.inMemory()
        let keywords = (0..<30).map { "k\($0)" }
        let blob = try JSONEncoder().encode(keywords)
        try await database.importLegacyData(LegacySnapshot(appEnvironment: .init(historyKeywords: blob)))
        let stored = try await self.keywords(database)
        #expect(stored.count == AppDatabase.searchHistoryLimit)
        #expect(stored.first == "k29")
    }

    @Test func endToEndImportThenDelete() async throws {
        let builder = try LegacyStoreBuilder()
        defer { builder.removeDirectory() }
        try LegacyFixtures.populateComplete(builder)
        builder.close()

        let (database, directory) = try await TestDatabase.onDisk()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LegacyStore(applicationSupportDirectory: builder.directory)
        #expect(await store.exists())
        try await database.importLegacyData(try await store.readSnapshot())
        try await store.deleteFiles()
        #expect(await !store.exists())
        #expect(try await database.rowCount("gallery") == 3)
    }
}
