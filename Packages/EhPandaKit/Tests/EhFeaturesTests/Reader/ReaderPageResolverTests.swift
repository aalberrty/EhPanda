@testable import EhFeatures
import EhModels
import EhNetworking
import Foundation
import Testing

/// A resolver on a `ReaderTestSite`, with the events it sent.
private final class ResolverHarness {
    let site: ReaderTestSite
    let resolver: ReaderPageResolver
    private(set) var events: [ReaderPageResolver.Event] = []

    init(site: ReaderTestSite = ReaderTestSite(), limit: Int = 4, previewConfig: PreviewConfig? = .normal(rows: 4)) {
        self.site = site
        resolver = ReaderPageResolver(
            gallery: site.gallery, client: site.client, previewConfig: previewConfig,
            maximumConcurrentRequests: limit
        )
        resolver.onEvent = { [weak self] in self?.events.append($0) }
    }

    /// Starts with the viewer links of these pages already known, as after a reopen.
    func restoreLinks(_ pages: ClosedRange<Int>) {
        resolver.restore(previewConfig: .normal(rows: 4), links: site.links(pages), images: [:])
    }

    var resolved: [Int] {
        events.compactMap { if case .resolved(let image) = $0 { image.index } else { nil } }
    }

    var failed: [Int] {
        events.compactMap { if case .failed(let page, _) = $0 { page } else { nil } }
    }

    func isResolved(_ pages: Int...) -> Bool {
        pages.allSatisfy { resolver.state(of: $0) == .image(site.image($0)) }
    }
}

@Suite struct ReaderPageResolverTests {
    // MARK: Ordering

    @Test func resolvesTheFocusPageFirstThenOutwards() async {
        let harness = ResolverHarness(limit: 1)
        harness.resolver.setFocus(8)
        harness.resolver.need(Array(3...13))

        await readerEventually { harness.resolved.count == 11 }

        // One preview page serves all eleven; then nearest first, the page ahead before the
        // page behind.
        #expect(harness.site.started == [
            "links:0", "page:8", "page:9", "page:7", "page:10", "page:6", "page:11", "page:5",
            "page:12", "page:4", "page:13", "page:3"
        ])
        #expect(harness.resolved == [8, 9, 7, 10, 6, 11, 5, 12, 4, 13, 3])
        #expect(harness.resolver.image(of: 8) == harness.site.pageImage(8))
        #expect(harness.resolver.link(of: 3) == harness.site.link(3))
    }

    @Test func eachPageIsReportedAsItResolves() async {
        let harness = ResolverHarness(limit: 2)
        harness.restoreLinks(1...40)
        harness.site.hold("page:2", "page:3")
        harness.resolver.need([1, 2, 3])

        await readerEventually { harness.isResolved(1) }

        // Page 1 is there while the others are still on their way.
        #expect(harness.resolved == [1])
        #expect(harness.resolver.state(of: 2) == .pending)
        harness.site.release("page:2", "page:3")
        await readerEventually { harness.isResolved(2, 3) }
    }

    @Test func aChangeOfFocusReordersWhatHasNotStarted() async {
        let harness = ResolverHarness(limit: 1)
        harness.restoreLinks(1...40)
        harness.site.hold("page:1")
        harness.resolver.need(Array(1...30))
        await readerEventually { harness.site.started == ["page:1"] }

        harness.resolver.setFocus(20)
        harness.site.release("page:1")
        await readerEventually { harness.site.started.count >= 4 }

        #expect(Array(harness.site.started.prefix(4)) == ["page:1", "page:20", "page:21", "page:19"])
    }

    // MARK: Bounds

    @Test func neverRunsMoreRequestsThanTheLimit() async {
        let harness = ResolverHarness(limit: 3)
        harness.restoreLinks(1...40)
        harness.site.holdEverything()
        harness.resolver.need(Array(1...12))

        await readerEventually { harness.site.inFlight.count == 3 }
        await readerSettle()
        #expect(harness.site.inFlight == ["page:1", "page:2", "page:3"])

        harness.site.releaseEverything()
        await readerEventually { harness.resolved.count == 12 }
        #expect(harness.site.maximumInFlight == 3)
    }

    @Test func oneSlotIsKeptForTheFocusPageWhileItWaitsForItsLink() async {
        let harness = ResolverHarness(limit: 3)
        // Page 1 has no link yet; its neighbours do.
        harness.resolver.restore(previewConfig: .normal(rows: 4), links: harness.site.links(2...40), images: [:])
        harness.site.holdEverything()
        harness.resolver.need(Array(1...10))

        await readerEventually { harness.site.inFlight.count == 3 }
        await readerSettle()
        // The preview page for page 1, and two other pages rather than three.
        #expect(harness.site.inFlight == ["links:0", "page:2", "page:3"])

        // The moment the link arrives, page 1 starts although nothing else has finished.
        harness.site.release("links:0")
        await readerEventually { harness.site.inFlight.contains("page:1") }
        #expect(harness.site.inFlight == ["page:1", "page:2", "page:3"])
        harness.site.releaseEverything()
    }

    @Test func landingOnAnUnresolvedPageTakesASlotFromTheFarthestRequest() async {
        let harness = ResolverHarness(limit: 2)
        harness.restoreLinks(1...40)
        harness.site.hold("page:2", "page:3")
        harness.resolver.need(Array(1...12))
        await readerEventually { harness.isResolved(1) && harness.site.inFlight == ["page:2", "page:3"] }

        harness.resolver.setFocus(12)

        await readerEventually { harness.isResolved(12) && !harness.site.cancelled.isEmpty }
        // Page 2 gave way; page 3 was left alone.
        #expect(harness.site.cancelled == ["page:2"])
        #expect(harness.site.inFlight.contains("page:3"))
        harness.site.release("page:2", "page:3")
        await readerEventually { harness.isResolved(2, 3) }
        #expect(harness.site.count(of: "page:2") == 2)
    }

    // MARK: Coalescing

    @Test func aPreviewPageAndAPageAreRequestedOnce() async {
        let harness = ResolverHarness()
        harness.site.hold("links:0")
        harness.resolver.need(Array(1...6))
        await readerEventually { harness.site.started == ["links:0"] }

        // Asked for again while the preview page and, later, the pages are in flight.
        harness.resolver.need(Array(1...6))
        harness.resolver.need([3, 4])
        await readerSettle()
        #expect(harness.site.started == ["links:0"])
        harness.site.hold("page:5")
        harness.site.release("links:0")
        await readerEventually { harness.site.inFlight.contains("page:5") }
        harness.resolver.need([5])
        harness.resolver.refetch(5)
        harness.site.release("page:5")

        await readerEventually { harness.resolved.count == 6 }
        #expect(harness.site.count(of: "links:0") == 1)
        for page in 1...6 {
            #expect(harness.site.count(of: "page:\(page)") == 1)
        }
        #expect(harness.resolver.link(of: 40) == harness.site.link(40))
    }

    // MARK: Cancellation

    @Test func releasedPagesAreCancelledAndFreeTheirSlots() async {
        let harness = ResolverHarness(limit: 2)
        harness.restoreLinks(1...40)
        harness.site.hold("page:1", "page:2")
        harness.resolver.need(Array(1...4))
        await readerEventually { harness.site.inFlight == ["page:1", "page:2"] }

        harness.resolver.release([2, 3])

        await readerEventually { harness.isResolved(4) && !harness.site.cancelled.isEmpty }
        #expect(harness.site.cancelled == ["page:2"])
        #expect(!harness.site.started.contains("page:3"))
        #expect(harness.resolver.state(of: 2) == .pending)
        #expect(harness.failed.isEmpty)
        harness.site.release("page:1", "page:2")

        // Needed again later, a cancelled page starts over.
        harness.resolver.need([2])
        await readerEventually { harness.isResolved(1, 2) }
    }

    @Test func aPreviewPageNobodyWaitsForIsCancelled() async {
        let harness = ResolverHarness()
        harness.site.hold("links:1")
        harness.resolver.setFocus(50)
        harness.resolver.need([49, 50, 51])
        await readerEventually { harness.site.inFlight == ["links:1"] }

        harness.resolver.release([49, 50])
        await readerSettle()
        #expect(harness.site.cancelled.isEmpty)

        harness.resolver.release([51])
        await readerEventually { harness.site.cancelled == ["links:1"] }
        #expect(harness.events.isEmpty)
    }

    @Test func stopCancelsEverything() async {
        let harness = ResolverHarness(limit: 3)
        harness.restoreLinks(1...40)
        harness.site.holdEverything()
        harness.resolver.need(Array(1...8))
        await readerEventually { harness.site.inFlight.count == 3 }

        harness.resolver.stop()

        await readerEventually { harness.site.cancelled.count == 3 }
        harness.site.releaseEverything()
        await readerSettle()
        #expect(harness.events.isEmpty)
        #expect(harness.site.started.count == 3)
    }

    // MARK: Failures

    @Test func aFailureStaysWithItsPage() async {
        let harness = ResolverHarness()
        harness.site.fail("page:3")
        harness.resolver.need(Array(1...5))

        await readerEventually { harness.resolved.count == 4 && harness.failed == [3] }

        #expect(harness.isResolved(1, 2, 4, 5))
        #expect(harness.resolver.state(of: 3) == .failed)
        #expect(harness.resolver.failure(of: 3) == .networkingFailed)
        #expect(harness.events.contains(.failed(page: 3, error: .networkingFailed)))
    }

    @Test func aFailedPreviewPageFailsOnlyThePagesWaitingForIt() async {
        let harness = ResolverHarness()
        harness.site.fail("links:0")
        harness.resolver.need([1, 2, 3])
        await readerEventually { harness.failed.count == 3 }
        #expect(Set(harness.failed) == [1, 2, 3])
        // Page 4 is on the same preview page but was not asked for.
        #expect(harness.resolver.state(of: 4) == .pending)
        #expect(harness.resolver.failure(of: 4) == nil)

        // Retrying one page fetches the preview page again, and the others recover with it.
        harness.resolver.retry(2)

        await readerEventually { harness.isResolved(1, 2, 3) }
        #expect(harness.site.count(of: "links:0") == 2)
        #expect(harness.events.contains(.updated(page: 1)))
        #expect(harness.events.contains(.updated(page: 2)))
    }

    @Test func aPageThePreviewPageDoesNotListIsNotFound() async {
        // The gallery claims more pages than the site lists.
        let site = ReaderTestSite(pageCount: 30)
        var gallery = site.gallery
        gallery.pageCount = 35
        let resolver = ReaderPageResolver(gallery: gallery, client: site.client, previewConfig: .normal(rows: 4))

        resolver.need([33])

        await readerEventually { resolver.state(of: 33) == .failed }
        #expect(resolver.failure(of: 33) == .notFound)
    }

    // MARK: Retry and refetch

    @Test func retryResolvesAFailedPageFromTheStart() async {
        let harness = ResolverHarness()
        harness.site.fail("page:2")
        harness.resolver.need([1, 2])
        await readerEventually { harness.failed == [2] }

        harness.resolver.retry(2)
        #expect(harness.resolver.state(of: 2) == .pending)

        await readerEventually { harness.isResolved(2) }
        #expect(harness.site.count(of: "page:2") == 2)
        // A plain second attempt: no other image server was asked for.
        #expect(!harness.site.started.contains("reload:2"))
    }

    @Test func refetchReloadsThroughAnotherServer() async {
        let harness = ResolverHarness()
        harness.resolver.need([3])
        await readerEventually { harness.isResolved(3) }

        harness.resolver.refetch(3)
        #expect(harness.resolver.state(of: 3) == .pending)

        let reloaded = PageImage(
            index: 3, imageURL: harness.site.reloadedImage(3), originalImageURL: harness.site.original(3)
        )
        await readerEventually { harness.resolver.image(of: 3) == reloaded }
        // The viewer page again for its identifier, then with `nl`: the first image is the
        // one that was stored, so the reloaded one wins.
        #expect(harness.site.started == ["links:0", "page:3", "page:3", "reload:3"])
        #expect(harness.events.suffix(2) == [.updated(page: 3), .resolved(reloaded)])
        #expect(harness.resolver.state(of: 3) == .image(harness.site.reloadedImage(3)))
    }

    @Test func aFailedRefetchKeepsTheImageAndRetriesAsARefetch() async {
        let harness = ResolverHarness()
        harness.resolver.need([3])
        await readerEventually { harness.isResolved(3) }
        harness.site.fail("reload:3")

        harness.resolver.refetch(3)
        await readerEventually { harness.failed == [3] }
        #expect(harness.resolver.image(of: 3) == harness.site.pageImage(3))

        harness.resolver.retry(3)
        await readerEventually { harness.resolver.state(of: 3) == .image(harness.site.reloadedImage(3)) }
        #expect(harness.site.count(of: "reload:3") == 2)
    }

    @Test func refetchOfAnUnresolvedPageSimplyResolvesIt() async {
        let harness = ResolverHarness()
        harness.site.hold("links:0")
        harness.resolver.need([7])
        await readerEventually { harness.site.inFlight == ["links:0"] }

        harness.resolver.refetch(7)
        harness.site.release("links:0")

        await readerEventually { harness.isResolved(7) }
        #expect(harness.site.started == ["links:0", "page:7"])
    }

    @Test func resolveAgainForgetsTheImageWithoutAskingForAnotherServer() async {
        let harness = ResolverHarness()
        let stale = PageImage(index: 4, imageURL: URL(string: "https://old.example/4.jpg")!, originalImageURL: nil)
        harness.resolver.restore(
            previewConfig: .normal(rows: 4), links: harness.site.links(1...40), images: [4: stale]
        )
        #expect(harness.resolver.state(of: 4) == .image(stale.imageURL))
        harness.resolver.need([4])

        harness.resolver.resolveAgain(4)
        #expect(harness.resolver.state(of: 4) == .pending)
        #expect(harness.resolver.image(of: 4) == nil)

        await readerEventually { harness.isResolved(4) }
        #expect(harness.site.started == ["page:4"])
    }

    /// Only the reader takes pages out of the resolver's demand, and it does so once, when a
    /// page leaves its reach. A command that put such a page back would leave it a candidate
    /// until the reader closes.
    @Test func aPageThatLeftTheReadersReachIsNotRequestedUntilItIsNeededAgain() async {
        let harness = ResolverHarness()
        let stale = PageImage(index: 4, imageURL: URL(string: "https://old.example/4.jpg")!, originalImageURL: nil)
        harness.resolver.restore(
            previewConfig: .normal(rows: 4), links: harness.site.links(1...40), images: [4: stale]
        )
        harness.site.fail("page:9")
        harness.resolver.need([4, 9])
        await readerEventually { harness.failed == [9] }
        harness.resolver.release([4, 9])

        // The failure of a prefetched image is reported after its page scrolled out of reach.
        harness.resolver.resolveAgain(4)
        harness.resolver.refetch(4)
        harness.resolver.retry(9)
        #expect(harness.resolver.state(of: 4) == .pending)
        #expect(harness.resolver.state(of: 9) == .pending)
        await readerSettle()
        #expect(harness.site.started == ["page:9"])

        harness.resolver.need([4, 9])
        await readerEventually { harness.isResolved(4, 9) }
        #expect(harness.site.started.sorted() == ["page:4", "page:9", "page:9"])
    }

    @Test func retryAllFailedResetsEveryFailedPage() async {
        let harness = ResolverHarness()
        harness.site.fail("page:2")
        harness.site.fail("page:30")
        harness.resolver.need([1, 2, 30])
        await readerEventually { harness.resolved == [1] && harness.failed.count == 2 }
        // Page 30 left the reader's reach while failed; page 1's refetch fails.
        harness.resolver.release([30])
        harness.site.fail("reload:1")
        harness.resolver.refetch(1)
        await readerEventually { harness.failed.count == 3 }

        harness.resolver.retryAllFailed()

        // The page with an image shows it again, as in legacy; nothing is refetched for it.
        #expect(harness.resolver.state(of: 1) == .image(harness.site.image(1)))
        #expect(harness.resolver.state(of: 30) == .pending)
        await readerEventually { harness.isResolved(2) }
        await readerSettle()
        // Page 30 waits until it is needed again.
        #expect(harness.site.count(of: "page:30") == 1)
        #expect(harness.site.count(of: "reload:1") == 1)
        harness.resolver.need([30])
        await readerEventually { harness.isResolved(30) }
    }

    @Test func resetForgetsEverythingAndResolvesNeededPagesAgain() async {
        let harness = ResolverHarness()
        harness.resolver.need([1, 2])
        await readerEventually { harness.isResolved(1, 2) }

        harness.resolver.reset()

        #expect(harness.resolver.state(of: 1) == .pending)
        #expect(harness.resolver.image(of: 1) == nil)
        #expect(harness.resolver.link(of: 1) == nil)
        await readerEventually { harness.isResolved(1, 2) }
        #expect(harness.site.count(of: "links:0") == 2)
        #expect(harness.site.count(of: "page:1") == 2)
    }

    @Test func resetDropsRequestsThatWereInFlight() async {
        let harness = ResolverHarness()
        harness.restoreLinks(1...40)
        harness.site.hold("page:1")
        harness.resolver.need([1])
        await readerEventually { harness.site.inFlight == ["page:1"] }

        harness.resolver.reset()
        harness.site.release("page:1")

        await readerEventually { harness.isResolved(1) && !harness.site.cancelled.isEmpty }
        #expect(harness.site.cancelled == ["page:1"])
        // The links were forgotten too, so the page went through its preview page again.
        #expect(harness.site.started == ["page:1", "links:0", "page:1"])
        #expect(harness.resolved == [1])
    }
}
