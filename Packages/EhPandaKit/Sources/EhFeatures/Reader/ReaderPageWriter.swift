import EhCore
import EhDatabase
import Foundation

/// Saves what the reader learns about a gallery: page links, image URLs, image sizes, slider
/// previews and the reading progress.
///
/// Page changes are collected and written in one transaction per burst instead of one per
/// page, and the progress is written once the reader has rested on a page instead of on every
/// page turn. Every write goes through one queue, so writes reach the database in the order
/// they were made (a "reload all" delete can never be overtaken by an older save), and the
/// queue's tasks do not belong to the reader's view, so the last save still completes after
/// the reader has closed.
final class ReaderPageWriter {
    /// How long page changes are collected before they are written.
    static let pageDelay: Duration = .milliseconds(500)
    /// How long the reader has to stay on a page before its progress is written.
    static let progressDelay: Duration = .milliseconds(500)

    private let gid: String
    private let database: AppDatabase
    private let clock: any Clock<Duration>
    private let logger: AppLogger

    private var pendingPages: [Int: GalleryPage] = [:]
    private var pageTimer: Task<Void, Never>?
    private var pendingProgress: Int?
    private var progressTimer: Task<Void, Never>?
    private var lastWrite: Task<Void, Never>?
    /// Database transactions made so far. Tests read it to see that changes are batched.
    private(set) var writeCount = 0

    init(gid: String, database: AppDatabase, clock: any Clock<Duration>, logger: AppLogger) {
        self.gid = gid
        self.database = database
        self.clock = clock
        self.logger = logger
    }

    /// Queues the non-`nil` fields of `page` for the next write.
    func add(_ page: GalleryPage) {
        pendingPages[page.index] = pendingPages[page.index].map { $0.merging(page) } ?? page
        guard pageTimer == nil else { return }
        // Timed from the first change of a burst, so a long burst still writes regularly.
        pageTimer = Task { [weak self, clock] in
            do {
                try await clock.sleep(for: Self.pageDelay)
            } catch {
                return
            }
            self?.flushPages()
        }
    }

    /// Writes `progress` once it has stayed the latest value for `progressDelay`.
    func setProgress(_ progress: Int) {
        pendingProgress = progress
        progressTimer?.cancel()
        progressTimer = Task { [weak self, clock] in
            do {
                try await clock.sleep(for: Self.progressDelay)
            } catch {
                return
            }
            self?.flushProgress()
        }
    }

    /// Writes everything that is waiting, now.
    func flush() {
        flushPages()
        flushProgress()
    }

    /// Forgets page changes that were not written yet and deletes the gallery's stored pages
    /// (legacy `removeImageURLs(gid:)`).
    func deletePages() {
        pageTimer?.cancel()
        pageTimer = nil
        pendingPages = [:]
        enqueue { [gid, database] in try await database.deletePages(gid: gid) }
    }

    /// Returns when every write made so far has finished.
    func waitUntilWritten() async {
        while let write = lastWrite {
            await write.value
            if lastWrite == write { return }
        }
    }

    private func flushPages() {
        pageTimer?.cancel()
        pageTimer = nil
        guard !pendingPages.isEmpty else { return }
        let pages = pendingPages.values.sorted { $0.index < $1.index }
        pendingPages = [:]
        enqueue { [database] in try await database.upsertPages(pages) }
    }

    private func flushProgress() {
        progressTimer?.cancel()
        progressTimer = nil
        guard let progress = pendingProgress else { return }
        pendingProgress = nil
        enqueue { [gid, database] in try await database.updateReadingProgress(gid: gid, progress: progress) }
    }

    private func enqueue(_ write: @escaping @Sendable () async throws -> Void) {
        let previous = lastWrite
        let logger = logger
        writeCount += 1
        lastWrite = Task {
            await previous?.value
            do {
                try await write()
            } catch {
                logger.error("Saving reader state failed: \(error)", category: "Reader")
            }
        }
    }
}

nonisolated private extension GalleryPage {
    /// This page with the non-`nil` fields of `newer` on top, which is how the database merges.
    func merging(_ newer: GalleryPage) -> GalleryPage {
        var page = self
        page.pageURL = newer.pageURL ?? pageURL
        page.imageURL = newer.imageURL ?? imageURL
        page.originalImageURL = newer.originalImageURL ?? originalImageURL
        page.previewURL = newer.previewURL ?? previewURL
        page.imageWidth = newer.imageWidth ?? imageWidth
        page.imageHeight = newer.imageHeight ?? imageHeight
        return page
    }
}
