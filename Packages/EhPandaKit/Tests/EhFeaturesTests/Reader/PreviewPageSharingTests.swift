import EhDatabase
@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

/// A preview page lists the thumbnails and the viewer links of its pages. Whoever fetches it
/// keeps both, so the detail screen, the previews grid, the reader and the reader's slider
/// never fetch the same preview page for the half another of them dropped.
@Suite struct PreviewPageSharingTests {
    /// A detail environment whose requests go to the reader's test site, so one site sees
    /// what the detail feature and the reader ask for, in order.
    private func detailEnvironment(on site: ReaderTestSite) async throws -> DetailEnvironment {
        let env = try await DetailEnvironment()
        env.transport.on(.any, reply: .handler { [site] request in try await site.transport.send(request) })
        return env
    }

    // MARK: Detail screen, then READ

    @Test func theReaderStartsAtTheViewerPageOnceTheDetailPageHasLoaded() async throws {
        let site = ReaderTestSite()
        let env = try await detailEnvironment(on: site)
        let detail = env.makeDetailModel(gallery: site.gallery)
        await detail.load()
        #expect(detail.detail != nil)
        #expect(site.started == ["detail"])

        // READ: the reader is a new model that knows the gallery only through the database.
        let harness = try ReaderModelHarness(site: site, database: env.database)
        let model = await harness.startedModel()
        model.pagesNeeded([1, 2, 3])
        await readerEventually { (1...3).allSatisfy { model.pageState(at: $0) == .image(site.image($0)) } }

        // The detail response listed the viewer links: no `?p=0` in front of the first page.
        // (The three viewer pages are requested at once, so they arrive in any order.)
        #expect(site.started.first == "detail")
        #expect(site.started.dropFirst().sorted() == ["page:1", "page:2", "page:3"])
        #expect(site.count(of: "links:0") == 0)
    }

    @Test func theDetailPageStoresTheViewerLinkAndTheThumbnailOfEveryPageItLists() async throws {
        let site = ReaderTestSite()
        let env = try await detailEnvironment(on: site)
        let detail = env.makeDetailModel(gallery: site.gallery)

        await detail.load()

        // Stored by the time the load returns: nothing to wait for before the reader opens.
        let stored = try await env.database.pages(gid: site.gid)
        #expect(stored.map(\.index) == Array(1...40))
        #expect(stored.allSatisfy { $0.pageURL == site.link($0.index) })
        #expect(stored.allSatisfy { $0.previewURL == site.preview($0.index) })
        #expect(detail.previews.count == 40)
    }

    @Test func aMultiPageViewerGalleryGoesStraightToItsKeysAfterTheDetailPage() async throws {
        let site = ReaderTestSite(usesMPV: true)
        let env = try await detailEnvironment(on: site)
        await env.makeDetailModel(gallery: site.gallery).load()

        let harness = try ReaderModelHarness(site: site, database: env.database)
        let model = await harness.startedModel()
        model.pagesNeeded([1])
        await readerEventually { model.pageState(at: 1) == .image(site.mpvImage(1)) }

        // The reader asks for the pages around the first one at once, so their dispatches start
        // in any order; what matters is that the viewer comes straight after the detail page.
        #expect(Array(site.started.prefix(2)) == ["detail", "mpv"])
        #expect(site.started.contains("dispatch:1"))
        #expect(site.count(of: "links:0") == 0)
    }

    // MARK: Previews grid, then a tap

    @Test func theReaderOpenedFromThePreviewsGridUsesTheLinksTheGridFetched() async throws {
        let site = ReaderTestSite(pageCount: 400)
        let env = try await detailEnvironment(on: site)
        let grid = env.with {
            PreviewsModel(gallery: site.gallery, pageCount: 400, config: .normal(rows: 4), previewURLs: [:])
        }
        await grid.load()
        grid.thumbnailAppeared(300)
        await pollUntil { grid.preview(at: 300) != nil }
        #expect(site.started == ["links:7"])
        await pollUntil { (try? await env.database.pages(gid: site.gid))?.count == 40 }

        let harness = try ReaderModelHarness(site: site, database: env.database)
        let model = await harness.startedModel(initialPage: 300)
        model.pagesNeeded([300])
        await readerEventually { model.pageState(at: 300) == .image(site.image(300)) }

        #expect(site.started == ["links:7", "page:300"])
        // The grid's thumbnails are the slider's too.
        #expect(model.previewURLs[300] == site.preview(300))
    }

    // MARK: Slider, then reading

    @Test func scrubbingToAFarPageAndReadingItFetchesItsPreviewPageOnce() async throws {
        let harness = try ReaderModelHarness(site: ReaderTestSite(pageCount: 600))
        let site = harness.site
        let model = await harness.startedModel()

        // The strip comes up where the reader is (preview page 0), then rests on page 500.
        model.sliderEditingChanged(true)
        model.setSliderPage(500)
        await harness.clock.advance(by: ReaderModel.previewDelay)
        await readerEventually { model.previewURLs[500] != nil }
        #expect(site.count(of: "links:12") == 1)

        // Letting go jumps there; the engine reports the new page and the pages it needs.
        model.sliderEditingChanged(false)
        #expect(harness.engineLog.last == "scroll:500")
        model.currentPageDidChange(500)
        model.pagesNeeded([499, 500, 501])
        await readerEventually { (499...501).allSatisfy { model.pageState(at: $0) == .image(site.image($0)) } }

        #expect(site.count(of: "links:12") == 1)
        let requests = site.started.filter { $0 != "links:0" }
        #expect(requests.first == "links:12")
        #expect(requests.dropFirst().sorted() == ["page:499", "page:500", "page:501"])

        // Both halves of the preview page are stored, whoever asked for it.
        await harness.flushWrites(of: model)
        let stored = try await harness.storedPages()
        #expect(stored[481]?.pageURL == site.link(481))
        #expect(stored[481]?.previewURL == site.preview(481))
        #expect(stored[500]?.imageURL == site.image(500))
    }

    @Test func aPreviewPageTheSliderAndTheReaderWantAtOnceIsRequestedOnce() async throws {
        let harness = try ReaderModelHarness(site: ReaderTestSite(pageCount: 600))
        let site = harness.site
        let model = await harness.startedModel()
        site.hold("links:12")

        model.sliderEditingChanged(true)
        model.setSliderPage(500)
        await harness.clock.advance(by: ReaderModel.previewDelay)
        await readerEventually { site.inFlight.contains("links:12") }

        // The reader arrives while the strip's request is still on its way.
        model.sliderEditingChanged(false)
        model.currentPageDidChange(500)
        model.pagesNeeded([500])
        await readerSettle()
        #expect(site.count(of: "links:12") == 1)

        // Leaving again takes back the reader's wait, not the request the strip is waiting for.
        model.pagesNoLongerNeeded([500])
        await readerSettle()
        #expect(site.cancelled.isEmpty)
        model.pagesNeeded([500])

        site.release("links:12")
        await readerEventually { model.pageState(at: 500) == .image(site.image(500)) }
        #expect(model.previewURLs[500] == site.preview(500))
        #expect(site.count(of: "links:12") == 1)
    }

    @Test func thePreviewPageTheReaderFetchedForItsLinksAlsoFillsTheSlider() async throws {
        let harness = try ReaderModelHarness()
        let site = harness.site
        let model = await harness.startedModel(initialPage: 90)
        model.pagesNeeded([90])
        await readerEventually { model.pageState(at: 90) == .image(site.image(90)) }
        #expect(site.started == ["links:2", "page:90"])

        // The thumbnails came with the links.
        #expect(model.previewURLs[90] == site.preview(90))
        #expect(model.previewURLs.count == 20)
        model.sliderEditingChanged(true)
        await harness.clock.advance(by: ReaderModel.previewDelay)
        await readerSettle()
        #expect(site.count(of: "links:2") == 1)

        await harness.flushWrites(of: model)
        let stored = try await harness.storedPages()
        #expect(stored[81]?.pageURL == site.link(81))
        #expect(stored[81]?.previewURL == site.preview(81))
    }

    @Test func aPreviewPageOnlyTheReaderWaitsForIsCancelledWhenItsPagesLeave() async throws {
        let harness = try ReaderModelHarness()
        let site = harness.site
        let model = await harness.startedModel(initialPage: 90)
        site.hold("links:2")
        model.pagesNeeded([90])
        await readerEventually { site.inFlight.contains("links:2") }

        model.pagesNoLongerNeeded([90])

        await readerEventually { site.cancelled == ["links:2"] }
        // Nothing is left behind: the page is fetched again when it is needed again.
        site.release("links:2")
        model.pagesNeeded([90])
        await readerEventually { model.pageState(at: 90) == .image(site.image(90)) }
        #expect(site.count(of: "links:2") == 2)
    }
}
