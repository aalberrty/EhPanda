import EhFeatures
import EhModels
import SwiftUI

/// A `GalleryListModel` on screen: the login prompt, loading, error and empty states, the
/// galleries with pull to refresh, and the pagination footer that loads the next page when it
/// scrolls into view. Every load runs in a task of this view, so leaving the screen cancels it.
///
/// Put the screen's search field, toolbar and sheets around it; it has none of its own.
struct PagedGalleryList: View {
    let model: GalleryListModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .notLoggedIn:
                LoginRequiredView()
            case .loading:
                LoadingStateView()
            case .failed(let error):
                ErrorStateView(
                    message: error.alertText, systemImage: error.symbol.rawValue,
                    retry: error.isRetryable ? { model.retry() } : nil
                )
            case .content:
                GalleryCollection(galleries: model.visibleGalleries) {
                    ListPaginationFooter(model: model)
                }
                .refreshable { await model.refresh() }
                .overlay {
                    if model.visibleGalleries.isEmpty {
                        ContentUnavailableView.search(text: model.titleFilter)
                    }
                }
            }
        }
        .animation(.default, value: model.phase)
        // Kept outside the switch so changing phase does not cancel the load it started.
        .task(id: model.loadRequest) { await model.loadIfNeeded() }
    }
}

private struct ListPaginationFooter: View {
    let model: GalleryListModel

    var body: some View {
        PaginationFooter(phase: phase) { model.retryLoadMore() }
            .task(id: model.paginationTrigger) { await model.loadMore() }
    }

    private var phase: PaginationFooter.Phase {
        switch model.footerPhase {
        case .idle: .idle
        case .loading: .loading
        case .failed: .failed
        case .end: .end
        }
    }
}

/// The "need login" prompt. Its button opens Settings › Account › Login (legacy
/// `NotLoginView` routing).
struct LoginRequiredView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var loginRequests = 0

    var body: some View {
        NotLoggedInView {
            loginRequests += 1
            appRouter.select(.settings)
            appRouter.settings.path = [.settings(.account), .settings(.login)]
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: loginRequests)
    }
}
