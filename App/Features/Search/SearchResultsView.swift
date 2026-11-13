import EhFeatures
import EhModels
import SwiftUI

/// Search results for a keyword (legacy `SearchView` and `DetailSearchView`).
///
/// `recordsHistory` is true for searches typed in the Search tab and false for detail searches.
struct SearchResultsView: View {
    @State private var model: SearchResultsModel

    init(keyword: String, recordsHistory: Bool) {
        _model = State(initialValue: SearchResultsModel(keyword: keyword, recordsHistory: recordsHistory))
    }

    var body: some View {
        PagedGalleryList(model: model.list)
            .screenGround()
            .navigationTitle(model.lastKeyword)
            .tagSearchable(
                text: $model.keyword, prompt: L10n.Localizable.TabItem.Title.search,
                onSubmit: { Task { await model.submit() } }
            )
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
}
