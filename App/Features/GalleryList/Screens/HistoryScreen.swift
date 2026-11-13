import EhFeatures
import EhModels
import SwiftUI

/// History as a screen of its own, pushed from Home; the Library tab shows the same list as a
/// segment. "Clear" empties it.
struct HistoryScreen: View {
    @State private var model = HistoryModel()

    var body: some View {
        HistoryList(model: model)
            .searchable(text: $model.titleFilter, prompt: L10n.Localizable.Searchable.Prompt.filter)
            .navigationTitle(L10n.Localizable.HistoryView.Title.history)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HistoryClearButton(model: model)
                }
            }
    }
}
