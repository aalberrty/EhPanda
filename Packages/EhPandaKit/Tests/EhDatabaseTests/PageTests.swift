@testable import EhDatabase
import EhTestSupport
import Foundation
import Testing

@Suite struct PageTests {
    @Test func upsertInsertsAndFetchesInOrder() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.upsertPages([
            GalleryPage(gid: "1", index: 2, imageURL: SampleData.url("2.jpg")),
            GalleryPage(gid: "1", index: 1, pageURL: SampleData.url("s/a/1-1"), imageURL: SampleData.url("1.jpg"),
                        originalImageURL: SampleData.url("1.png"), previewURL: SampleData.url("p1.jpg"),
                        imageWidth: 1280, imageHeight: 1800),
            GalleryPage(gid: "2", index: 1, imageURL: SampleData.url("other.jpg"))
        ])
        let pages = try await database.pages(gid: "1")
        #expect(pages == [
            GalleryPage(gid: "1", index: 1, pageURL: SampleData.url("s/a/1-1"), imageURL: SampleData.url("1.jpg"),
                        originalImageURL: SampleData.url("1.png"), previewURL: SampleData.url("p1.jpg"),
                        imageWidth: 1280, imageHeight: 1800),
            GalleryPage(gid: "1", index: 2, imageURL: SampleData.url("2.jpg"))
        ])
        #expect(try await database.pages(gid: "missing").isEmpty)
    }

    @Test func upsertOverwritesOnlyNonNilFields() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.upsertPages([
            GalleryPage(gid: "1", index: 1, pageURL: SampleData.url("s/1"), previewURL: SampleData.url("p1"))
        ])
        // Image URLs arrive later from another request.
        try await database.upsertPages([
            GalleryPage(gid: "1", index: 1, imageURL: SampleData.url("i1"), originalImageURL: SampleData.url("o1"))
        ])
        // The reader records the size; a refreshed image URL replaces the old one.
        try await database.upsertPages([
            GalleryPage(gid: "1", index: 1, imageURL: SampleData.url("i1-new"), imageWidth: 800, imageHeight: 1200)
        ])
        let page = try #require(try await database.pages(gid: "1").first)
        #expect(page == GalleryPage(
            gid: "1", index: 1, pageURL: SampleData.url("s/1"), imageURL: SampleData.url("i1-new"),
            originalImageURL: SampleData.url("o1"), previewURL: SampleData.url("p1"),
            imageWidth: 800, imageHeight: 1200
        ))
    }

    @Test func duplicateKeysInOneBatchMerge() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.upsertPages([
            GalleryPage(gid: "1", index: 1, pageURL: SampleData.url("s/1")),
            GalleryPage(gid: "1", index: 1, imageURL: SampleData.url("i1"))
        ])
        let pages = try await database.pages(gid: "1")
        #expect(pages == [GalleryPage(gid: "1", index: 1, pageURL: SampleData.url("s/1"), imageURL: SampleData.url("i1"))])
    }

    @Test func emptyBatchIsANoOp() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.upsertPages([])
        #expect(try await database.rowCount("galleryPage") == 0)
    }

    @Test func fetchesRange() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.upsertPages((1...20).map { GalleryPage(gid: "1", index: $0, imageURL: SampleData.url("\($0)")) })
        let pages = try await database.pages(gid: "1", in: 5...8)
        #expect(pages.map(\.index) == [5, 6, 7, 8])
        #expect(try await database.pages(gid: "1", in: 19...30).map(\.index) == [19, 20])
    }

    @Test func deletesOneGalleryPages() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.upsertPages([
            GalleryPage(gid: "1", index: 1, imageURL: SampleData.url("a")),
            GalleryPage(gid: "2", index: 1, imageURL: SampleData.url("b"))
        ])
        try await database.deletePages(gid: "1")
        #expect(try await database.pages(gid: "1").isEmpty)
        #expect(try await database.pages(gid: "2").count == 1)
    }

    @Test func deletesExpiredPages() async throws {
        let database = try await TestDatabase.inMemory()
        let now = SampleData.date(1_000_000)
        let week: TimeInterval = 7 * 24 * 60 * 60
        try await database.recordOpened(SampleData.gallery("recent"), at: now.addingTimeInterval(-week + 60))
        try await database.recordOpened(SampleData.gallery("old"), at: now.addingTimeInterval(-week - 60))
        try await database.upsertPages(["recent", "old", "orphan"].map {
            GalleryPage(gid: $0, index: 1, imageURL: SampleData.url($0))
        })

        try await database.deleteExpiredPages(notOpenedWithin: week, now: now)

        #expect(try await database.pages(gid: "recent").count == 1)
        #expect(try await database.pages(gid: "old").isEmpty)
        #expect(try await database.pages(gid: "orphan").isEmpty)
        // Only the cached URLs expire; the history entry stays.
        #expect(try await database.gallery(gid: "old") != nil)
    }
}
