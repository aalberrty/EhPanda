@testable import EhFeatures
import EhModels
import Foundation
import Testing

@Suite struct HistoryModelTests {
    @Test func observesOpenedGalleriesNewestFirst() async throws {
        let env = try ListTestEnvironment()
        try await env.database.recordOpened(.stub("1", title: "Old"), at: Date(timeIntervalSince1970: 10))
        try await env.database.recordOpened(.stub("2", title: "New"), at: Date(timeIntervalSince1970: 20))
        let model = env.make { HistoryModel() }
        #expect(model.loadingState == .loading)
        #expect(!model.canClear)

        let task = Task { await model.observe() }
        await waitUntil { model.galleries.count == 2 }
        #expect(model.galleries.map(\.gid) == ["2", "1"])
        #expect(model.loadingState == .idle)
        #expect(model.canClear)

        model.titleFilter = "old"
        #expect(model.visibleGalleries.map(\.gid) == ["1"])

        try await env.database.recordOpened(.stub("3"), at: Date(timeIntervalSince1970: 30))
        await waitUntil { model.galleries.count == 3 }
        #expect(model.galleries.first?.gid == "3")

        model.isClearConfirmationPresented = true
        await model.clear()
        await waitUntil { model.galleries.isEmpty }
        #expect(model.galleries.isEmpty)
        #expect(!model.isClearConfirmationPresented)
        #expect(!model.canClear)
        task.cancel()
        await task.value
    }

    @Test func refreshReadsOnce() async throws {
        let env = try ListTestEnvironment()
        try await env.database.recordOpened(.stub("1"))
        let model = env.make { HistoryModel() }

        await model.refresh()

        #expect(model.galleries.map(\.gid) == ["1"])
        #expect(model.loadingState == .idle)
    }
}
