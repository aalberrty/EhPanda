import Dependencies
import EhCore
import EhModels
import EhNetworking
import Foundation
import Observation

/// Opens gallery links from outside the app: `ehpanda://` URLs (the share extension rewrites
/// shared links to that scheme) and links found on the clipboard (legacy `AppRouteReducer`).
///
/// A link is resolved to its gallery, from the history when it was opened before, otherwise from
/// the site behind a loading HUD, and the gallery is presented in the shell's gallery sheet. A
/// link to an image page also opens the reader at that page; a link to a comment opens the
/// comments (see `GalleryLinkTarget`).
@Observable
public final class DeepLinkModel {
    /// The HUD shown while a link is resolved.
    public enum Progress: Equatable, Sendable {
        case loading
        /// Resolving failed. The HUD dismisses itself and sets `progress` back to `nil`.
        case failed
    }

    /// One link to handle. A new request cancels the one in progress.
    public struct Request: Equatable, Sendable {
        let id: Int
        let url: URL
    }

    public var progress: Progress?
    /// The link waiting to be handled. The shell runs `handleRequest()` in `.task(id:)` on it, so
    /// a newer link cancels the previous one and links that arrive during launch wait until the
    /// tabs exist.
    public private(set) var request: Request?

    /// Set once the database is installed. Until then requests wait: resolving a link reads
    /// the history.
    @ObservationIgnored var isAcceptingLinks = false

    private let router: AppRouter
    @ObservationIgnored private var requestCount = 0

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.database) private var database
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.clipboardClient) private var clipboard
    @ObservationIgnored @Dependency(\.clipboardChangeCountStore) private var clipboardChangeCount
    @ObservationIgnored @Dependency(\.continuousClock) private var clock
    @ObservationIgnored @Dependency(\.appLogger) private var logger

    init(router: AppRouter) {
        self.router = router
    }

    /// Queues `url`; links the app cannot open are ignored when handled.
    public func open(_ url: URL) {
        requestCount += 1
        request = Request(id: requestCount, url: url)
    }

    public func handleRequest() async {
        guard isAcceptingLinks, let request else { return }
        await handle(request.url)
        if self.request == request {
            self.request = nil
        }
    }

    /// When "Detects links from clipboard" is on and the pasteboard changed since the last
    /// check, opens the link on it. The same contents are therefore offered only once.
    func checkClipboard() {
        guard settings.detectsLinksFromClipboard else { return }
        let changeCount = clipboard.changeCount()
        guard changeCount != clipboardChangeCount.load() else { return }
        clipboardChangeCount.save(changeCount)
        if let url = clipboard.url() {
            open(url)
        }
    }

    func handle(_ link: URL) async {
        let link = EhURL.resolvingAppScheme(link)
        guard EhURL.isHandleable(link), let gid = EhURL.galleryID(of: link) else { return }
        let url = LinkRedirection(settings: settings).redirect(link)
        if router.presentedGallery != nil {
            // Let the current sheet finish dismissing before presenting the next one.
            router.dismissPresentedGallery()
            do {
                try await clock.sleep(for: .seconds(1))
            } catch {
                return
            }
        }
        guard let gallery = await resolve(url, gid: gid) else { return }

        let analysis = EhURL.analyze(url)
        if let page = analysis.pageIndex {
            do {
                try await database.updateReadingProgress(gid: gid, progress: page)
            } catch {
                logger.warning("Saving the linked page failed: \(error)", category: Self.logCategory)
            }
        }
        guard !Task.isCancelled else { return }
        let target: GalleryLinkTarget? = if let page = analysis.pageIndex {
            .page(page)
        } else if let commentID = analysis.commentID {
            .comment(commentID)
        } else {
            nil
        }
        router.present(gallery, target: target)
    }

    /// The gallery from the history, or else from the site with the loading HUD.
    private func resolve(_ url: URL, gid: String) async -> Gallery? {
        if let stored = try? await database.gallery(gid: gid) {
            return LinkRedirection(settings: settings).redirect(stored)
        }
        guard !Task.isCancelled else { return nil }
        progress = .loading
        do {
            let gallery = try await client.gallery(from: url)
            progress = nil
            return gallery
        } catch is CancellationError {
            progress = nil
        } catch {
            // Legacy cleared the HUD before switching it to the error style, so the error never
            // showed; it is shown here.
            logger.info("Opening a gallery link failed: \(error)", category: Self.logCategory)
            progress = .failed
        }
        return nil
    }

    nonisolated static let logCategory = "DeepLink"
}
