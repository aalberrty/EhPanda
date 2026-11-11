import Dependencies
import EhCore
import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Synchronization
import Testing

@Suite struct HomeModelTests {
    private let transport = StubTransport()

    // MARK: Loading

    @Test func runLoadsEverySectionConcurrently() async throws {
        serveFixtures()
        let model = makeModel()
        model.loadIfNeeded()

        try await homeEventually { settled(model, after: 6) }

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
        model.loadIfNeeded()

        try await homeEventually { settled(model, after: 6) }

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
        model.loadIfNeeded()

        try await homeEventually { settled(model, after: 6) }

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
        model.loadIfNeeded()

        try await homeEventually { settled(model, after: 6) }

        #expect(model.popularState == .failed(.notFound))
        #expect(model.cards.isEmpty)
        #expect(!model.frontpage.isEmpty)
    }

    // MARK: Reload

    @Test func reloadAllRequestsEverySectionAgainAndKeepsDataOnFailure() async throws {
        serveFixtures()
        let model = makeModel()
        model.loadIfNeeded()
        try await homeEventually { settled(model, after: 6) }
        let cards = model.cards

        transport.on(.path("/popular"), reply: .error(URLError(.timedOut)))
        model.reloadAll()
        try await homeEventually { settled(model, after: 12) }

        #expect(transport.requests.count == 12)
        #expect(model.popularState == .failed(.networkingFailed))
        #expect(model.cards == cards)
    }

    @Test func sectionReloadsRequestOnlyTheirSection() async throws {
        serveFixtures()
        let model = makeModel()
        model.loadIfNeeded()
        try await homeEventually { settled(model, after: 6) }
        transport.reset()
        serveFixtures()

        model.reloadFrontpage()
        try await homeEventually { settled(model, after: 1) }
        #expect(transport.requests.first?.url?.path() == "/")

        model.reloadToplists()
        try await homeEventually { settled(model, after: 5) }
        #expect(transport.requests.dropFirst().allSatisfy { $0.url?.path() == "/toplist.php" })
    }

    @Test func reloadingASectionThatIsLoadingIsIgnored() async throws {
        serveFixtures()
        transport.on(.path("/"), reply: .suspendUntilCancelled)
        let model = makeModel()
        model.loadIfNeeded()
        try await homeEventually { model.frontpageState.isLoading && model.popularState == .idle }

        model.reloadFrontpage()
        model.reloadFrontpage()
        model.loadIfNeeded()
        try await Task.sleep(for: .milliseconds(50))

        #expect(transport.requests.filter { $0.url?.path() == "/" }.count == 1)
    }

    // MARK: Leaving the screen

    /// Pushing a gallery while sections load must not abandon them: the screen coming back
    /// finds them filled in, without requesting anything again.
    @Test func loadsInFlightOutliveTheScreenAndAreNotRequestedAgain() async throws {
        serveFixtures()
        let gate = Gate()
        transport.on(.path("/toplist.php"), reply: .handler { request in
            await gate.wait()
            return try Fixture.response("Parser/List/ToplistsCompactList.html", for: request)
        })
        let model = makeModel()
        model.loadIfNeeded()
        try await homeEventually { !model.cards.isEmpty && !model.frontpage.isEmpty && model.isLoadingToplists }

        // The screen goes away and comes back while the toplists are still loading.
        model.loadIfNeeded()
        gate.open()
        try await homeEventually { settled(model, after: 6) }

        #expect(transport.requests.count == 6)
        for type in ToplistsType.allCases {
            #expect(!model.toplists(for: type).isEmpty)
        }
    }

    @Test func releasingTheModelCancelsEveryLoadWithoutFailing() async throws {
        let cancellations = Counter()
        transport.on(.any, reply: .handler { _ in
            do {
                while true { try await Task.sleep(for: .seconds(3600)) }
            } catch {
                cancellations.increment()
                throw URLError(.cancelled)
            }
        })
        var model: HomeModel? = makeModel()
        model?.loadIfNeeded()
        try await homeEventually { transport.requests.count == 6 }
        weak let released = model

        model = nil

        #expect(released == nil)
        try await homeEventually { cancellations.value == 6 }
    }

    @Test func appearingAgainLoadsOnlyWhatIsMissing() async throws {
        serveFixtures()
        transport.on(.path("/"), reply: .error(URLError(.notConnectedToInternet)))
        let model = makeModel()
        model.loadIfNeeded()
        try await homeEventually { settled(model, after: 6) }
        #expect(model.frontpageState == .failed(.networkingFailed))

        transport.reset()
        serveFixtures()
        model.loadIfNeeded()
        try await homeEventually { settled(model, after: 1) && !model.frontpage.isEmpty }

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

nonisolated private final class Counter: Sendable {
    private let count = Mutex(0)
    var value: Int { count.withLock { $0 } }
    func increment() { count.withLock { $0 += 1 } }
}

/// Polls `condition` on the main actor until it holds, yielding between checks.
private func homeEventually(
    timeout: Duration = .seconds(60), _ condition: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { throw TimedOut() }
        try await Task.sleep(for: .milliseconds(5))
    }
}
