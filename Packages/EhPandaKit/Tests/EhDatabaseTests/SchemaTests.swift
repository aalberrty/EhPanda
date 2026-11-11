@testable import EhDatabase
import EhTestSupport
import Foundation
import Testing

@Suite struct SchemaTests {
    @Test func migrationCreatesSchema() async throws {
        let database = try await TestDatabase.inMemory()
        let columns = try await database.schemaColumns()
        #expect(Set(columns.keys) == [
            "gallery", "galleryDetail", "galleryState", "galleryPage",
            "tagTranslation", "searchHistory", "quickSearchWord"
        ])
        #expect(columns["gallery"] == [
            "gid", "token", "title", "rating", "category", "uploader", "pageCount", "postedDate",
            "coverURL", "galleryURL", "tags", "lastOpenDate"
        ])
        #expect(columns["galleryState"] == ["gid", "readingProgress", "previewConfig", "tags", "comments"])
        #expect(columns["galleryPage"] == [
            "gid", "pageIndex", "pageURL", "imageURL", "originalImageURL", "previewURL",
            "imageWidth", "imageHeight"
        ])
        #expect(columns["tagTranslation"] == [
            "key", "namespace", "tag", "value", "displayValue", "valueImageURL", "description", "linksString"
        ])
        #expect(columns["searchHistory"] == ["keyword", "lastUsedAt"])
        #expect(columns["quickSearchWord"] == ["id", "name", "content", "position"])
        #expect(columns["galleryDetail"]?.count == 20)

        let indexes = try await database.indexNames()
        #expect(indexes.contains("gallery_on_lastOpenDate"))
    }

    @Test func onDiskDatabaseReopensWithData() async throws {
        let directory = try TestDatabase.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Nested/EhPanda.sqlite")

        let first = try await AppDatabase.open(at: url)
        try await first.recordOpened(SampleData.gallery("1"), at: SampleData.date(1))
        let second = try await AppDatabase.open(at: url)
        #expect(try await second.gallery(gid: "1")?.lastOpenDate == SampleData.date(1))
        #expect(FileManager.default.fileExists(atPath: url.path + "-wal"))
    }
}
