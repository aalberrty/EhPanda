import EhCore
import EhDatabase
@testable import EhFeatures
import EhModels
import Foundation
import Testing

@Suite struct ReaderModelImageActionTests {
    /// A model whose page 2 has an image and an original.
    private func modelWithPage2(_ harness: ReaderModelHarness) async -> ReaderModel {
        let model = await harness.startedModel()
        model.pagesNeeded([2])
        await readerEventually { model.pageState(at: 2) != .pending }
        return model
    }

    @Test func theMenuOffersWhatThePageHas() async throws {
        let harness = try ReaderModelHarness()
        try await harness.database.upsertPages([
            GalleryPage(gid: harness.gid, index: 5, imageURL: harness.site.image(5))
        ])
        let model = await modelWithPage2(harness)

        #expect(model.imageActions(for: 1) == [.reload])
        #expect(model.imageActions(for: 2) == [.reload, .copy, .save, .saveOriginal, .share])
        // No original offered: no "Save original".
        #expect(model.imageActions(for: 5) == [.reload, .copy, .save, .share])
    }

    @Test func copyPutsTheOriginalBytesOnTheClipboard() async throws {
        let harness = try ReaderModelHarness()
        let model = await modelWithPage2(harness)

        model.perform(.copy, page: 2)

        await readerEventually { model.notice == .copiedToClipboard }
        #expect(harness.requestedImages.value == [harness.site.image(2)])
        #expect(harness.copied.value == [ReaderModelHarness.imageData(for: harness.site.image(2))])
    }

    @Test func saveAndSaveOriginalUseTheirOwnURLs() async throws {
        let harness = try ReaderModelHarness()
        let model = await modelWithPage2(harness)

        model.perform(.save, page: 2)
        await readerEventually { model.notice == .savedToPhotoLibrary }
        model.notice = nil
        model.perform(.saveOriginal, page: 2)
        await readerEventually { model.notice == .savedToPhotoLibrary }

        #expect(harness.saved.value == [
            ReaderModelHarness.imageData(for: harness.site.image(2)),
            ReaderModelHarness.imageData(for: harness.site.original(2))
        ])
    }

    @Test func aRefusedSaveAndMissingBytesShowAnError() async throws {
        let harness = try ReaderModelHarness()
        let model = await modelWithPage2(harness)

        harness.savesSucceed.setValue(false)
        model.perform(.save, page: 2)
        await readerEventually { model.notice == .error }
        #expect(harness.saved.value.isEmpty)

        model.notice = nil
        harness.imageDataFails.setValue(true)
        model.perform(.copy, page: 2)
        await readerEventually { model.notice == .error }
        #expect(harness.copied.value.isEmpty)
    }

    @Test func shareWritesTheBytesToAFileAndPresentsIt() async throws {
        let harness = try ReaderModelHarness()
        let model = await modelWithPage2(harness)
        model.setAutoPlay(.oneSecond)

        model.perform(.share, page: 2)

        await readerEventually { model.destination != nil }
        guard case .share(let file) = model.destination else {
            Issue.record("Expected the share sheet")
            return
        }
        #expect(file.lastPathComponent == "\(harness.gid)-2.png")
        #expect(try Data(contentsOf: file) == ReaderModelHarness.imageData(for: harness.site.image(2)))
        #expect(model.autoPlay == .off)

        // The file does not outlive the reader.
        model.close()
        await readerEventually { !FileManager.default.fileExists(atPath: file.path) }
    }

    @Test func actionsOnAPageWithoutAnImageDoNothing() async throws {
        let harness = try ReaderModelHarness()
        let model = await harness.startedModel()

        model.perform(.copy, page: 9)
        model.perform(.share, page: 9)

        await readerSettle()
        #expect(harness.requestedImages.value.isEmpty)
        #expect(model.notice == nil)
        #expect(model.destination == nil)
    }

    @Test func reloadFetchesThePageThroughAnotherServer() async throws {
        let harness = try ReaderModelHarness()
        let model = await modelWithPage2(harness)
        harness.clearEngineLog()

        model.perform(.reload, page: 2)

        #expect(model.pageState(at: 2) == .pending)
        await readerEventually { model.pageState(at: 2) == .image(harness.site.reloadedImage(2)) }
        #expect(harness.engineLog == ["reload:2", "reload:2"])
        #expect(harness.site.started.last == "reload:2")

        // On a page that has no image yet, "Reload" resolves it (legacy did nothing).
        model.perform(.reload, page: 8)
        await readerEventually { model.pageState(at: 8) == .image(harness.site.image(8)) }
    }

    @Test func shareFileNamesFollowTheImageType() {
        #expect(ReaderShareFile.fileExtension(for: Data([0xFF, 0xD8, 0xFF, 0xE0, 0, 0])) == "jpg")
        #expect(ReaderShareFile.fileExtension(for: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])) == "png")
        #expect(ReaderShareFile.fileExtension(for: Data("GIF89a....".utf8)) == "gif")
        #expect(ReaderShareFile.fileExtension(for: Data("RIFF\u{1}\u{2}\u{3}\u{4}WEBPVP8 ".utf8)) == "webp")
        #expect(ReaderShareFile.fileExtension(for: Data("RIFF\u{1}\u{2}\u{3}\u{4}WAVEfmt ".utf8)) == "jpg")
        #expect(ReaderShareFile.fileExtension(for: Data()) == "jpg")
    }
}

@Suite struct ReaderModelOrientationTests {
    @Test func landscapeIsUnlockedWhileReadingAndPortraitRestoredOnClose() async throws {
        let harness = try ReaderModelHarness()
        harness.settings.enablesLandscape = true

        let model = await harness.startedModel()
        #expect(harness.orientationLocks == [.unlocked])
        #expect(model.showsLandscapeSetting)

        // The setting applies at once while reading.
        model.enablesLandscapeDidChange(false)
        model.enablesLandscapeDidChange(true)
        #expect(harness.orientationLocks == [.unlocked, .portrait, .unlocked])

        model.close()
        #expect(harness.orientationLocks.last == .portrait)
        #expect(harness.orientationLocks.count == 4)
        // Nothing after the reader has closed.
        model.enablesLandscapeDidChange(true)
        #expect(harness.orientationLocks.count == 4)
    }

    @Test func theIPadIsNeverLockedToPortrait() async throws {
        let harness = try ReaderModelHarness()
        harness.isPad = true
        harness.settings.enablesLandscape = true

        let model = await harness.startedModel()
        model.enablesLandscapeDidChange(false)
        model.close()

        #expect(harness.orientationLocks == [.unlocked])
        #expect(!model.showsLandscapeSetting)
    }
}
