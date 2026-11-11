@testable import EhDatabase
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct GalleryStateTests {
    @Test func detailRoundTripsAndUpserts() async throws {
        let database = try await TestDatabase.inMemory()
        #expect(try await database.detail(gid: "1") == nil)

        var detail = SampleData.detail("1")
        try await database.saveDetail(detail)
        #expect(try await database.detail(gid: "1") == detail)

        detail.isFavorited = false
        detail.visibility = .yes
        detail.archiveURL = nil
        detail.ratingCount = 121
        try await database.saveDetail(detail)
        #expect(try await database.detail(gid: "1") == detail)
        #expect(try await database.rowCount("galleryDetail") == 1)
    }

    @Test func stateIsNilUntilWritten() async throws {
        let database = try await TestDatabase.inMemory()
        #expect(try await database.state(gid: "1") == nil)
    }

    @Test func eachStateFieldUpdatesIndependently() async throws {
        let database = try await TestDatabase.inMemory()

        try await database.updateReadingProgress(gid: "1", progress: 7)
        var state = try #require(try await database.state(gid: "1"))
        #expect(state == GalleryState(gid: "1", readingProgress: 7))

        try await database.updateTags(gid: "1", tags: SampleData.tags())
        try await database.updateComments(gid: "1", comments: SampleData.comments())
        try await database.updatePreviewConfig(gid: "1", config: .large(rows: 6))
        state = try #require(try await database.state(gid: "1"))
        #expect(state.readingProgress == 7)
        #expect(state.tags == SampleData.tags())
        #expect(state.comments == SampleData.comments())
        #expect(state.previewConfig == .large(rows: 6))

        try await database.updateReadingProgress(gid: "1", progress: 9)
        try await database.updateTags(gid: "1", tags: SampleData.tags("maid"))
        state = try #require(try await database.state(gid: "1"))
        #expect(state.readingProgress == 9)
        #expect(state.tags == SampleData.tags("maid"))
        #expect(state.comments == SampleData.comments())
        #expect(state.previewConfig == .large(rows: 6))
        #expect(state.imageURLs.isEmpty && state.previewURLs.isEmpty)

        // Another gallery's state is separate.
        #expect(try await database.state(gid: "2") == nil)
        #expect(try await database.rowCount("galleryState") == 1)
    }

    @Test func newStateWithOnlyTagsHasZeroProgress() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.updateTags(gid: "1", tags: SampleData.tags())
        let state = try #require(try await database.state(gid: "1"))
        #expect(state.readingProgress == 0)
        #expect(state.previewConfig == nil)
        #expect(state.comments.isEmpty)
    }
}
