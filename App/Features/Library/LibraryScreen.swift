import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The Library tab root: Favorites, Watched and History behind a segmented control under the
/// title. One search field, toolbar and set of sheets serve the segment on show; the lists below
/// stay on screen once opened, so each keeps its scroll place and loaded pages.
struct LibraryScreen: View {
    @State private var model = LibraryModel()

    @Environment(AppRouter.self) private var appRouter

    var body: some View {
        LibraryLists(model: model)
            .screenGround()
            .floatingBar(edge: .top, spacing: 0, background: .materialUnderNavigationBar) {
                LibrarySegmentPicker(model: model)
            }
            .tagSearchable(
                text: $model.searchText, prompt: searchPrompt, suggestsTags: model.searchesServer,
                onSubmit: { model.submitSearch() }
            )
            .navigationTitle(L10n.Localizable.TabItem.Title.library)
            // Large, but in the bar's row and never collapsing: the lists share one bar, and a
            // collapsing title would follow whichever list scrolled last (and on iOS 26 sit under
            // the scroll edge effect that the segment bar extends over it).
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar { LibraryToolbar(model: model) }
            .sheet(item: $model.destination) { destination in
                switch destination {
                case .quickSearch:
                    QuickSearchSheet { model.quickSearch($0) }
                case .filters:
                    FiltersSheet(range: .watched)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: model.destination) { _, new in new != nil }
            // `AppModel.selectTab` plays the re-selection haptic.
            .onChange(of: appRouter.rootReselectionCount(for: .library)) {
                model.reloadForTabReselection()
            }
    }

    private var searchPrompt: String {
        model.searchesServer ? L10n.Localizable.TabItem.Title.search : L10n.Localizable.Searchable.Prompt.filter
    }
}

/// The opened segments' lists, stacked, with only the selected one visible and interactive.
/// Keeping the others in place (rather than switching views) is what keeps their scroll places.
private struct LibraryLists: View {
    let model: LibraryModel

    var body: some View {
        ZStack {
            ForEach(model.openedSegments, id: \.self) { segment in
                let isShown = segment == model.segment
                list(for: segment)
                    .opacity(isShown ? 1 : 0)
                    .allowsHitTesting(isShown)
                    .accessibilityHidden(!isShown)
            }
        }
    }

    @ViewBuilder
    private func list(for segment: LibrarySegment) -> some View {
        switch segment {
        case .favorites:
            FavoritesList(model: model.favorites)
        case .watched:
            PagedGalleryList(model: model.watched.list)
        case .history:
            HistoryList(model: model.history)
        }
    }
}

/// The selected favourites folder's list with the folder chips above it. The chips are hidden
/// while the list asks the user to log in.
private struct FavoritesList: View {
    let model: FavoritesModel

    var body: some View {
        // Each folder is a list of its own, so its view is too: a list swapped into the previous
        // folder's view opened rows down, under the bars, instead of at its top. The stack keeps
        // that identity off the chip row, which keeps its own scroll place.
        ZStack {
            PagedGalleryList(model: model.list)
                .id(ObjectIdentifier(model.list))
        }
        .floatingBar(edge: .top, spacing: 0, background: .material) {
            if !model.list.needsLogin {
                FavoriteFolderChips(model: model)
            }
        }
    }
}

extension LibrarySegment {
    var localizedName: String {
        switch self {
        case .favorites: L10n.Localizable.FavoritesView.Title.favorites
        case .watched: L10n.Localizable.WatchedView.Title.watched
        case .history: L10n.Localizable.HistoryView.Title.history
        }
    }
}
