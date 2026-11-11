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
        try await database.saveDetail(detail, state: GalleryState(gid: "1"))
        #expect(try await database.detail(gid: "1") == detail)

        detail.isFavorited = false
        detail.visibility = .yes
        detail.archiveURL = nil
        detail.ratingCount = 121
        try await database.saveDetail(detail, state: GalleryState(gid: "1"))
        #expect(try await database.detail(gid: "1") == detail)
        #expect(try await database.rowCount("galleryDetail") == 1)
    }

    @Test func stateIsNilUntilWritten() async throws {
        let database = try await TestDatabase.inMemory()
        #expect(try await database.state(gid: "1") == nil)
    }

    /// One fetched detail page: the detail, its tags and comments, the preview layout and
    /// what its first preview page lists.
    private func fetchedState(tag: String = "glasses", previewConfig: PreviewConfig? = .large(rows: 6)) -> GalleryState {
        GalleryState(
            gid: "1", tags: SampleData.tags(tag),
            // Not stored by a detail save: the reader owns the progress.
            readingProgress: 99,
            previewURLs: [1: SampleData.url("p1.jpg")!, 2: SampleData.url("p2.jpg")!],
            previewConfig: previewConfig, comments: SampleData.comments(),
            thumbnailURLs: [1: SampleData.url("s/a/1-1")!, 2: SampleData.url("s/b/1-2")!]
        )
    }

    @Test func aFetchedDetailIsStoredInOneTransaction() async throws {
        let database = try await TestDatabase.inMemory()

        let commits = try await database.commitCount {
            try await database.saveDetail(SampleData.detail("1"), state: fetchedState())
        }

        #expect(commits == 1)
        #expect(try await database.detail(gid: "1") == SampleData.detail("1"))
        let state = try #require(try await database.state(gid: "1"))
        #expect(state.tags == SampleData.tags())
        #expect(state.comments == SampleData.comments())
        #expect(state.previewConfig == .large(rows: 6))
        // The viewer link is stored with the thumbnail, so the reader need not fetch it.
        #expect(try await database.pages(gid: "1") == [
            GalleryPage(gid: "1", index: 1, pageURL: SampleData.url("s/a/1-1"), previewURL: SampleData.url("p1.jpg")),
            GalleryPage(gid: "1", index: 2, pageURL: SampleData.url("s/b/1-2"), previewURL: SampleData.url("p2.jpg"))
        ])
    }

    @Test func savingADetailLeavesTheReadingProgressAndWhatThePageDidNotSay() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.updateReadingProgress(gid: "1", progress: 7)
        #expect(try await database.state(gid: "1") == GalleryState(gid: "1", readingProgress: 7))
        try await database.upsertPages([
            GalleryPage(gid: "1", index: 1, imageURL: SampleData.url("1.jpg"), imageWidth: 800, imageHeight: 1200)
        ])

        try await database.saveDetail(SampleData.detail("1"), state: fetchedState())
        var state = try #require(try await database.state(gid: "1"))
        #expect(state.readingProgress == 7)
        #expect(state.tags == SampleData.tags())
        #expect(state.previewConfig == .large(rows: 6))
        // What the reader stored for the page is merged with, not replaced.
        #expect(try await database.pages(gid: "1").first == GalleryPage(
            gid: "1", index: 1, pageURL: SampleData.url("s/a/1-1"), imageURL: SampleData.url("1.jpg"),
            previewURL: SampleData.url("p1.jpg"), imageWidth: 800, imageHeight: 1200
        ))

        // A page that shows no layout keeps the stored one; tags and comments are the page's.
        try await database.updateReadingProgress(gid: "1", progress: 9)
        var later = fetchedState(tag: "maid", previewConfig: nil)
        later.comments = []
        later.previewURLs = [:]
        later.thumbnailURLs = [:]
        try await database.saveDetail(SampleData.detail("1"), state: later)
        state = try #require(try await database.state(gid: "1"))
        #expect(state.readingProgress == 9)
        #expect(state.tags == SampleData.tags("maid"))
        #expect(state.comments.isEmpty)
        #expect(state.previewConfig == .large(rows: 6))
        #expect(state.imageURLs.isEmpty && state.previewURLs.isEmpty)
        #expect(try await database.pages(gid: "1").count == 2)

        // Another gallery's state is separate.
        #expect(try await database.state(gid: "2") == nil)
        #expect(try await database.rowCount("galleryState") == 1)
    }

    /// The reader opens on the stored progress and pages by the stored layout. It reads
    /// those two, not the tags and comments stored in the same row.
    @Test func readingStateIsTheProgressAndThePreviewLayout() async throws {
        let database = try await TestDatabase.inMemory()
        #expect(try await database.readingState(gid: "1") == nil)

        try await database.updateReadingProgress(gid: "1", progress: 7)
        #expect(try await database.readingState(gid: "1") == ReadingState(readingProgress: 7, previewConfig: nil))

        try await database.saveDetail(SampleData.detail("1"), state: fetchedState())
        #expect(try await database.readingState(gid: "1")
            == ReadingState(readingProgress: 7, previewConfig: .large(rows: 6)))
        #expect(try await database.readingState(gid: "2") == nil)
    }

    @Test func aDetailSavedBeforeAnythingWasReadHasZeroProgress() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.saveDetail(SampleData.detail("1"), state: GalleryState(gid: "1", tags: SampleData.tags()))
        let state = try #require(try await database.state(gid: "1"))
        #expect(state.readingProgress == 0)
        #expect(state.previewConfig == nil)
        #expect(state.comments.isEmpty)
        #expect(try await database.pages(gid: "1").isEmpty)
    }
}
