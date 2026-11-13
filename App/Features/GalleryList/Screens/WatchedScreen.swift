import EhFeatures
import EhModels
import SwiftUI

/// The watched-tags list. Needs login; its search field searches on the server.
struct WatchedScreen: View {
    @State private var model = WatchedModel()
    @State private var sheet: Sheet?

    private enum Sheet: String, Identifiable {
        case filters
        case quickSearch
        var id: String { rawValue }
    }

    var body: some View {
        PagedGalleryList(model: model.list)
            .screenGround()
            .tagSearchable(
                text: $model.keyword, prompt: L10n.Localizable.TabItem.Title.search,
                onSubmit: { model.submitKeyword() }
            )
            .navigationTitle(L10n.Localizable.WatchedView.Title.watched)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ListDisplayModeButton()
                    ToolbarFeaturesMenu {
                        FiltersButton { sheet = .filters }
                        QuickSearchButton { sheet = .quickSearch }
                    }
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .filters:
                    FiltersSheet(range: .watched)
                case .quickSearch:
                    QuickSearchSheet { word in
                        self.sheet = nil
                        model.quickSearch(word)
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: sheet) { _, sheet in sheet != nil }
    }
}
