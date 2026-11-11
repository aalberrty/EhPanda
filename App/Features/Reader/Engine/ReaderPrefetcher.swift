import EhFeatures
import UIKit

/// Keeps the pages around the visible ones warm.
///
/// It tells the host which pages moved into and out of reach (so it can resolve their URLs),
/// and downloads the image data of in-reach pages whose URL is known, a few at a time and
/// nearest first. Pages that have a view load their own image and are skipped here. Nothing is
/// decoded: the data goes to disk, and only the image's size is read from it, which lets the
/// vertical strip give a page its real height before it scrolls into view.
final class ReaderPrefetcher {
    var pageState: (Int) -> ReaderPageState = { _ in .pending }
    var onNeedPages: ([Int]) -> Void = { _ in }
    var onReleasePages: ([Int]) -> Void = { _ in }
    var onPixelSize: (Int, CGSize) -> Void = { _, _ in }

    private static let maximumConcurrentDownloads = 3

    private var window: ClosedRange<Int>?
    /// The window's pages, most urgent first.
    private var queue: [Int] = []
    private var loadedPages: ClosedRange<Int>?
    private var running: [Int: (url: URL, task: Task<Void, Never>)] = [:]
    /// Pages whose data for this URL was fetched (or failed), so they are not tried again.
    private var finished: [Int: URL] = [:]

    deinit {
        for entry in running.values {
            entry.task.cancel()
        }
    }

    /// Moves the window to follow the visible pages.
    func update(visible: ClosedRange<Int>?, loaded: ClosedRange<Int>?, pageCount: Int, limit: Int) {
        loadedPages = loaded
        let newWindow = visible.flatMap {
            ReaderPrefetchWindow.range(visible: $0, pageCount: pageCount, limit: limit)
        }
        if let newWindow, let visible {
            queue = ReaderPrefetchWindow.prioritized(newWindow, around: visible)
        } else {
            queue = []
        }
        if newWindow != window {
            let changes = ReaderPrefetchWindow.changes(from: window, to: newWindow)
            window = newWindow
            for page in changes.removed {
                cancel(page)
                finished[page] = nil
            }
            if !changes.removed.isEmpty {
                onReleasePages(changes.removed)
            }
            if !changes.added.isEmpty {
                let added = Set(changes.added)
                onNeedPages(queue.filter(added.contains))
            }
        }
        schedule()
    }

    /// A page's state may have changed: forget what was fetched for its old URL.
    func pageDidChange(_ page: Int) {
        var currentURL: URL?
        if case .image(let url) = pageState(page) {
            currentURL = url
        }
        if running[page]?.url != currentURL {
            cancel(page)
        }
        if finished[page] != currentURL {
            finished[page] = nil
        }
        schedule()
    }

    /// Cancels everything and forgets the window; the next `update` announces it afresh.
    func reset() {
        for page in Array(running.keys) {
            cancel(page)
        }
        finished = [:]
        queue = []
        if let window {
            self.window = nil
            onReleasePages(Array(window))
        }
    }

    private func schedule() {
        for page in queue {
            guard running.count < Self.maximumConcurrentDownloads else { return }
            if loadedPages?.contains(page) == true { continue }
            guard case .image(let url) = pageState(page), finished[page] != url, running[page] == nil else {
                continue
            }
            start(page, url: url)
        }
    }

    private func start(_ page: Int, url: URL) {
        let task = Task { [weak self] in
            let pixelSize = try? await ImagePipeline.prefetch(url)
            guard !Task.isCancelled else { return }
            self?.finish(page, url: url, pixelSize: pixelSize)
        }
        running[page] = (url, task)
    }

    private func finish(_ page: Int, url: URL, pixelSize: CGSize?) {
        guard running[page]?.url == url else { return }
        running[page] = nil
        finished[page] = url
        if let pixelSize {
            onPixelSize(page, pixelSize)
        }
        schedule()
    }

    private func cancel(_ page: Int) {
        running.removeValue(forKey: page)?.task.cancel()
    }
}
