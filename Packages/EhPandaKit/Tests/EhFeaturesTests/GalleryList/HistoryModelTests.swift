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

        var task = Task { await model.observe() }
        await waitUntil { model.galleries.count == 2 }
        #expect(model.galleries.map(\.gid) == ["2", "1"])
        #expect(model.loadingState == .idle)
        #expect(model.canClear)

        try await env.database.recordOpened(.stub("3"), at: Date(timeIntervalSince1970: 30))
        await waitUntil { model.galleries.count == 3 }
        #expect(model.galleries.first?.gid == "3")

        // The view restarts the observation when the query changes.
        let query = model.query
        model.titleFilter = "old"
        #expect(model.query != query)
        task.cancel()
        task = Task { await model.observe() }
        await waitUntil { model.galleries.count == 1 }
        #expect(model.galleries.map(\.gid) == ["1"])
        #expect(model.canClear)

        model.isClearConfirmationPresented = true
        await model.clear()
        await waitUntil { model.galleries.isEmpty }
        #expect(model.galleries.isEmpty)
        #expect(model.isHistoryEmpty)
        #expect(!model.isClearConfirmationPresented)
        #expect(!model.canClear)
        task.cancel()
        await task.value
    }

    @Test func readsAPageAtATimeAndLoadsMore() async throws {
        let env = try ListTestEnvironment()
        let count = HistoryModel.pageSize + 5
        for index in 0..<count {
            try await env.database.recordOpened(.stub("\(index)"), at: Date(timeIntervalSince1970: Double(index)))
        }
        let model = env.make { HistoryModel() }

        await model.refresh()
        #expect(model.galleries.count == HistoryModel.pageSize)
        #expect(model.galleries.first?.gid == "\(count - 1)")
        #expect(model.hasMore)

        let query = model.query
        model.loadMore()
        #expect(model.query != query)
        // Asking again before the page arrived asks for nothing more.
        let pending = model.query
        model.loadMore()
        #expect(model.query == pending)

        await model.refresh()
        #expect(model.galleries.count == count)
        #expect(!model.hasMore)
        model.loadMore()
        #expect(model.query == pending)
    }

    /// The filter is a query over the whole history, not a filter of the loaded page.
    @Test func titleFilterFindsGalleriesBeyondTheLoadedPage() async throws {
        let env = try ListTestEnvironment()
        try await env.database.recordOpened(.stub("old", title: "Needle"), at: Date(timeIntervalSince1970: 0))
        for index in 1...HistoryModel.pageSize {
            try await env.database.recordOpened(.stub("\(index)"), at: Date(timeIntervalSince1970: Double(index)))
        }
        let model = env.make { HistoryModel() }
        await model.refresh()
        #expect(!model.galleries.contains { $0.gid == "old" })
        model.loadMore()

        model.titleFilter = "needle"
        #expect(model.query.limit == HistoryModel.pageSize)
        await model.refresh()

        #expect(model.galleries.map(\.gid) == ["old"])
        #expect(!model.isHistoryEmpty)
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
