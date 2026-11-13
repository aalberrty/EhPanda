@testable import EhFeatures
import EhModels
import Foundation
import Testing

@Suite struct GalleryCollectionModelTests {
    @Test func readOpensTheReaderAndRecordsTheGalleryInHistory() async throws {
        let env = try ListTestEnvironment()
        let model = env.make { GalleryCollectionModel() }
        #expect(model.readingGallery == nil)

        let gallery = Gallery.stub("42", title: "Read from a list")
        model.read(gallery)
        #expect(model.readingGallery == gallery)

        await model.recording?.value
        let stored = try await env.database.gallery(gid: "42")
        #expect(stored?.title == "Read from a list")
        #expect(stored?.lastOpenDate != nil)

        // Closing the reader clears the destination.
        model.readingGallery = nil
        #expect(model.readingGallery == nil)
    }

    @Test func readingAgainMovesTheGalleryToTheTopOfHistory() async throws {
        let env = try ListTestEnvironment()
        try await env.database.recordOpened(.stub("1"), at: Date(timeIntervalSince1970: 10))
        try await env.database.recordOpened(.stub("2"), at: Date(timeIntervalSince1970: 20))
        let model = env.make { GalleryCollectionModel() }

        model.read(.stub("1"))
        await model.recording?.value

        let history = env.make { HistoryModel() }
        await history.refresh()
        #expect(history.galleries.map(\.gid) == ["1", "2"])
    }

    @Test func displayModeToggles() {
        #expect(ListDisplayMode.detail.toggled == .thumbnail)
        #expect(ListDisplayMode.thumbnail.toggled == .detail)
    }
}
