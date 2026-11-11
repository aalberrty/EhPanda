import EhFeatures
import EhModels
import SwiftUI

/// Every opened gallery, newest first, from the database a page at a time. Updates live;
/// "Clear" empties it.
struct HistoryScreen: View {
    @State private var model = HistoryModel()

    var body: some View {
        content
            .searchable(text: $model.titleFilter, prompt: L10n.Localizable.Searchable.Prompt.filter)
            .navigationTitle(L10n.Localizable.HistoryView.Title.history)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.Localizable.ConfirmationDialog.Button.clear, systemImage: "trash.circle") {
                        model.isClearConfirmationPresented = true
                    }
                    .disabled(!model.canClear)
                    .confirmationDialog(
                        L10n.Localizable.ConfirmationDialog.Title.clear,
                        isPresented: $model.isClearConfirmationPresented, titleVisibility: .visible
                    ) {
                        Button(L10n.Localizable.ConfirmationDialog.Button.clear, role: .destructive) {
                            Task { await model.clear() }
                        }
                    }
                }
            }
            // A new filter or another page restarts the observation for those rows.
            .task(id: model.query) { await model.observe() }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch model.loadingState {
            case .loading:
                LoadingStateView()
            case .failed(let error):
                ErrorStateView(message: error.alertText, systemImage: error.symbol.rawValue)
            case .idle where model.isHistoryEmpty:
                EmptyStateView()
            case .idle:
                GalleryCollection(galleries: model.galleries) {
                    HistoryFooter(model: model)
                }
                .refreshable { await model.refresh() }
                .overlay {
                    if model.galleries.isEmpty {
                        ContentUnavailableView.search(text: model.titleFilter)
                    }
                }
            }
        }
    }
}

/// The end of the history: asks for the next page when it scrolls into view, and again when a
/// page lands while it is still visible.
private struct HistoryFooter: View {
    let model: HistoryModel

    var body: some View {
        PaginationFooter(phase: model.hasMore ? .loading : .end) {}
            .task(id: model.galleries.count) { model.loadMore() }
    }
}
