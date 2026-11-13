import CoreGraphics
import EhCore
import EhDatabase
@testable import EhFeatures
import EhModels
import Foundation
import Testing

@Suite struct ReaderModelSliderTests {
    @Test func theSliderFollowsTheReaderAndJumpsWhenMovedWithoutTheStrip() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        model.currentPageDidChange(4)
        #expect(model.sliderPage == 4)

        model.setSliderPage(10)

        #expect(model.sliderPage == 10)
        #expect(harness.engineLog == ["scroll:10"])
        // Out of range values are clamped; the same value does nothing.
        model.setSliderPage(1_000)
        model.setSliderPage(100)
        #expect(harness.engineLog == ["scroll:10", "scroll:100"])
        model.setSliderPage(-5)
        #expect(model.sliderPage == 1)
    }

    @Test func whileTheStripIsUpTheReaderStaysAndLettingGoJumps() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        model.setAutoPlay(.threeSeconds)

        model.sliderEditingChanged(true)
        #expect(model.showsSliderPreview)
        // Legacy: the strip turns auto-play off.
        #expect(model.autoPlay == .off)
        model.setSliderPage(30)
        model.setSliderPage(31)
        #expect(model.sliderPage == 31)
        #expect(harness.engineLog.isEmpty)
        // The reader reporting its page does not move the slider under the finger.
        model.currentPageDidChange(2)
        #expect(model.sliderPage == 31)

        model.sliderEditingChanged(false)

        #expect(!model.showsSliderPreview)
        #expect(harness.engineLog == ["scroll:31"])
        model.currentPageDidChange(31)
        #expect(model.sliderPage == 31)
        // Letting go where the reader already is does not scroll.
        model.sliderEditingChanged(true)
        model.sliderEditingChanged(false)
        #expect(harness.engineLog == ["scroll:31"])
    }

    @Test func stripPagesAreCentredOnTheSlider() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel(initialPage: 50)
        #expect(model.previewStripPages == [48, 49, 50, 51, 52])
        model.previewStripLength = 7
        #expect(model.previewStripPages == Array(47...53))
        model.setSliderPage(1)
        // Places outside the gallery are kept; the strip leaves them empty.
        #expect(model.previewStripPages == Array(-2...4))
    }

    @Test func theStripShowsFiveThumbnailsAndSevenOnAWideLandscapeWindow() {
        #expect(ReaderModel.previewStripLength(isRegularWidth: false, isLandscape: false) == 5)
        #expect(ReaderModel.previewStripLength(isRegularWidth: false, isLandscape: true) == 5)
        #expect(ReaderModel.previewStripLength(isRegularWidth: true, isLandscape: false) == 5)
        #expect(ReaderModel.previewStripLength(isRegularWidth: true, isLandscape: true) == 7)
    }

    @Test func pagesLeftCountFromTheSliderAndFollowItWhileDragging() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel(initialPage: 12)
        #expect(model.pageCount == 100)
        #expect(model.sliderPagesLeft == 88)

        model.sliderEditingChanged(true)
        model.setSliderPage(18)
        #expect(model.sliderPagesLeft == 82)
        // The reader reporting its page while the slider is held changes nothing.
        model.currentPageDidChange(13)
        #expect(model.sliderPagesLeft == 82)
        model.sliderEditingChanged(false)

        model.currentPageDidChange(100)
        #expect(model.sliderPagesLeft == 0)
        model.currentPageDidChange(1)
        #expect(model.sliderPagesLeft == 99)
    }

    @Test func previewsAreFetchedWhenTheStripAppearsOnAFreshGallery() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        #expect(model.previewURLs.isEmpty)

        model.sliderEditingChanged(true)

        await readerEventually { model.previewURLs.count == 40 }
        #expect(harness.site.started == ["links:0"])
        #expect(model.previewURLs[1] == harness.site.preview(1))
        #expect(model.previewURLs[40] == harness.site.preview(40))
        await harness.flushWrites(of: model)
        #expect(try await harness.storedPages()[7]?.previewURL == harness.site.preview(7))
        #expect(model.writer.writeCount == 1)
    }

    @Test func previewsAreFetchedWhereTheSliderRestsNotWhereItPasses() async throws {
        let harness = try ReaderModelHarness(site: ReaderTestSite(pageCount: 400))
        let model = await harness.startedModel()
        model.sliderEditingChanged(true)
        await readerEventually { model.previewURLs.count == 40 }

        // A drag across the gallery: every value passes within the wait.
        for page in stride(from: 10, through: 390, by: 20) {
            model.setSliderPage(page)
            await harness.clock.advance(by: ReaderModel.previewDelay - .milliseconds(50))
        }
        await readerSettle()
        #expect(harness.site.started == ["links:0"])

        // It rests on page 390.
        await harness.clock.advance(by: .milliseconds(50))
        await readerEventually { model.previewURLs[390] != nil }
        #expect(harness.site.started == ["links:0", "links:9"])
        #expect(model.previewURLs[390] == harness.site.preview(390))
    }

    @Test func aStripAcrossTwoPreviewPagesFetchesBothOnce() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel(initialPage: 40)

        model.sliderEditingChanged(true)
        await readerEventually { model.previewURLs[40] != nil && model.previewURLs[41] != nil }
        model.sliderEditingChanged(false)
        model.sliderEditingChanged(true)
        await readerSettle()

        #expect(Set(harness.site.started) == ["links:0", "links:1"])
        #expect(harness.site.started.count == 2)
    }

    @Test func aFailedPreviewPageIsLeftAloneUntilRetryAllFailed() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        harness.site.fail("links:0")
        model.sliderEditingChanged(true)
        await readerEventually { harness.site.started == ["links:0"] && harness.site.inFlight.isEmpty }
        await readerSettle()
        model.setSliderPage(5)
        await harness.clock.advance(by: ReaderModel.previewDelay)
        await readerSettle()
        #expect(harness.site.started == ["links:0"])

        model.retryAllFailedImages()
        model.setSliderPage(6)
        await harness.clock.advance(by: ReaderModel.previewDelay)

        await readerEventually { model.previewURLs[6] == harness.site.preview(6) }
        #expect(harness.site.started == ["links:0", "links:0"])
    }

    @Test func previewsCorrectAWrongPageSize() async throws {
        // Nothing stored: 40 per preview page is assumed, the site has 20.
        let harness = try ReaderModelHarness(site: ReaderTestSite(batchSize: 20))
        let model = await harness.startedModel(initialPage: 30)

        model.sliderEditingChanged(true)

        await readerEventually { model.previewURLs[30] != nil }
        #expect(harness.site.started == ["links:0", "links:1"])
        #expect(model.previewURLs[30] == harness.site.preview(30))
    }
}

@Suite struct ReaderModelAutoPlayTests {
    @Test func turnsThePageEveryIntervalAndStopsAtTheEnd() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()

        model.setAutoPlay(.twoSeconds)
        #expect(model.autoPlay == .twoSeconds)
        await harness.clock.advance(by: .seconds(1))
        #expect(harness.engineLog.isEmpty)
        await harness.clock.advance(by: .seconds(1))
        #expect(harness.engineLog == ["advance"])
        await harness.clock.advance(by: .seconds(4))
        #expect(harness.engineCount("advance") == 3)

        // The engine has nowhere to go: legacy kept its timer firing.
        harness.canAdvance = false
        await harness.clock.advance(by: .seconds(2))
        #expect(harness.engineCount("advance") == 4)
        #expect(model.autoPlay == .off)
        await harness.clock.advance(by: .seconds(10))
        #expect(harness.engineCount("advance") == 4)
    }

    @Test func stopsOnArrivingAtTheLastPage() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel(initialPage: 98)
        model.setAutoPlay(.oneSecond)
        await harness.clock.advance(by: .seconds(1))
        model.currentPageDidChange(99)
        #expect(model.autoPlay == .oneSecond)
        await harness.clock.advance(by: .seconds(1))

        model.currentPageDidChange(100)

        #expect(model.autoPlay == .off)
        await harness.clock.advance(by: .seconds(5))
        #expect(harness.engineCount("advance") == 2)
    }

    @Test func aNewIntervalReplacesTheOldOneAndOffStops() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        model.setAutoPlay(.fiveSeconds)
        await harness.clock.advance(by: .seconds(4))

        model.setAutoPlay(.oneSecond)
        await harness.clock.advance(by: .seconds(1))
        #expect(harness.engineCount("advance") == 1)

        model.setAutoPlay(.off)
        await harness.clock.advance(by: .seconds(10))
        #expect(harness.engineCount("advance") == 1)
        #expect(ReaderAutoPlayPolicy.allCases.map(\.seconds) == [nil, 1, 2, 3, 4, 5])
    }

    @Test func sheetsAndClosingTurnItOff() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()

        model.setAutoPlay(.oneSecond)
        model.showSettings()
        #expect(model.destination == .settings)
        #expect(model.autoPlay == .off)

        // Dismissing the sheet does not turn it back on, and the HUD leaves it running.
        model.destination = nil
        model.setAutoPlay(.oneSecond)
        model.notice = .copiedToClipboard
        #expect(model.autoPlay == .oneSecond)

        model.close()
        #expect(model.autoPlay == .off)
        await harness.clock.advance(by: .seconds(5))
        #expect(harness.engineLog.isEmpty)
    }
}

@Suite struct ReaderModelReloadTests {
    @Test func reloadAllForgetsEverythingInMemoryAndInTheDatabase() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        model.pagesNeeded([1, 2])
        await readerEventually { model.pageState(at: 1) != .pending && model.pageState(at: 2) != .pending }
        model.imageDidLoad(page: 1, pixelSize: CGSize(width: 700, height: 1000))
        model.sliderEditingChanged(true)
        await readerEventually { model.previewURLs.count == 40 }
        model.sliderEditingChanged(false)
        await harness.flushWrites(of: model)
        #expect(try await harness.storedPages().count == 40)
        // A change that is still waiting to be written must not survive the reload.
        model.imageDidLoad(page: 2, pixelSize: CGSize(width: 700, height: 1000))
        harness.clearEngineLog()
        harness.site.hold("links:0")

        model.reloadAllImages()

        #expect(harness.engineLog == ["reloadData"])
        #expect(model.pageState(at: 1) == .pending)
        #expect(model.imageActions(for: 1) == [.reload])
        #expect(model.previewURLs.isEmpty)
        await harness.flushWrites(of: model)
        #expect(try await harness.storedPages().isEmpty)

        // The pages are still needed (the engine announces them again) and resolve from scratch.
        harness.site.release("links:0")
        await readerEventually { model.pageState(at: 1) == .image(harness.site.image(1)) }
        #expect(harness.site.count(of: "page:1") == 2)
        await harness.flushWrites(of: model)
        let stored = try await harness.storedPages()
        #expect(stored[1]?.imageURL == harness.site.image(1))
        #expect(stored[1]?.imageWidth == nil)
        // The size is saved again when the image is back on screen.
        model.imageDidLoad(page: 1, pixelSize: CGSize(width: 700, height: 1000))
        await harness.flushWrites(of: model)
        #expect(try await harness.storedPages()[1]?.imageWidth == 700)
    }

    @Test func reloadAllForgetsTheMultiPageViewerKeys() async throws {
        let harness = try ReaderModelHarness(site: ReaderTestSite(pageCount: 10, usesMPV: true))
        let model = await harness.startedModel()
        model.pagesNeeded([1])
        await readerEventually { model.pageState(at: 3) != .pending }

        model.reloadAllImages()

        await readerEventually { model.pageState(at: 3) != .pending }
        #expect(harness.site.count(of: "mpv") == 2)
        #expect(harness.site.count(of: "dispatch:1") == 2)
    }

    @Test func retryAllFailedResetsFailedPagesAndReloadsFailedImages() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        harness.site.fail("page:2")
        model.pagesNeeded([1, 2, 3])
        await readerEventually { model.pageState(at: 2) == .failed && model.pageState(at: 3) != .pending }
        model.imageDidFail(page: 3)
        harness.clearEngineLog()

        model.retryAllFailedImages()

        // Page 2 resolves again; page 3 loads the URL it has (legacy: back to idle).
        #expect(model.pageState(at: 2) == .pending)
        await readerEventually { model.pageState(at: 2) == .image(harness.site.image(2)) }
        #expect(model.pageState(at: 3) == .image(harness.site.image(3)))
        #expect(harness.engineCount("reload:3") == 1)
        #expect(harness.engineCount("reload:2") == 2)
        #expect(!harness.site.started.contains("reload:3"))
        #expect(harness.site.count(of: "page:3") == 1)

        // The failure is forgotten: a later retry of page 3 is a plain one, not a refetch.
        model.retryAllFailedImages()
        #expect(harness.engineCount("reload:3") == 1)
    }
}
