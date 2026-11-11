import CoreGraphics
import EhCore
import EhDatabase
@testable import EhFeatures
import EhModels
import EhNetworking
import Foundation
import Testing

@Suite struct ReaderModelStartTests {
    @Test func initIsCheapAndStartsNothing() async throws {
        let harness = try ReaderModelHarness()
        let model = harness.makeModel()

        await readerSettle()

        #expect(!model.isReady)
        #expect(harness.site.started.isEmpty)
        #expect(harness.orientationLocks.isEmpty)
        #expect(model.pageCount == 100)
    }

    @Test func opensOnStoredProgressWithStoredPages() async throws {
        let harness = try ReaderModelHarness()
        let stale = URL(string: "https://stored.example/2.jpg")!
        try await harness.database.upsertPages([
            GalleryPage(
                gid: harness.gid, index: 2, pageURL: harness.site.link(2), imageURL: stale,
                originalImageURL: harness.site.original(2), previewURL: harness.site.preview(2),
                imageWidth: 800, imageHeight: 1200
            ),
            GalleryPage(gid: harness.gid, index: 3, pageURL: harness.site.link(3)),
            // Beyond the gallery: ignored.
            GalleryPage(gid: harness.gid, index: 500, imageURL: stale)
        ])
        try await harness.database.updateReadingProgress(gid: harness.gid, progress: 37)
        let model = harness.makeModel()

        await model.start()

        #expect(model.isReady)
        #expect(model.initialPage == 37)
        #expect(model.currentPage == 37)
        #expect(model.sliderPage == 37)
        // Stored URLs and sizes are there before any request.
        #expect(model.pageState(at: 2) == .image(stale))
        #expect(model.aspectRatio(at: 2) == CGFloat(800) / CGFloat(1200))
        #expect(model.pageState(at: 3) == .pending)
        #expect(model.aspectRatio(at: 3) == nil)
        #expect(model.pageState(at: 500) == .pending)
        #expect(model.previewURLs == [2: harness.site.preview(2)])
        #expect(model.imageActions(for: 2) == [.reload, .copy, .save, .saveOriginal, .share])
        #expect(harness.site.started.isEmpty)
        // Landscape is off by default: the orientation is left alone.
        #expect(harness.orientationLocks.isEmpty)

        // The stored link saves the preview-page request.
        model.pagesNeeded([3])
        await readerEventually { model.pageState(at: 3) == .image(harness.site.image(3)) }
        #expect(harness.site.started == ["page:3"])
    }

    @Test func aRequestedPageWinsOverStoredProgressAndIsSaved() async throws {
        let harness = try ReaderModelHarness()
        try await harness.database.updateReadingProgress(gid: harness.gid, progress: 37)

        let model = await harness.startedModel(initialPage: 12)

        #expect(model.initialPage == 12)
        #expect(model.currentPage == 12)
        await harness.clock.advance(by: ReaderPageWriter.progressDelay)
        await model.waitUntilSaved()
        #expect(try await harness.storedProgress() == 12)
    }

    @Test func theFirstPageIsClampedToTheGallery() async throws {
        let harness = try ReaderModelHarness()
        #expect(await harness.startedModel(initialPage: 400).initialPage == 100)
        #expect(await harness.startedModel(initialPage: 0).initialPage == 1)
        #expect(await harness.startedModel(initialPage: -3).initialPage == 1)
    }

    @Test func aGalleryThatWasNeverOpenedStartsOnPageOneAndSavesNothing() async throws {
        let harness = try ReaderModelHarness()

        let model = await harness.startedModel()

        #expect(model.initialPage == 1)
        await harness.flushWrites(of: model)
        model.close()
        await model.waitUntilSaved()
        #expect(try await harness.storedProgress() == nil)
        #expect(model.writer.writeCount == 0)
    }

    @Test func theStoredPreviewLayoutDecidesThePreviewPage() async throws {
        let harness = try ReaderModelHarness(site: ReaderTestSite(batchSize: 20))
        try await harness.storeDetail(previewConfig: .large(rows: 4))
        let model = await harness.startedModel(initialPage: 25)

        model.pagesNeeded([25])

        await readerEventually { model.pageState(at: 25) == .image(harness.site.image(25)) }
        #expect(harness.site.started == ["links:1", "page:25"])
    }

    @Test func startMeasuresTheTimeToTheFirstPage() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        #expect(model.timeToFirstPage == nil)

        model.imageDidLoad(page: 1, pixelSize: CGSize(width: 100, height: 150))
        let first = try #require(model.timeToFirstPage)
        model.imageDidLoad(page: 2, pixelSize: CGSize(width: 100, height: 150))

        #expect(first >= .zero)
        #expect(model.timeToFirstPage == first)
    }

    /// The log files are in Documents, where the Files app shows them, and the release build
    /// writes `info` and above: a line naming the gallery would be a list of what was read.
    @Test func theLogDoesNotSayWhichGalleryWasRead() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ReaderLogTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let logger = AppLogger.live(directory: directory, minimumLevel: .info)
        let harness = try ReaderModelHarness()
        harness.logger = logger
        let gallery = Gallery(
            gid: "987654321", token: "0a1b2c3d4e", title: "A very private title", rating: 4, tags: [],
            category: .doujinshi, pageCount: 100, postedDate: Date(timeIntervalSince1970: 0), coverURL: nil,
            galleryURL: URL(string: "https://e-hentai.org/g/987654321/0a1b2c3d4e/")
        )
        let model = harness.makeModel(gallery: gallery)
        await model.start()

        model.pagesNeeded([1, 2])
        model.imageDidLoad(page: 1, pixelSize: CGSize(width: 100, height: 150))
        model.currentPageDidChange(2)
        await harness.flushWrites(of: model)
        model.close()
        await model.waitUntilSaved()
        await logger.flush()

        var lines: [String] = []
        for file in await logger.logFiles() {
            lines += try await logger.lines(of: file)
        }
        // The timing is logged; nothing that identifies the gallery is.
        #expect(lines.contains { $0.contains("First page shown after") })
        #expect(!lines.contains { $0.contains("987654321") || $0.contains("0a1b2c3d4e") || $0.contains("private") })
    }
}

@Suite struct ReaderModelResolutionTests {
    @Test func resolvesNeededPagesTellsTheEngineAndSavesInOneWrite() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()

        model.pagesNeeded([1, 2, 3])
        await readerEventually { (1...3).allSatisfy { model.pageState(at: $0) == .image(harness.site.image($0)) } }

        #expect(Set(harness.engineLog) == ["reload:1", "reload:2", "reload:3"])
        #expect(harness.site.started.first == "links:0")
        // Nothing has been written while the pages were coming in.
        #expect(model.writer.writeCount == 0)
        #expect(try await harness.storedPages().isEmpty)

        await harness.flushWrites(of: model)

        // 40 links and 3 images, one transaction.
        #expect(model.writer.writeCount == 1)
        let stored = try await harness.storedPages()
        #expect(stored.count == 40)
        #expect(stored[2]?.pageURL == harness.site.link(2))
        #expect(stored[2]?.imageURL == harness.site.image(2))
        #expect(stored[2]?.originalImageURL == harness.site.original(2))
        #expect(stored[40]?.pageURL == harness.site.link(40))
        #expect(stored[40]?.imageURL == nil)
    }

    @Test func multiPageViewerGalleriesResolveThroughTheAPI() async throws {
        let harness = try ReaderModelHarness(site: ReaderTestSite(pageCount: 60, usesMPV: true))
        let model = await harness.startedModel(initialPage: 20)

        model.pagesNeeded([20, 21])
        await readerEventually { model.pageState(at: 3) != .pending }

        #expect(model.pageState(at: 20) == .image(harness.site.mpvImage(20)))
        #expect(model.pageState(at: 21) == .image(harness.site.mpvImage(21)))
        #expect(Array(harness.site.started.prefix(2)) == ["links:0", "mpv"])
        #expect(model.imageActions(for: 20).contains(.saveOriginal))
        await harness.flushWrites(of: model)
        let stored = try await harness.storedPages()
        // Everything the preview page listed is kept, and the images of the pages asked for
        // and of the three legacy fetched eagerly.
        #expect(Set(stored.keys) == Set(1...40))
        #expect(Set(stored.values.filter { $0.imageURL != nil }.map(\.index)) == [1, 2, 3, 20, 21])
        #expect(stored[20]?.imageURL == harness.site.mpvImage(20))
        #expect(stored[20]?.originalImageURL == harness.site.mpvOriginal(20))
        #expect(stored[40]?.previewURL == harness.site.preview(40))
        #expect(EhURL.isMPVURL(stored[20]?.pageURL))

        // The stored link says where the keys are: the next session, on a preview page nobody
        // has fetched, goes straight to them.
        model.close()
        let requests = harness.site.started.count
        let reopened = await harness.startedModel(initialPage: 45)
        reopened.pagesNeeded([45])
        await readerEventually { reopened.pageState(at: 45) == .image(harness.site.mpvImage(45)) }
        #expect(Array(harness.site.started.dropFirst(requests).prefix(2)) == ["mpv", "dispatch:45"])
        #expect(harness.site.count(of: "links:1") == 0)
    }

    @Test func releasedPagesStopResolving() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        harness.site.hold("links:0")
        model.pagesNeeded([1, 2])
        await readerEventually { harness.site.inFlight == ["links:0"] }

        model.pagesNoLongerNeeded([1, 2])

        await readerEventually { harness.site.cancelled == ["links:0"] }
        #expect(harness.engineLog.isEmpty)
    }

    @Test func theCurrentPageDecidesWhatResolvesFirst() async throws {
        let harness = try ReaderModelHarness()
        try await harness.database.upsertPages((1...40).map {
            GalleryPage(gid: harness.gid, index: $0, pageURL: harness.site.link($0))
        })
        let model = await harness.startedModel()
        harness.site.holdEverything()
        // The engine announces the pages and then the page it landed on.
        model.pagesNeeded(Array(1...30))
        model.currentPageDidChange(20)

        await readerEventually { harness.site.inFlight.count == 4 }
        await readerSettle()

        #expect(harness.site.inFlight == ["page:20", "page:21", "page:19", "page:22"])
        harness.site.releaseEverything()
        model.close()
    }

    @Test func aFailedResolutionIsRetriedFromTheStart() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        harness.site.fail("page:2")
        model.pagesNeeded([1, 2])
        await readerEventually {
            model.pageState(at: 2) == .failed && model.pageState(at: 1) == .image(harness.site.image(1))
        }
        harness.clearEngineLog()

        model.retry(page: 2)

        #expect(model.pageState(at: 2) == .pending)
        await readerEventually { model.pageState(at: 2) == .image(harness.site.image(2)) }
        // Once for the spinner, once for the image.
        #expect(harness.engineLog == ["reload:2", "reload:2"])
        #expect(!harness.site.started.contains("reload:2"))
    }

    @Test func aFailedImageIsRetriedThroughAnotherServer() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        model.pagesNeeded([2])
        await readerEventually { model.pageState(at: 2) == .image(harness.site.image(2)) }

        model.imageDidFail(page: 2)
        // The URL is from this session, so it stays until the user asks.
        await readerSettle()
        #expect(model.pageState(at: 2) == .image(harness.site.image(2)))
        #expect(harness.site.count(of: "page:2") == 1)

        model.retry(page: 2)

        #expect(model.pageState(at: 2) == .pending)
        await readerEventually { model.pageState(at: 2) == .image(harness.site.reloadedImage(2)) }
        #expect(Array(harness.site.started.suffix(2)) == ["page:2", "reload:2"])
        await harness.flushWrites(of: model)
        #expect(try await harness.storedPages()[2]?.imageURL == harness.site.reloadedImage(2))
    }

    @Test func aStoredImageURLThatFailsIsResolvedAgainOnce() async throws {
        let harness = try ReaderModelHarness()
        let stale = URL(string: "https://stored.example/4.jpg")!
        try await harness.database.upsertPages([
            GalleryPage(gid: harness.gid, index: 4, pageURL: harness.site.link(4), imageURL: stale)
        ])
        let model = await harness.startedModel()
        #expect(model.pageState(at: 4) == .image(stale))
        model.pagesNeeded([4])

        model.imageDidFail(page: 4)

        #expect(model.pageState(at: 4) == .pending)
        await readerEventually { model.pageState(at: 4) == .image(harness.site.image(4)) }
        // The viewer page again, not another image server.
        #expect(harness.site.started == ["page:4"])
        #expect(harness.engineLog == ["reload:4", "reload:4"])

        // A second failure is the user's to retry.
        model.imageDidFail(page: 4)
        await readerSettle()
        #expect(model.pageState(at: 4) == .image(harness.site.image(4)))
        #expect(harness.site.started == ["page:4"])
    }

    /// The engine prefetches the images of the pages around the visible ones, so a stored URL
    /// can turn out to have expired after its page has left that window.
    @Test func aStoredImageURLThatFailsAfterItsPageLeftTheWindowWaitsUntilThePageIsNeeded() async throws {
        let harness = try ReaderModelHarness()
        let stale = URL(string: "https://stored.example/4.jpg")!
        try await harness.database.upsertPages([
            GalleryPage(gid: harness.gid, index: 4, pageURL: harness.site.link(4), imageURL: stale)
        ])
        let model = await harness.startedModel()
        model.pagesNeeded([4])
        model.pagesNoLongerNeeded([4])

        model.imageDidFail(page: 4)

        #expect(model.pageState(at: 4) == .pending)
        await readerSettle()
        #expect(harness.site.started.isEmpty)

        model.pagesNeeded([4])
        await readerEventually { model.pageState(at: 4) == .image(harness.site.image(4)) }
        #expect(harness.site.started == ["page:4"])
    }

    @Test func aStoredImageURLThatLoadedIsNotSuspectAnyMore() async throws {
        let harness = try ReaderModelHarness()
        let stored = URL(string: "https://stored.example/4.jpg")!
        try await harness.database.upsertPages([
            GalleryPage(gid: harness.gid, index: 4, pageURL: harness.site.link(4), imageURL: stored)
        ])
        let model = await harness.startedModel()
        model.imageDidLoad(page: 4, pixelSize: CGSize(width: 10, height: 10))

        model.imageDidFail(page: 4)

        await readerSettle()
        #expect(model.pageState(at: 4) == .image(stored))
        #expect(harness.site.started.isEmpty)
    }

    @Test func closeCancelsRequestsAndIgnoresLaterEvents() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        harness.site.hold("links:0")
        model.pagesNeeded([1, 2])
        await readerEventually { harness.site.inFlight == ["links:0"] }

        model.close()
        model.close()

        await readerEventually { harness.site.cancelled == ["links:0"] }
        harness.site.release("links:0")
        await readerSettle()
        #expect(model.pageState(at: 1) == .pending)
        #expect(harness.engineLog.isEmpty)
        // Portrait is restored once, not once per call.
        #expect(harness.orientationLocks == [.portrait])
    }
}

@Suite struct ReaderModelPersistenceTests {
    @Test func imageSizesBecomeAspectRatiosAndAreSavedOnce() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()

        model.imageDidLoad(page: 2, pixelSize: CGSize(width: 800, height: 1200))
        model.imageDidLoad(page: 5, pixelSize: CGSize(width: 1000, height: 500))
        #expect(model.aspectRatio(at: 2) == CGFloat(800) / CGFloat(1200))
        await harness.flushWrites(of: model)

        var stored = try await harness.storedPages()
        #expect(stored[2]?.imageWidth == 800)
        #expect(stored[2]?.imageHeight == 1200)
        #expect(stored[5]?.imageWidth == 1000)
        #expect(model.writer.writeCount == 1)

        // Zooming in decodes the page larger; its shape is the same and is not written again.
        model.imageDidLoad(page: 2, pixelSize: CGSize(width: 1600, height: 2400))
        await harness.flushWrites(of: model)
        #expect(model.writer.writeCount == 1)

        // A different shape (the image behind the URL changed) is.
        model.imageDidLoad(page: 2, pixelSize: CGSize(width: 900, height: 900))
        await harness.flushWrites(of: model)
        stored = try await harness.storedPages()
        #expect(stored[2]?.imageWidth == 900)
        #expect(model.aspectRatio(at: 2) == 1)
        #expect(model.writer.writeCount == 2)
    }

    @Test func storedSizesAreNotWrittenBack() async throws {
        let harness = try ReaderModelHarness()
        try await harness.database.upsertPages([
            GalleryPage(gid: harness.gid, index: 2, imageWidth: 800, imageHeight: 1200)
        ])
        let model = await harness.startedModel()

        model.imageDidLoad(page: 2, pixelSize: CGSize(width: 400, height: 600))

        await harness.flushWrites(of: model)
        #expect(model.writer.writeCount == 0)
    }

    @Test func aBurstOfChangesIsOneWriteAndTheNextBurstAnother() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        for page in 1...20 {
            model.imageDidLoad(page: page, pixelSize: CGSize(width: 100, height: 100 + page))
        }

        // Still inside the collecting window.
        await harness.clock.advance(by: ReaderPageWriter.pageDelay - .milliseconds(1))
        await model.waitUntilSaved()
        #expect(model.writer.writeCount == 0)
        await harness.clock.advance(by: .milliseconds(1))
        await model.waitUntilSaved()
        #expect(model.writer.writeCount == 1)
        #expect(try await harness.storedPages().count == 20)

        model.imageDidLoad(page: 30, pixelSize: CGSize(width: 100, height: 100))
        await harness.flushWrites(of: model)
        #expect(model.writer.writeCount == 2)
        #expect(try await harness.storedPages().count == 21)
    }

    @Test func progressIsSavedOnceTheReaderRestsOnAPage() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()

        // Flicking through pages: each turn restarts the wait.
        for page in 2...6 {
            model.currentPageDidChange(page)
            await harness.clock.advance(by: ReaderPageWriter.progressDelay - .milliseconds(100))
        }
        await model.waitUntilSaved()
        #expect(model.writer.writeCount == 0)
        #expect(try await harness.storedProgress() == nil)
        #expect(model.currentPage == 6)
        #expect(model.sliderPage == 6)

        await harness.clock.advance(by: .milliseconds(100))
        await model.waitUntilSaved()

        #expect(model.writer.writeCount == 1)
        #expect(try await harness.storedProgress() == 6)
    }

    @Test func closingSavesWhatIsStillWaiting() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()
        model.pagesNeeded([1])
        await readerEventually { model.pageState(at: 1) == .image(harness.site.image(1)) }
        model.imageDidLoad(page: 1, pixelSize: CGSize(width: 700, height: 1000))
        model.currentPageDidChange(9)

        // Closed before either timer ran out.
        model.close()
        await model.waitUntilSaved()

        #expect(try await harness.storedProgress() == 9)
        let stored = try await harness.storedPages()
        #expect(stored[1]?.imageURL == harness.site.image(1))
        #expect(stored[1]?.imageWidth == 700)
        #expect(stored[1]?.pageURL == harness.site.link(1))
        // One transaction for the pages, one for the progress.
        #expect(model.writer.writeCount == 2)
    }
}
