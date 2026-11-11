import ConcurrencyExtras
import Dependencies
@testable import EhCore
import EhDatabase
@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

@MainActor @Suite struct DeepLinkModelTests {
    private let transport = StubTransport()
    private let settings = SettingsStore(storage: .ephemeral())
    private let router = AppRouter()
    private let changeCounts = ClipboardChangeCountStore.inMemory()

    private func makeModel(
        database: AppDatabase? = nil, clipboard: ClipboardClient = AppFixture.clipboard()
    ) async throws -> (DeepLinkModel, AppDatabase) {
        let database = if let database { database } else { try await AppDatabase.inMemory() }
        let model = withDependencies {
            $0.ehClient = AppFixture.client(transport)
            $0.database = database
            $0.settings = settings
            $0.clipboardClient = clipboard
            $0.clipboardChangeCountStore = changeCounts
            $0.continuousClock = ShellInstantClock()
        } operation: {
            DeepLinkModel(router: router)
        }
        model.isAcceptingLinks = true
        return (model, database)
    }

    private func open(_ link: String, in model: DeepLinkModel) async {
        model.open(URL(string: link)!)
        await model.handleRequest()
    }

    private var requestedURLs: [String] {
        transport.requests.compactMap { $0.url?.absoluteString }
    }

    // MARK: Link kinds

    @Test func galleryLinkLoadsAndPresentsTheGallery() async throws {
        let (model, _) = try await makeModel()
        let progressDuringLoad = LockIsolated<DeepLinkModel.Progress?>(nil)
        transport.on(.path("/g/3103480/0000000000/"), reply: .handler { request in
            let progress = await MainActor.run { model.progress }
            progressDuringLoad.setValue(progress)
            return try await StubTransport.Reply.fixture(AppFixture.detailPage).response(for: request)
        })

        await open("https://e-hentai.org/g/3103480/0000000000/", in: model)

        #expect(progressDuringLoad.value == .loading)
        #expect(model.progress == nil)
        #expect(router.presentedGallery?.gid == "3103480")
        #expect(router.presentedGalleryTarget == nil)
        #expect(model.request == nil)
    }

    @Test func appSchemeLinkIsOpened() async throws {
        let (model, _) = try await makeModel()
        transport.on(.any, reply: .fixture(AppFixture.detailPage))

        await open("ehpanda://e-hentai.org/g/3103480/0000000000/", in: model)

        #expect(requestedURLs == ["https://e-hentai.org/g/3103480/0000000000/"])
        #expect(router.presentedGallery?.gid == "3103480")
    }

    @Test func imagePageLinkStoresThePageAndOpensTheReader() async throws {
        let (model, database) = try await makeModel()
        transport.on(.path("/s/abc123/0000000-3"), reply: .fixture(AppFixture.imagePage))
        transport.on(.path("/g/0000000/898683e1d1/"), reply: .fixture(AppFixture.detailPage))

        await open("https://e-hentai.org/s/abc123/0000000-3", in: model)

        #expect(router.presentedGallery?.gid == "0000000")
        #expect(router.presentedGalleryTarget == .page(3))
        #expect(try await database.state(gid: "0000000")?.readingProgress == 3)
    }

    @Test func commentLinkOpensTheComments() async throws {
        let (model, _) = try await makeModel()
        transport.on(.any, reply: .fixture(AppFixture.detailPage))

        await open("https://e-hentai.org/g/3103480/0000000000/#c4242", in: model)

        #expect(router.presentedGallery?.gid == "3103480")
        #expect(router.presentedGalleryTarget == .comment("4242"))
    }

    @Test func galleryInTheHistoryOpensWithoutLoading() async throws {
        let database = try await AppDatabase.inMemory()
        try await database.recordOpened(AppFixture.gallery())
        let (model, _) = try await makeModel(database: database)

        await open("https://e-hentai.org/g/3103480/0000000000/", in: model)

        #expect(transport.requests.isEmpty)
        #expect(router.presentedGallery?.title == "Stored")
    }

    @Test func linksTheAppCannotOpenAreIgnored() async throws {
        let (model, _) = try await makeModel()

        await open("https://example.com/g/1/abc/", in: model)
        await open("https://e-hentai.org/tag/female:glasses", in: model)

        #expect(transport.requests.isEmpty)
        #expect(router.presentedGallery == nil)
    }

    // MARK: Host rewriting

    @Test func redirectOnLoadsFromTheSelectedHost() async throws {
        settings.galleryHost = .ehentai
        settings.redirectsLinksToSelectedHost = true
        let (model, _) = try await makeModel()
        transport.on(.any, reply: .fixture(AppFixture.detailPage))

        await open("https://exhentai.org/g/3103480/0000000000/", in: model)

        #expect(requestedURLs == ["https://e-hentai.org/g/3103480/0000000000/"])
        #expect(router.presentedGallery?.galleryURL?.host() == "e-hentai.org")
    }

    @Test func redirectOffLoadsFromTheLinkedHost() async throws {
        settings.galleryHost = .ehentai
        settings.redirectsLinksToSelectedHost = false
        let (model, _) = try await makeModel()
        transport.on(.any, reply: .fixture(AppFixture.detailPage))

        await open("https://exhentai.org/g/3103480/0000000000/", in: model)

        #expect(requestedURLs == ["https://exhentai.org/g/3103480/0000000000/"])
    }

    @Test func redirectAlsoAppliesToAGalleryFromTheHistory() async throws {
        settings.galleryHost = .exhentai
        settings.redirectsLinksToSelectedHost = true
        let database = try await AppDatabase.inMemory()
        try await database.recordOpened(AppFixture.gallery())
        let (model, _) = try await makeModel(database: database)

        await open("https://e-hentai.org/g/3103480/0000000000/", in: model)

        #expect(transport.requests.isEmpty)
        #expect(router.presentedGallery?.galleryURL?.absoluteString == "https://exhentai.org/g/3103480/0000000000/")
    }

    @Test func redirectingKeepsLinksOnTheSelectedHost() {
        let url = URL(string: "https://e-hentai.org/s/abc/1-2")!

        #expect(DeepLinkModel.redirecting(url, to: .ehentai) == url)
        #expect(DeepLinkModel.redirecting(url, to: .exhentai).absoluteString == "https://exhentai.org/s/abc/1-2")
    }

    // MARK: Failure and replacement

    @Test func failureShowsTheErrorHUD() async throws {
        let (model, _) = try await makeModel()
        transport.on(.any, reply: .error(URLError(.notConnectedToInternet)))

        await open("https://e-hentai.org/g/3103480/0000000000/", in: model)

        #expect(model.progress == .failed)
        #expect(router.presentedGallery == nil)
    }

    @Test func anOpenGalleryIsDismissedBeforeTheNextOne() async throws {
        let database = try await AppDatabase.inMemory()
        try await database.recordOpened(AppFixture.gallery())
        let (model, _) = try await makeModel(database: database)
        router.present(AppFixture.gallery(gid: "1"), target: .page(2))
        router.presented.push(.galleryList(.popular))

        await open("https://e-hentai.org/g/3103480/0000000000/", in: model)

        #expect(router.presentedGallery?.gid == "3103480")
        #expect(router.presentedGalleryTarget == nil)
        #expect(router.presented.isAtRoot)
    }

    @Test func newerLinkCancelsTheOneInProgress() async throws {
        let (model, _) = try await makeModel()
        transport.on(.path("/g/1/aaaaaaaaaa/"), reply: .suspendUntilCancelled)
        transport.on(.path("/g/3103480/0000000000/"), reply: .fixture(AppFixture.detailPage))

        model.open(URL(string: "https://e-hentai.org/g/1/aaaaaaaaaa/")!)
        let first = Task { await model.handleRequest() }
        await shellWaitUntil { transport.requests.count == 1 }
        #expect(model.progress == .loading)
        first.cancel()
        await first.value
        #expect(model.progress == nil)

        await open("https://e-hentai.org/g/3103480/0000000000/", in: model)
        #expect(router.presentedGallery?.gid == "3103480")
    }

    // MARK: Clipboard

    @Test func clipboardLinkIsOpenedOncePerChange() async throws {
        settings.detectsLinksFromClipboard = true
        let link = URL(string: "https://e-hentai.org/g/3103480/0000000000/")!
        let (model, _) = try await makeModel(clipboard: AppFixture.clipboard(changeCount: 8, url: link))
        changeCounts.save(7)

        model.checkClipboard()
        #expect(model.request?.url == link)
        #expect(changeCounts.load() == 8)

        let request = model.request
        model.checkClipboard()
        #expect(model.request == request)
    }

    @Test func clipboardIsNotReadWhenDetectionIsOff() async throws {
        let clipboard = ClipboardClient(
            changeCount: { Issue.record("Read the clipboard"); return 1 },
            url: { Issue.record("Read the clipboard"); return nil },
            copyText: { _ in }, copyImage: { _ in }
        )
        let (model, _) = try await makeModel(clipboard: clipboard)

        model.checkClipboard()

        #expect(model.request == nil)
    }

    @Test func changedClipboardWithoutALinkIsRemembered() async throws {
        settings.detectsLinksFromClipboard = true
        let (model, _) = try await makeModel(clipboard: AppFixture.clipboard(changeCount: 2, url: nil))

        model.checkClipboard()

        #expect(model.request == nil)
        #expect(changeCounts.load() == 2)
    }
}

private extension StubTransport.Reply {
    func response(for request: URLRequest) async throws -> HTTPResponse {
        let transport = StubTransport()
        transport.on(.any, reply: self)
        return try await transport.send(request)
    }
}
