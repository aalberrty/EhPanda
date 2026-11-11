import EhNetworking
import Foundation

/// Loads the thumbnails of the slider's preview strip, one preview page per request and only
/// when the strip asks for one.
///
/// Legacy fetched them from the strip's cells, but only built the cells when some preview was
/// already known, so on a gallery without stored previews the strip never appeared.
final class ReaderPreviewLoader {
    /// Called with the previews a preview page listed, by 1-based page index.
    var onLoad: ((_ previews: [Int: URL], _ previewPage: Int) -> Void)?

    private let galleryURL: URL?
    private let client: EhClient
    private var loading: [Int: Task<Void, Never>] = [:]
    private var loaded: Set<Int> = []
    private var failed: Set<Int> = []

    init(galleryURL: URL?, client: EhClient) {
        self.galleryURL = galleryURL
        self.client = client
    }

    /// Loads a preview page unless it is loading or was loaded. A preview page that failed is
    /// left alone until `retryFailed()`, so dragging the slider does not ask again and again.
    func load(previewPage: Int) {
        guard let galleryURL, loading[previewPage] == nil,
              !loaded.contains(previewPage), !failed.contains(previewPage)
        else { return }
        loading[previewPage] = Task { [weak self, client] in
            let previews = try? await client.previewURLs(galleryURL: galleryURL, pageNumber: previewPage)
            guard !Task.isCancelled, let self else { return }
            loading[previewPage] = nil
            // Legacy: an empty list is "not found".
            guard let previews, !previews.isEmpty else {
                failed.insert(previewPage)
                return
            }
            loaded.insert(previewPage)
            onLoad?(previews, previewPage)
        }
    }

    func retryFailed() {
        failed = []
    }

    /// Cancels what is loading, for when the reader closes.
    func stop() {
        for task in loading.values {
            task.cancel()
        }
        loading = [:]
    }

    /// Forgets everything, for "reload all images".
    func reset() {
        stop()
        loaded = []
        failed = []
    }
}
