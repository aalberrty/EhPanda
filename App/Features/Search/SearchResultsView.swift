import EhFeatures
import EhModels
import SwiftUI

/// Search results for a keyword (legacy `SearchView` and `DetailSearchView`).
///
/// `recordsHistory` is true for searches typed in the Search tab and false for detail searches.
struct SearchResultsView: View {
    @State private var model: SearchResultsModel

    @Environment(AppRouter.self) private var appRouter
    @Environment(StackRouter.self) private var stack

    init(keyword: String, recordsHistory: Bool) {
        _model = State(initialValue: SearchResultsModel(keyword: keyword, recordsHistory: recordsHistory))
    }

    var body: some View {
        PagedGalleryList(model: model.list)
            .screenGround()
            .navigationTitle(model.lastKeyword)
            .tagSearchable(
                text: $model.keyword, prompt: L10n.Localizable.TabItem.Title.search,
                inToolbar: searchesInToolbar, onSubmit: { Task { await model.submit() } }
            )
            .toolbar {
                if searchesInToolbar {
                    ToolbarSearchItem()
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    ListDisplayModeButton()
                    ToolbarFeaturesMenu {
                        FiltersButton(action: model.showFilters)
                        QuickSearchButton(action: model.showQuickSearch)
                    }
                }
            }
            .sheet(item: $model.sheet) { sheet in
                switch sheet {
                case .filters:
                    FiltersSheet(range: .search)
                case .quickSearch, .newQuickSearchWord:
                    QuickSearchSheet(startsAdding: sheet == .newQuickSearchWord) { word in
                        Task { await model.selectQuickSearchWord(word) }
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: model.sheet) { _, sheet in sheet != nil }
            .task { await model.start() }
    }

    /// The field waits behind a toolbar button, as on the other lists, except in the Search tab:
    /// there iOS 26 makes the tab's own search button stand for every field in the tab, and a
    /// toolbar search button would open the Search root's field instead of this one. A screen
    /// never changes stacks, so this stays the same for its life.
    private var searchesInToolbar: Bool {
        stack !== appRouter.search
    }
}
