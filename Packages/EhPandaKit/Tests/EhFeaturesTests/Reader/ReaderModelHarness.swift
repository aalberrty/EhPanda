import Dependencies
import EhCore
import EhDatabase
@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation

/// A `ReaderModel` on a `ReaderTestSite`, an in-memory database and a clock the test moves,
/// with fakes that record what the model asks of the engine and of the system.
final class ReaderModelHarness {
    let site: ReaderTestSite
    let database: AppDatabase
    let clock = TestClock()
    let settings = SettingsStore(defaults: UserDefaults(suiteName: "ReaderTests-\(UUID().uuidString)")!)

    /// Engine commands in order: `reload:<page>`, `reloadData`, `scroll:<page>`, `advance`.
    private(set) var engineLog: [String] = []
    /// What `advance` answers; `false` is the end of the gallery.
    var canAdvance = true
    var isPad = false
    private(set) var orientationLocks: [OrientationLock] = []

    let copied = LockIsolated<[Data]>([])
    let saved = LockIsolated<[Data]>([])
    let requestedImages = LockIsolated<[URL]>([])
    /// Whether the photo library accepts a save.
    let savesSucceed = LockIsolated(true)
    /// Whether the image cache can produce bytes.
    let imageDataFails = LockIsolated(false)
    /// The logger of the models made from now on; the test default when nil.
    var logger: AppLogger?

    /// - Parameter database: The database another feature's model already wrote to; a new,
    ///   empty one by default.
    init(site: ReaderTestSite = ReaderTestSite(), database: AppDatabase? = nil) throws {
        self.site = site
        self.database = try database ?? AppDatabase.makeInMemory()
    }

    var gid: String { site.gid }

    /// The bytes the fake image cache returns for a URL: a PNG signature followed by the URL.
    nonisolated static func imageData(for url: URL) -> Data {
        Data([0x89, 0x50, 0x4E, 0x47]) + Data(url.absoluteString.utf8)
    }

    func makeModel(initialPage: Int? = nil, gallery: Gallery? = nil, detail: GalleryDetail? = nil) -> ReaderModel {
        let model = withDependencies {
            $0.ehClient = site.client
            $0.database = database
            $0.continuousClock = clock
            $0.settings = settings
            $0.applicationClient = applicationClient
            if let logger {
                $0.appLogger = logger
            }
            $0.clipboardClient.copyImage = { [copied] data in copied.withValue { $0.append(data) } }
            $0.photoLibraryClient.saveImage = { [saved, savesSucceed] data in
                guard savesSucceed.value else { return false }
                saved.withValue { $0.append(data) }
                return true
            }
            $0.imageCacheClient.imageData = { [requestedImages, imageDataFails] url in
                requestedImages.withValue { $0.append(url) }
                if imageDataFails.value { throw URLError(.notConnectedToInternet) }
                return Self.imageData(for: url)
            }
        } operation: {
            ReaderModel(gallery: gallery ?? site.gallery, initialPage: initialPage, detail: detail)
        }
        model.engine = ReaderEngineCommands(
            reloadPage: { [weak self] in self?.engineLog.append("reload:\($0)") },
            reloadData: { [weak self] in self?.engineLog.append("reloadData") },
            scrollToPage: { [weak self] in self?.engineLog.append("scroll:\($0)") },
            advance: { [weak self] in
                self?.engineLog.append("advance")
                return self?.canAdvance ?? false
            }
        )
        return model
    }

    private var applicationClient: ApplicationClient {
        ApplicationClient(
            isPad: { [weak self] in self?.isPad ?? false },
            openURL: { _ in false },
            openSettings: {},
            alternateIconName: { nil },
            setAlternateIconName: { _ in false },
            setOrientationLock: { [weak self] in self?.orientationLocks.append($0) }
        )
    }

    /// A started model, the way the screen has one once its `.task` ran.
    func startedModel(initialPage: Int? = nil) async -> ReaderModel {
        let model = makeModel(initialPage: initialPage)
        await model.start()
        return model
    }

    func engineCount(_ command: String) -> Int {
        engineLog.count { $0 == command }
    }

    func clearEngineLog() {
        engineLog = []
    }

    // MARK: Database

    func storedPages() async throws -> [Int: GalleryPage] {
        let pages = try await database.pages(gid: gid)
        return Dictionary(uniqueKeysWithValues: pages.map { ($0.index, $0) })
    }

    /// Stores a detail page of the gallery that showed this preview layout.
    func storeDetail(previewConfig: PreviewConfig, jpnTitle: String? = nil) async throws {
        let detail = GalleryDetail(
            gid: gid, title: "Title", jpnTitle: jpnTitle, isFavorited: false, visibility: .yes, rating: 4, userRating: 0,
            ratingCount: 1, category: .doujinshi, language: .japanese, uploader: "Uploader",
            postedDate: Date(timeIntervalSince1970: 0), coverURL: nil, favoritedCount: 0,
            pageCount: site.pageCount, sizeCount: 1, sizeType: "MiB", torrentCount: 0
        )
        try await database.saveDetail(detail, state: GalleryState(gid: gid, previewConfig: previewConfig))
    }

    func storedProgress() async throws -> Int? {
        try await database.state(gid: gid)?.readingProgress
    }

    /// Lets the writer's timer run out and waits for the write.
    func flushWrites(of model: ReaderModel) async {
        await clock.advance(by: ReaderPageWriter.pageDelay)
        await model.waitUntilSaved()
    }
}
