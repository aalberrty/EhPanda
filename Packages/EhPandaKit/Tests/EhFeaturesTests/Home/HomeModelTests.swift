import Dependencies
import EhCore
import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

@Suite struct HomeModelTests {
    private let transport = StubTransport()

    // MARK: Loading

    @Test func runLoadsEverySectionConcurrently() async throws {
        serveFixtures()
        let model = makeModel()
        let task = Task { await model.run() }
        defer { task.cancel() }

        try await eventually { settled(model, after: 6) }

        #expect(model.popularState == .idle)
        #expect(!model.cards.isEmpty && model.cards.count <= HomeSections.maximumCards)
        #expect(model.frontpageState == .idle)
        #expect(!model.frontpage.isEmpty && model.frontpage.count <= 25)
        #expect(!model.coverColumns.isEmpty)
        for type in ToplistsType.allCases {
            #expect(model.toplistsStates[type] == .idle)
            #expect(!model.toplists(for: type).isEmpty)
        }
        #expect(transport.requests.count == 6)
    }

    @Test func toplistsAreRequestedOncePerPeriodWithoutAFilter() async throws {
        serveFixtures()
        let model = makeModel()
        let task = Task { await model.run() }
        defer { task.cancel() }

        try await eventually { settled(model, after: 6) }

        let toplists = transport.requests.filter { $0.url?.path() == "/toplist.php" }
        let periods = toplists.compactMap { request in
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "tl" }?.value
        }
        #expect(periods.sorted() == ["11", "12", "13", "15"])
        let queryNames = toplists.map { request in
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.map(\.name) ?? []
        }
        #expect(queryNames.allSatisfy { $0 == ["tl"] })
    }

    @Test func aFailingSectionDoesNotBlankTheOthers() async throws {
        serveFixtures()
        transport.on(.path("/"), reply: .error(URLError(.timedOut)))
        transport.on(.path("/toplist.php") && .query("tl", "12"), reply: .error(URLError(.notConnectedToInternet)))
        let model = makeModel()
        let task = Task { await model.run() }
        defer { task.cancel() }

        try await eventually { settled(model, after: 6) }

        #expect(!model.cards.isEmpty)
        #expect(model.frontpageState == .failed(.networkingFailed))
        #expect(model.frontpage.isEmpty)
        #expect(model.toplistsStates[.pastYear] == .failed(.networkingFailed))
        #expect(model.toplists(for: .pastYear).isEmpty)
        for type in [ToplistsType.yesterday, .pastMonth, .allTime] {
            #expect(!model.toplists(for: type).isEmpty)
        }
    }

    @Test func emptyPopularIsNotFound() async throws {
        serveFixtures()
        transport.on(.path("/popular"), reply: .html("<html><body></body></html>"))
        let model = makeModel()
        let task = Task { await model.run() }
        defer { task.cancel() }

        try await eventually { settled(model, after: 6) }

        #expect(model.popularState == .failed(.notFound))
        #expect(model.cards.isEmpty)
        #expect(!model.frontpage.isEmpty)
    }

    // MARK: Reload

    @Test func reloadAllRequestsEverySectionAgainAndKeepsDataOnFailure() async throws {
        serveFixtures()
        let model = makeModel()
        let task = Task { await model.run() }
        defer { task.cancel() }
        try await eventually { settled(model, after: 6) }
        let cards = model.cards

        transport.on(.path("/popular"), reply: .error(URLError(.timedOut)))
        model.reloadAll()
        try await eventually { settled(model, after: 12) }

        #expect(transport.requests.count == 12)
        #expect(model.popularState == .failed(.networkingFailed))
        #expect(model.cards == cards)
    }

    @Test func sectionReloadsRequestOnlyTheirSection() async throws {
        serveFixtures()
        let model = makeModel()
        let task = Task { await model.run() }
        defer { task.cancel() }
        try await eventually { settled(model, after: 6) }
        transport.reset()
        serveFixtures()

        model.reloadFrontpage()
        try await eventually { settled(model, after: 1) }
        #expect(transport.requests.first?.url?.path() == "/")

        model.reloadToplists()
        try await eventually { settled(model, after: 5) }
        #expect(transport.requests.dropFirst().allSatisfy { $0.url?.path() == "/toplist.php" })
    }

    @Test func reloadingASectionThatIsLoadingIsIgnored() async throws {
        serveFixtures()
        transport.on(.path("/"), reply: .suspendUntilCancelled)
        let model = makeModel()
        let task = Task { await model.run() }
        try await eventually { model.frontpageState.isLoading && model.popularState == .idle }

        model.reloadFrontpage()
        model.reloadFrontpage()
        try await Task.sleep(for: .milliseconds(50))

        #expect(transport.requests.filter { $0.url?.path() == "/" }.count == 1)
        task.cancel()
        await task.value
    }

    @Test func reloadWithoutARunningScreenDoesNothing() {
        serveFixtures()
        let model = makeModel()

        model.reloadAll()

        #expect(transport.requests.isEmpty)
        #expect(model.popularState == .idle)
    }

    // MARK: Cancellation

    @Test func cancellingTheRunCancelsEveryLoadWithoutFailing() async throws {
        transport.on(.any, reply: .suspendUntilCancelled)
        let model = makeModel()
        let task = Task { await model.run() }
        try await eventually { transport.requests.count == 6 }

        task.cancel()
        await task.value

        #expect(model.popularState == .idle)
        #expect(model.frontpageState == .idle)
        #expect(model.toplistsStates.values.allSatisfy { $0 == .idle })
        #expect(model.cards.isEmpty)
    }

    @Test func aNewRunLoadsOnlyWhatIsMissing() async throws {
        serveFixtures()
        transport.on(.path("/"), reply: .suspendUntilCancelled)
        let model = makeModel()
        let first = Task { await model.run() }
        try await eventually {
            !model.cards.isEmpty && model.frontpageState.isLoading
                && ToplistsType.allCases.allSatisfy { !model.toplists(for: $0).isEmpty }
        }
        first.cancel()
        await first.value
        #expect(model.frontpageState == .idle)

        transport.reset()
        serveFixtures()
        let second = Task { await model.run() }
        defer { second.cancel() }
        try await eventually { settled(model, after: 1) && !model.frontpage.isEmpty }

        #expect(transport.requests.map { $0.url?.path() } == ["/"])
    }

    // MARK: Helpers

    /// Every load sets its state to loading before its request goes out, so once `count`
    /// requests were sent and nothing is loading, all of them have finished.
    private func settled(_ model: HomeModel, after count: Int) -> Bool {
        transport.requests.count >= count && allSettled(model)
    }

    private func serveFixtures() {
        transport.on(.path("/"), reply: .fixture("Parser/List/FrontPageCompactList.html"))
        transport.on(.path("/popular"), reply: .fixture("Parser/List/PopularCompactList.html"))
        transport.on(.path("/toplist.php"), reply: .fixture("Parser/List/ToplistsCompactList.html"))
    }

    private func makeModel() -> HomeModel {
        let client = EhClient(
            transport: transport, cookies: CookieStore(storage: InMemoryCookieStorage()), host: { .ehentai }
        )
        return withDependencies {
            $0.ehClient = client
            $0.withRandomNumberGenerator = WithRandomNumberGenerator(SplitMix64(seed: 3))
        } operation: {
            HomeModel()
        }
    }
}

private func allSettled(_ model: HomeModel) -> Bool {
    !model.popularState.isLoading && !model.frontpageState.isLoading
        && model.toplistsStates.count == ToplistsType.allCases.count && !model.isLoadingToplists
}

private struct TimedOut: Error {}

/// Polls `condition` on the main actor until it holds, yielding between checks.
private func eventually(
    timeout: Duration = .seconds(10), _ condition: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { throw TimedOut() }
        try await Task.sleep(for: .milliseconds(5))
    }
}
