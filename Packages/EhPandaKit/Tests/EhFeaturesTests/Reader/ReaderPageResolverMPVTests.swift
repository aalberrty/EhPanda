@testable import EhFeatures
import EhModels
import EhNetworking
import Foundation
import Testing

@Suite struct ReaderPageResolverMPVTests {
    private func makeResolver(
        _ site: ReaderTestSite, limit: Int = 1, previewConfig: PreviewConfig? = .normal(rows: 4)
    ) -> ReaderPageResolver {
        ReaderPageResolver(
            gallery: site.gallery, client: site.client, previewConfig: previewConfig,
            maximumConcurrentRequests: limit
        )
    }

    @Test func switchesToTheMultiPageViewerWhenALinkPointsThere() async {
        let site = ReaderTestSite(usesMPV: true)
        let resolver = makeResolver(site)
        var events: [ReaderPageResolver.Event] = []
        resolver.onEvent = { events.append($0) }
        resolver.setFocus(50)
        resolver.need([49, 50, 51])

        await readerEventually { resolver.state(of: 3) != .pending }

        // The preview page, the keys, the pages that were asked for (nearest first), and then
        // pages 1 to 3, which legacy fetched as soon as it had the keys.
        #expect(site.started == [
            "links:1", "mpv", "dispatch:50", "dispatch:51", "dispatch:49",
            "dispatch:1", "dispatch:2", "dispatch:3"
        ])
        let page50 = PageImage(index: 50, imageURL: site.mpvImage(50), originalImageURL: site.mpvOriginal(50))
        #expect(resolver.image(of: 50) == page50)
        #expect(resolver.state(of: 1) == .image(site.mpvImage(1)))
        #expect(resolver.mpvKeys?.mpvKey == "mpvkey0")
        #expect(resolver.mpvKeys?.imageKeys[50] == "imgkey50")
        // Multi-page-viewer links are not viewer pages: none is kept or reported for storing.
        #expect(resolver.link(of: 50) == nil)
        #expect(!events.contains { if case .links = $0 { true } else { false } })
    }

    @Test func onceTheKeysAreKnownNoPreviewPageIsNeeded() async {
        let site = ReaderTestSite(usesMPV: true)
        let resolver = makeResolver(site)
        resolver.need([1])
        await readerEventually { resolver.state(of: 3) != .pending }

        resolver.setFocus(90)
        resolver.need([90])

        await readerEventually { resolver.state(of: 90) == .image(site.mpvImage(90)) }
        #expect(site.count(of: "mpv") == 1)
        #expect(site.started.filter { $0.hasPrefix("links") } == ["links:0"])
    }

    @Test func theKeysAreFetchedOnceForPagesOnDifferentPreviewPages() async {
        let site = ReaderTestSite(usesMPV: true)
        let resolver = makeResolver(site, limit: 4)
        resolver.setFocus(40)
        resolver.need([39, 40, 41, 42])

        await readerEventually { [39, 40, 41, 42].allSatisfy { resolver.state(of: $0) != .pending } }

        #expect(site.count(of: "mpv") == 1)
        #expect(resolver.state(of: 41) == .image(site.mpvImage(41)))
    }

    @Test func refetchSendsTheSkipServerIdentifierOfTheLastDispatch() async {
        let site = ReaderTestSite(pageCount: 3, usesMPV: true)
        let resolver = makeResolver(site)
        resolver.need([2])
        await readerEventually { resolver.state(of: 3) != .pending }

        resolver.refetch(2)

        await readerEventually { resolver.state(of: 2) == .image(site.reloadedMPVImage(2)) }
        #expect(site.started.last == "dispatch:2:nl=skip2")
        // A first dispatch never sends one.
        #expect(site.started.filter { $0.contains("nl=") }.count == 1)
    }

    @Test func aKeyListThatDoesNotCoverTheGalleryIsNotFound() async {
        let site = ReaderTestSite(pageCount: 60, usesMPV: true, mpvKeyCount: 59)
        let resolver = makeResolver(site)
        resolver.need([5, 6])

        await readerEventually { resolver.state(of: 5) == .failed && resolver.state(of: 6) == .failed }

        #expect(resolver.failure(of: 5) == .notFound)
        #expect(resolver.mpvKeys == nil)
        #expect(site.started == ["links:0", "mpv"])
        // Pages that were not waiting are untouched, and nothing was fetched eagerly.
        #expect(resolver.state(of: 1) == .pending)
        #expect(resolver.failure(of: 1) == nil)
    }

    @Test func aFailedKeyRequestRecoversWithARetry() async {
        let site = ReaderTestSite(usesMPV: true)
        site.fail("mpv")
        let resolver = makeResolver(site, limit: 2)
        resolver.need([10, 11])
        await readerEventually { resolver.state(of: 10) == .failed && resolver.state(of: 11) == .failed }
        #expect(resolver.failure(of: 10) == .networkingFailed)

        resolver.retry(10)

        await readerEventually {
            resolver.state(of: 10) == .image(site.mpvImage(10)) && resolver.state(of: 11) == .image(site.mpvImage(11))
        }
        #expect(site.count(of: "mpv") == 2)
        #expect(site.count(of: "links:0") == 1)
    }

    @Test func aStoredMultiPageViewerLinkLeadsStraightToTheKeys() async {
        let site = ReaderTestSite(usesMPV: true)
        let resolver = makeResolver(site)
        let stored = URL(string: "https://e-hentai.org/mpv/\(site.gid)/\(site.token)/#page7")!
        resolver.restore(previewConfig: nil, links: [7: stored], images: [:])
        resolver.setFocus(7)
        resolver.need([7])

        await readerEventually { resolver.state(of: 7) == .image(site.mpvImage(7)) }

        #expect(Array(site.started.prefix(2)) == ["mpv", "dispatch:7"])
        #expect(resolver.link(of: 7) == nil)
    }
}

@Suite struct ReaderPageResolverPagingTests {
    @Test func aPageThatIsAMultipleOfTheBatchSizeUsesItsOwnPreviewPage() async {
        let site = ReaderTestSite(pageCount: 100, batchSize: 40)
        let resolver = ReaderPageResolver(gallery: site.gallery, client: site.client, previewConfig: .normal(rows: 4))
        resolver.setFocus(40)
        resolver.need([40])
        await readerEventually { resolver.state(of: 40) == .image(site.image(40)) }
        // Legacy asked for preview page 1 here, which lists pages 41 to 80.
        #expect(site.started == ["links:0", "page:40"])

        resolver.setFocus(80)
        resolver.need([80, 81])
        await readerEventually { resolver.state(of: 80) != .pending && resolver.state(of: 81) != .pending }
        #expect(Set(site.started.filter { $0.hasPrefix("links") }) == ["links:0", "links:1", "links:2"])
        #expect(resolver.state(of: 81) == .image(site.image(81)))
    }

    @Test func correctsAWrongBatchSizeFromTheResponse() async {
        // Nothing stored, so 40 is assumed, but the site lists 20 per preview page.
        let site = ReaderTestSite(pageCount: 100, batchSize: 20)
        let resolver = ReaderPageResolver(gallery: site.gallery, client: site.client, previewConfig: nil)
        resolver.setFocus(25)
        resolver.need([25])

        await readerEventually { resolver.state(of: 25) != .pending }

        #expect(resolver.state(of: 25) == .image(site.image(25)))
        #expect(site.started == ["links:0", "links:1", "page:25"])
        #expect(resolver.paging.batchSize == 20)
    }

    @Test func correctsABatchSizeThatWasStoredTooSmall() async {
        let site = ReaderTestSite(pageCount: 100, batchSize: 40)
        let resolver = ReaderPageResolver(gallery: site.gallery, client: site.client, previewConfig: .large(rows: 4))
        resolver.setFocus(25)
        resolver.need([25])

        await readerEventually { resolver.state(of: 25) != .pending }

        // Preview page 1 was asked for (20 per page) and started at 41: the size is 40.
        #expect(resolver.state(of: 25) == .image(site.image(25)))
        #expect(site.started == ["links:1", "links:0", "page:25"])
        #expect(resolver.paging.batchSize == 40)
    }
}
