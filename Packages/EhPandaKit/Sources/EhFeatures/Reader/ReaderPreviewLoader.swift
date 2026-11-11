import EhModels
import EhNetworking
import Foundation

/// Fetches the preview pages of the reader's gallery: one request per preview page, shared by
/// everyone who asks for it while it runs.
///
/// Two parts of the reader read preview pages. The page resolver needs the viewer links of
/// the pages around the reading position, the slider's strip the thumbnails of the pages
/// around its thumb. A preview page lists both, so both ask here, and every fetched page goes
/// to `onLoad` once, whoever asked for it: the reader keeps both halves and the other part
/// never has to ask for the same page.
///
/// Legacy fetched the thumbnails from the strip's cells, but only built the cells when some
/// preview was already known, so on a gallery without stored previews the strip never appeared.
final class ReaderPreviewLoader {
    /// Called once with every preview page that was fetched, before whoever waits for it
    /// continues.
    var onLoad: ((_ listed: PreviewPage, _ previewPage: Int) -> Void)?

    private struct Fetch {
        let id: Int
        let task: Task<PreviewPage, any Error>
        /// Callers of `page(_:)` that have not been cancelled.
        var waiters = 0
        /// The strip asked for it. The strip never takes a request back.
        var isForStrip = false
    }

    private let galleryURL: URL?
    private let client: EhClient
    private var fetches: [Int: Fetch] = [:]
    private var lastFetchID = 0
    private var loaded: Set<Int> = []
    private var failed: Set<Int> = []

    init(galleryURL: URL?, client: EhClient) {
        self.galleryURL = galleryURL
        self.client = client
    }

    /// The preview page `number`, from the request that is already running for it if there is
    /// one. Cancelling the caller leaves that request to the others waiting for it, and cancels
    /// it when there are none.
    func page(_ number: Int) async throws -> PreviewPage {
        guard let fetch = fetch(number) else { throw AppError.notFound }
        fetches[number]?.waiters += 1
        let id = fetch.id
        return try await withTaskCancellationHandler {
            try await fetch.task.value
        } onCancel: {
            Task { @MainActor [weak self] in self?.leave(number, fetch: id) }
        }
    }

    /// Loads a preview page for the strip unless it is loading or was loaded. A preview page
    /// that failed is left alone until `retryFailed()`, so dragging the slider does not ask
    /// again and again.
    func load(previewPage number: Int) {
        guard !loaded.contains(number), !failed.contains(number), fetch(number) != nil else { return }
        fetches[number]?.isForStrip = true
    }

    func retryFailed() {
        failed = []
    }

    /// Cancels what is loading, for when the reader closes.
    func stop() {
        for fetch in fetches.values {
            fetch.task.cancel()
        }
        fetches = [:]
    }

    /// Forgets everything, for "reload all images".
    func reset() {
        stop()
        loaded = []
        failed = []
    }

    // MARK: Private

    /// The request for a preview page, started if none is running.
    private func fetch(_ number: Int) -> Fetch? {
        if let fetch = fetches[number] { return fetch }
        guard let galleryURL else { return nil }
        lastFetchID += 1
        let id = lastFetchID
        let task = Task { [weak self, client] in
            do {
                let listed = try await client.previewPage(galleryURL: galleryURL, pageNumber: number)
                self?.finish(number, fetch: id, listed: listed)
                return listed
            } catch {
                self?.finish(number, fetch: id, listed: nil)
                throw error
            }
        }
        let fetch = Fetch(id: id, task: task)
        fetches[number] = fetch
        return fetch
    }

    private func finish(_ number: Int, fetch id: Int, listed: PreviewPage?) {
        // A request that was cancelled or reset is no longer registered; its result is dropped.
        guard fetches[number]?.id == id else { return }
        fetches[number] = nil
        // Legacy: an empty list is "not found".
        guard let listed, !listed.isEmpty else {
            failed.insert(number)
            return
        }
        failed.remove(number)
        loaded.insert(number)
        onLoad?(listed, number)
    }

    private func leave(_ number: Int, fetch id: Int) {
        guard var fetch = fetches[number], fetch.id == id else { return }
        fetch.waiters -= 1
        if fetch.waiters <= 0, !fetch.isForStrip {
            fetch.task.cancel()
            fetches[number] = nil
        } else {
            fetches[number] = fetch
        }
    }
}
