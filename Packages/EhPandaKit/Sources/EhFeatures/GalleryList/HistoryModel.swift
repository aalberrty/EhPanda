import Dependencies
import EhCore
import EhDatabase
import EhModels
import Observation

/// The History screen: every gallery the user opened, newest first, read from the database.
@Observable
public final class HistoryModel {
    public private(set) var galleries: [Gallery] = [] {
        didSet { updateVisibleGalleries() }
    }
    public private(set) var visibleGalleries: [Gallery] = []
    public var titleFilter = "" {
        didSet {
            if titleFilter != oldValue { updateVisibleGalleries() }
        }
    }
    /// `.loading` until the database first answers.
    public private(set) var loadingState: LoadingState = .loading
    public var isClearConfirmationPresented = false

    @ObservationIgnored @Dependency(\.database) private var database

    public init() {}

    public var canClear: Bool { !loadingState.isLoading && !galleries.isEmpty }

    /// Follows the history until the calling task is cancelled.
    public func observe() async {
        do {
            for try await galleries in database.observeHistory() {
                apply(galleries)
            }
        } catch {
            fail(error)
        }
    }

    /// Reads the history once (pull to refresh). The observation keeps it current anyway.
    public func refresh() async {
        do {
            for try await galleries in database.observeHistory() {
                apply(galleries)
                break
            }
        } catch {
            fail(error)
        }
    }

    public func clear() async {
        isClearConfirmationPresented = false
        do {
            try await database.clearHistory()
        } catch {
            fail(error)
        }
    }

    private func apply(_ galleries: [Gallery]) {
        self.galleries = galleries.filter { $0.lastOpenDate != nil }
        loadingState = .idle
    }

    private func fail(_ error: any Error) {
        guard !(error is CancellationError), !Task.isCancelled else { return }
        loadingState = .failed(.databaseCorrupted(nil))
    }

    private func updateVisibleGalleries() {
        visibleGalleries = GalleryListPaging.filtered(galleries, byTitle: titleFilter)
    }
}
