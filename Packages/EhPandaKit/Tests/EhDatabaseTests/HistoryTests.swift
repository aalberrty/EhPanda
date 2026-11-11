@testable import EhDatabase
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct HistoryTests {
    @Test func recordOpenedStoresGalleryWithOpenDate() async throws {
        let database = try await TestDatabase.inMemory()
        let gallery = SampleData.gallery("100")
        try await database.recordOpened(gallery, at: SampleData.date(1000))

        let stored = try #require(try await database.gallery(gid: "100"))
        #expect(stored.gid == "100")
        #expect(stored.token == gallery.token)
        #expect(stored.title == gallery.title)
        #expect(stored.rating == gallery.rating)
        #expect(stored.tags == gallery.tags)
        #expect(stored.category == gallery.category)
        #expect(stored.uploader == gallery.uploader)
        #expect(stored.pageCount == gallery.pageCount)
        #expect(stored.postedDate == gallery.postedDate)
        #expect(stored.coverURL == gallery.coverURL)
        #expect(stored.galleryURL == gallery.galleryURL)
        #expect(stored.lastOpenDate == SampleData.date(1000))
        #expect(try await database.gallery(gid: "missing") == nil)
    }

    @Test func recordOpenedAgainUpdatesRowAndDate() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordOpened(SampleData.gallery("1", title: "Old"), at: SampleData.date(1))
        try await database.recordOpened(SampleData.gallery("1", title: "New"), at: SampleData.date(2))
        let stored = try #require(try await database.gallery(gid: "1"))
        #expect(stored.title == "New")
        #expect(stored.lastOpenDate == SampleData.date(2))
        #expect(try await database.rowCount("gallery") == 1)
    }

    @Test func millisecondDatesRoundTrip() async throws {
        let database = try await TestDatabase.inMemory()
        let date = SampleData.date(123.456)
        try await database.recordOpened(SampleData.gallery("1"), at: date)
        let stored = try #require(try await database.gallery(gid: "1")?.lastOpenDate)
        #expect(abs(stored.timeIntervalSince(date)) < 0.001)
    }

    @Test func historyIsNewestFirstWithLimit() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordOpened(SampleData.gallery("1"), at: SampleData.date(10))
        try await database.recordOpened(SampleData.gallery("2"), at: SampleData.date(30))
        try await database.recordOpened(SampleData.gallery("3"), at: SampleData.date(20))

        let all = try await observe(database.observeHistory(), changes: [])
        #expect(all.first?.map(\.gid) == ["2", "3", "1"])
        let limited = try await observe(database.observeHistory(limit: 2), changes: [])
        #expect(limited.first?.map(\.gid) == ["2", "3"])
    }

    @Test func historyObservationEmitsOnChange() async throws {
        let database = try await TestDatabase.inMemory()
        let values = try await observe(database.observeHistory(), changes: [
            { try await database.recordOpened(SampleData.gallery("1"), at: SampleData.date(1)) },
            { try await database.recordOpened(SampleData.gallery("2"), at: SampleData.date(2)) },
            { try await database.clearHistory() }
        ])
        #expect(values.map { $0.map(\.gid) } == [[], ["1"], ["2", "1"], []])
    }

    @Test func clearHistoryDeletesAllGalleryData() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordOpened(SampleData.gallery("1"))
        try await database.saveDetail(SampleData.detail("1"))
        try await database.updateReadingProgress(gid: "1", progress: 5)
        try await database.upsertPages([GalleryPage(gid: "1", index: 1, imageURL: SampleData.url("1.jpg"))])
        // Rows for a gallery without a `gallery` row are cleared too.
        try await database.saveDetail(SampleData.detail("2"))
        try await database.recordSearchKeyword("kept")

        try await database.clearHistory()

        for table in ["gallery", "galleryDetail", "galleryState", "galleryPage"] {
            #expect(try await database.rowCount(table) == 0, "\(table)")
        }
        #expect(try await database.gallery(gid: "1") == nil)
        #expect(try await database.detail(gid: "1") == nil)
        #expect(try await database.state(gid: "1") == nil)
        #expect(try await database.pages(gid: "1").isEmpty)
        // Search history is a separate list with its own clear action.
        #expect(try await database.rowCount("searchHistory") == 1)
    }

    @Test func clearHistoryOnDiskLeavesDatabaseUsable() async throws {
        let (database, directory) = try await TestDatabase.onDisk()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await database.recordOpened(SampleData.gallery("1"))
        try await database.clearHistory()
        #expect(try await database.rowCount("gallery") == 0)
        try await database.recordOpened(SampleData.gallery("2"))
        #expect(try await database.rowCount("gallery") == 1)
    }
}
