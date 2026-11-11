@testable import EhDatabase
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct LegacyStoreTests {
    @Test func readsCompleteStore() async throws {
        let builder = try LegacyStoreBuilder()
        defer { builder.removeDirectory() }
        try LegacyFixtures.populateComplete(builder)
        builder.close()

        let store = LegacyStore(applicationSupportDirectory: builder.directory)
        #expect(store.url == builder.url)
        #expect(await store.exists())
        let snapshot = try await store.readSnapshot()

        let environment = snapshot.appEnvironment
        #expect(environment.user == Data(#"{"displayName":"panda"}"#.utf8))
        #expect(environment.setting == Data(#"{"galleryHost":"ExHentai"}"#.utf8))
        #expect(environment.searchFilter == Data(#"{"search":1}"#.utf8))
        #expect(environment.globalFilter == Data(#"{"global":1}"#.utf8))
        #expect(environment.watchedFilter == Data(#"{"watched":1}"#.utf8))
        #expect(environment.tagTranslator == Data(#"{"translations":{}}"#.utf8))
        #expect(environment.historyKeywords == Data(LegacyFixtures.historyKeywordsJSON.utf8))
        #expect(environment.quickSearchWords == Data(LegacyFixtures.quickSearchWordsJSON.utf8))

        #expect(snapshot.history.map(\.gid) == ["200", "300", "100"])
        let gallery = try #require(snapshot.history.last)
        #expect(gallery.token == "tok100")
        #expect(gallery.title == "Title 100")
        #expect(gallery.rating == 4.5)
        #expect(gallery.category == .manga)
        #expect(gallery.uploader == "uploader")
        #expect(gallery.pageCount == 30)
        #expect(gallery.postedDate == Date(timeIntervalSinceReferenceDate: 700_000_000))
        #expect(gallery.coverURL == URL(string: "https://ehgt.org/100.jpg"))
        #expect(gallery.galleryURL == URL(string: "https://e-hentai.org/g/100/tok100/"))
        #expect(gallery.lastOpenDate == Date(timeIntervalSinceReferenceDate: 700_000_100))
        #expect(gallery.tags.first?.contents.first?.text == "glasses")
        #expect(snapshot.history.first?.lastOpenDate == Date(timeIntervalSinceReferenceDate: 700_000_300.25))

        // Progress only for history galleries.
        #expect(snapshot.readingProgress == ["100": 12])
    }

    @Test func readsRowsStillInWriteAheadLog() async throws {
        let builder = try LegacyStoreBuilder()
        defer { builder.removeDirectory() }
        try LegacyFixtures.populateComplete(builder)
        // The builder's connection is open with checkpoints off, so the rows are only in the WAL.
        let walSize = try FileManager.default.attributesOfItem(atPath: builder.url.path + "-wal")[.size] as? Int
        #expect((walSize ?? 0) > 0)

        let snapshot = try await LegacyStore(url: builder.url).readSnapshot()
        #expect(snapshot.history.count == 3)
        #expect(snapshot.appEnvironment.user != nil)
    }

    @Test func nullBlobsAreNil() async throws {
        let builder = try LegacyStoreBuilder()
        defer { builder.removeDirectory() }
        try LegacyFixtures.insertAppEnv(builder, blobs: false)
        try LegacyFixtures.insertGallery(builder, gid: "1", lastOpenDate: .int(1), tags: .null)
        try builder.insert(into: "ZGALLERYMO", ["ZGID": .text("2"), "ZLASTOPENDATE": .int(2)])
        try builder.insert(into: "ZGALLERYMO", ["ZGID": .null, "ZLASTOPENDATE": .int(3)])
        builder.close()

        let snapshot = try await LegacyStore(url: builder.url).readSnapshot()
        #expect(snapshot.appEnvironment == LegacySnapshot.AppEnvironment())
        #expect(snapshot.history.map(\.gid) == ["2", "1"])
        #expect(snapshot.history.last?.tags.isEmpty == true)
        let sparse = try #require(snapshot.history.first)
        #expect(sparse.token == "" && sparse.title == "" && sparse.uploader == nil)
        #expect(sparse.category == .private)
        #expect(sparse.coverURL == nil && sparse.pageCount == 0)
        #expect(snapshot.readingProgress.isEmpty)
    }

    @Test func undecodableTagsAreDropped() async throws {
        let builder = try LegacyStoreBuilder()
        defer { builder.removeDirectory() }
        try LegacyFixtures.insertGallery(builder, gid: "1", lastOpenDate: .int(1), tags: LegacyFixtures.blob("not json"))
        builder.close()
        let snapshot = try await LegacyStore(url: builder.url).readSnapshot()
        #expect(snapshot.history.map(\.gid) == ["1"])
        #expect(snapshot.history.first?.tags.isEmpty == true)
    }

    @Test func missingColumnsAreSkipped() async throws {
        let builder = try LegacyStoreBuilder(omittingColumns: [
            "ZAPPENVMO": ["ZQUICKSEARCHWORDS", "ZWATCHEDFILTER"],
            "ZGALLERYMO": ["ZUPLOADER", "ZTAGS", "ZGALLERYURL"],
            "ZGALLERYSTATEMO": ["ZREADINGPROGRESS"]
        ])
        defer { builder.removeDirectory() }
        try LegacyFixtures.populateComplete(builder)
        builder.close()

        let snapshot = try await LegacyStore(url: builder.url).readSnapshot()
        #expect(snapshot.appEnvironment.quickSearchWords == nil)
        #expect(snapshot.appEnvironment.watchedFilter == nil)
        #expect(snapshot.appEnvironment.user != nil)
        #expect(snapshot.history.map(\.gid) == ["200", "300", "100"])
        #expect(snapshot.history.first?.uploader == nil)
        #expect(snapshot.history.first?.tags.isEmpty == true)
        #expect(snapshot.history.first?.galleryURL == nil)
        #expect(snapshot.readingProgress.isEmpty)
    }

    @Test func missingLastOpenDateColumnMeansNoHistory() async throws {
        let builder = try LegacyStoreBuilder(omittingColumns: ["ZGALLERYMO": ["ZLASTOPENDATE"]])
        defer { builder.removeDirectory() }
        try LegacyFixtures.populateComplete(builder)
        builder.close()
        let snapshot = try await LegacyStore(url: builder.url).readSnapshot()
        #expect(snapshot.history.isEmpty)
        #expect(snapshot.appEnvironment.user != nil)
    }

    @Test func missingTablesAreSkipped() async throws {
        let builder = try LegacyStoreBuilder(omittingTables: ["ZAPPENVMO", "ZGALLERYSTATEMO", "ZGALLERYDETAILMO"])
        defer { builder.removeDirectory() }
        try LegacyFixtures.populateComplete(builder)
        builder.close()

        let snapshot = try await LegacyStore(url: builder.url).readSnapshot()
        #expect(snapshot.appEnvironment == LegacySnapshot.AppEnvironment())
        #expect(snapshot.history.count == 3)
        #expect(snapshot.readingProgress.isEmpty)
    }

    @Test func storeWithNoGalleryTableIsEmpty() async throws {
        let builder = try LegacyStoreBuilder(omittingTables: ["ZGALLERYMO"])
        defer { builder.removeDirectory() }
        try LegacyFixtures.populateComplete(builder)
        builder.close()
        let snapshot = try await LegacyStore(url: builder.url).readSnapshot()
        #expect(snapshot.history.isEmpty && snapshot.readingProgress.isEmpty)
        #expect(snapshot.appEnvironment.setting != nil)
    }

    @Test func emptyFileIsEmptySnapshot() async throws {
        let directory = try TestDatabase.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LegacyStore(applicationSupportDirectory: directory)
        #expect(FileManager.default.createFile(atPath: store.url.path, contents: Data()))

        #expect(await store.exists())
        let snapshot = try await store.readSnapshot()
        #expect(snapshot.history.isEmpty)
        #expect(snapshot.readingProgress.isEmpty)
        #expect(snapshot.appEnvironment == LegacySnapshot.AppEnvironment())
    }

    @Test func missingFileDoesNotExistAndCannotBeRead() async throws {
        let directory = try TestDatabase.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LegacyStore(applicationSupportDirectory: directory)
        #expect(await !store.exists())
        await #expect(throws: (any Error).self) { try await store.readSnapshot() }
        // Reading must not have created the file.
        #expect(await !store.exists())
    }

    @Test func corruptFileThrows() async throws {
        let directory = try TestDatabase.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LegacyStore(applicationSupportDirectory: directory)
        let garbage = Data(repeating: 0x42, count: 4096)
        #expect(FileManager.default.createFile(atPath: store.url.path, contents: garbage))
        await #expect(throws: (any Error).self) { try await store.readSnapshot() }
    }

    @Test func readingDoesNotModifyStore() async throws {
        let builder = try LegacyStoreBuilder()
        defer { builder.removeDirectory() }
        try LegacyFixtures.populateComplete(builder)
        builder.close()
        let before = try Data(contentsOf: builder.url)
        _ = try await LegacyStore(url: builder.url).readSnapshot()
        #expect(try Data(contentsOf: builder.url) == before)
    }

    @Test func deleteFilesRemovesAllThreeAndIsIdempotent() async throws {
        let builder = try LegacyStoreBuilder()
        defer { builder.removeDirectory() }
        try LegacyFixtures.populateComplete(builder)
        let store = LegacyStore(url: builder.url)
        // While the builder is open, the -wal and -shm files exist.
        for url in store.fileURLs {
            #expect(FileManager.default.fileExists(atPath: url.path), "\(url.lastPathComponent)")
        }
        builder.close()

        try await store.deleteFiles()
        for url in store.fileURLs {
            #expect(!FileManager.default.fileExists(atPath: url.path), "\(url.lastPathComponent)")
        }
        #expect(await !store.exists())
        try await store.deleteFiles()
    }

    @Test(arguments: [
        (0.0, "2001-01-01T00:00:00Z"),
        (700_000_000.0, "2023-03-08T20:26:40Z"),
        (-31_622_400.0, "2000-01-01T00:00:00Z")
    ])
    func convertsCoreDataTimestamps(timestamp: Double, iso: String) throws {
        let expected = try #require(ISO8601DateFormatter().date(from: iso))
        #expect(LegacyDate.date(fromCoreDataTimestamp: timestamp) == expected)
    }
}
