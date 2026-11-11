import Dependencies
import EhCore
import EhModels
import EhNetworking
import Foundation
import Observation

/// The archives sheet: the Hentai@Home download options and the account's funds.
///
/// Funds are written to `UserStore`, the only copy of the user, and the sheet reads them from
/// there; legacy wrote them to storage behind its in-memory user, which later overwrote them.
@Observable
public final class ArchivesModel {
    public let gallery: Gallery
    public let archiveURL: URL

    public private(set) var archives: [GalleryArchive.HathArchive] = []
    public private(set) var loadingState: LoadingState = .idle
    public private(set) var selection: ArchiveResolution?
    /// Counts selections, for the view's haptic.
    public private(set) var selectionCount = 0
    public private(set) var download: DownloadState?
    /// The last download command's result, for the view's haptic.
    public private(set) var feedback: OperationFeedback?

    public enum DownloadState: Equatable, Sendable {
        case communicating
        case finished(DownloadResult)
    }

    /// The server's answer to a download command. The three errors are recognised by the
    /// site's English messages; any other message means the client accepted the command.
    public enum DownloadResult: Equatable, Sendable {
        case success(message: String)
        case hathClientNotFound
        case hathClientNotOnline
        case invalidResolution
        case failed(AppError)

        public var isSuccess: Bool {
            if case .success = self { true } else { false }
        }
    }

    @ObservationIgnored private var feedbackCounter = FeedbackCounter()
    @ObservationIgnored private let tasks = ModelTasks()

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.userStore) private var userStore

    public init(gallery: Gallery, archiveURL: URL) {
        self.gallery = gallery
        self.archiveURL = archiveURL
    }

    // MARK: Loading

    /// Fetches the archive page; call from the sheet's `.task`.
    ///
    /// The page usually shows the funds. When it does not and both sites are logged in with the
    /// same account, they are read through E-Hentai instead (legacy `fetchArchiveFunds`).
    public func load() async {
        guard !loadingState.isLoading else { return }
        loadingState = .loading
        let client = client
        let archiveURL = archiveURL
        let outcome = await Outcome.of { try await client.archive(archiveURL: archiveURL) }
        switch outcome {
        case .cancelled:
            loadingState = .idle
        case .failure(let error):
            loadingState = .failed(error)
        case .success(let info) where info.archive.hathArchives.isEmpty:
            loadingState = .failed(.notFound)
        case .success(let info):
            archives = info.archive.hathArchives
            loadingState = .idle
            if let funds = info.funds {
                userStore.updateGalleryFunds(galleryPoints: funds.galleryPoints, credits: funds.credits)
            } else if client.cookies.isSameAccount, let galleryURL = gallery.galleryURL {
                await loadFunds(galleryURL: galleryURL)
            }
        }
    }

    public func retry() {
        tasks.run("load") { [weak self] in await self?.load() }
    }

    private func loadFunds(galleryURL: URL) async {
        let client = client
        let outcome = await Outcome.of { try await client.archiveFunds(galleryURL: galleryURL) }
        if case .success(let funds) = outcome {
            userStore.updateGalleryFunds(galleryPoints: funds.galleryPoints, credits: funds.credits)
        }
    }

    // MARK: Download

    /// Options the site marks unavailable cannot be selected.
    public func select(_ archive: GalleryArchive.HathArchive) {
        guard archive.isValid else { return }
        selection = archive.resolution
        selectionCount += 1
    }

    /// Asks the user's H@H client to download the selected archive.
    public func sendDownloadCommand() {
        guard let resolution = selection, download != .communicating else { return }
        download = .communicating
        let client = client
        let archiveURL = archiveURL
        tasks.run("download") { [weak self] in
            let outcome = await Outcome.of {
                try await client.sendDownloadCommand(archiveURL: archiveURL, resolution: resolution)
            }
            self?.finishDownload(outcome)
        }
    }

    /// Called when the result HUD hides itself.
    public func dismissDownloadResult() {
        if case .finished = download {
            download = nil
        }
    }

    private func finishDownload(_ outcome: Outcome<String>) {
        let result: DownloadResult
        switch outcome {
        case .cancelled:
            download = nil
            return
        case .failure(let error):
            result = .failed(error)
        case .success(let message):
            result = Self.result(for: message)
        }
        download = .finished(result)
        feedback = feedbackCounter.next(result.isSuccess ? .success : .failure)
    }

    /// The site's messages, as in legacy `Constant.strings` (`website.response.*`).
    static func result(for message: String) -> DownloadResult {
        switch message {
        case "You must have a H@H client assigned to your account to use this feature.":
            .hathClientNotFound
        case "Your H@H client appears to be offline. Turn it on, then try again.":
            .hathClientNotOnline
        case "The requested gallery cannot be downloaded with the selected resolution.":
            .invalidResolution
        default:
            .success(message: message)
        }
    }
}
