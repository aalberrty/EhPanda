import EhFeatures
import EhModels
import SwiftUI

/// Frontpage and Popular: a list with the Global filter, a Filters button and a search field
/// that filters the loaded galleries by title.
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
            .searchable(text: $model.titleFilter, prompt: L10n.Localizable.Searchable.Prompt.filter)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    FiltersButton { showsFilters = true }
                }
            }
            .sheet(isPresented: $showsFilters) {
                FiltersSheet(range: model.source.filterRange ?? .global)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showsFilters) { _, isShown in isShown }
    }
}
