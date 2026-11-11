import EhFeatures
import EhModels
import SwiftUI

/// Every opened gallery, newest first, from the database. Updates live; "Clear" empties it.
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
            .task { await model.observe() }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch model.loadingState {
            case .loading:
                LoadingStateView()
            case .failed(let error):
                ErrorStateView(message: error.alertText, systemImage: error.symbol.rawValue)
            case .idle where model.galleries.isEmpty:
                EmptyStateView()
            case .idle:
                GalleryCollection(galleries: model.visibleGalleries)
                    .refreshable { await model.refresh() }
                    .overlay {
                        if model.visibleGalleries.isEmpty {
                            ContentUnavailableView.search(text: model.titleFilter)
                        }
                    }
            }
        }
    }
}
