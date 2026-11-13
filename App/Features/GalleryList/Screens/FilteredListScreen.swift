import EhFeatures
import EhModels
import SwiftUI

/// Frontpage and Popular: a list with the Global filter, and a toolbar with the search field
/// that filters the loaded galleries by title, the display mode and Filters.
struct FilteredListScreen: View {
    let title: String

    @State private var model: GalleryListModel
    @State private var showsFilters = false

    init(source: GalleryListSource, title: String) {
        self.title = title
        _model = State(initialValue: GalleryListModel(source: source))
    }

    var body: some View {
        PagedGalleryList(model: model)
            .screenGround()
            .toolbarSearchable(text: $model.titleFilter, prompt: L10n.Localizable.Searchable.Prompt.filter)
            .navigationTitle(title)
            .toolbar {
                ToolbarSearchItem()
                ToolbarItemGroup(placement: .primaryAction) {
                    ListDisplayModeButton()
                    FiltersButton { showsFilters = true }
                }
            }
            .sheet(isPresented: $showsFilters) {
                FiltersSheet(range: model.source.filterRange ?? .global)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showsFilters) { _, isShown in isShown }
    }
}
