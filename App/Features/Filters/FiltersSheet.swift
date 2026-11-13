import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Edits the search filter of one `FilterRange` (legacy `FiltersView`). Opens on the range of
/// the list that presented it; legacy always opened on "Search".
struct FiltersSheet: View {
    @State private var model: FiltersModel
    @FocusState private var focusedBound: FiltersModel.Bound?
    @Environment(\.dismiss) private var dismiss

    init(range: FilterRange) {
        _model = State(initialValue: FiltersModel(range: range))
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    FiltersBasicSection(model: model)
                    FiltersAdvancedSections(model: model, focusedBound: $focusedBound)
                }
                .raisedRows()
            }
            .screenGround(.grouped)
            .navigationTitle(L10n.Localizable.FiltersView.Title.filters)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        // The model decides where focus goes on return; the field reports where the user taps.
        .onChange(of: model.focusedBound) { _, bound in
            if focusedBound != bound { focusedBound = bound }
        }
        .onChange(of: focusedBound) { _, bound in
            if model.focusedBound != bound { model.focusedBound = bound }
        }
    }
}

private struct FiltersBasicSection: View {
    @Bindable var model: FiltersModel

    var body: some View {
        Section {
            Picker(selection: $model.range) {
                ForEach(FilterRange.allCases) { range in
                    Text(range.localizedName).tag(range)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            FilterCategoryGrid(model: model)
            Button(L10n.Localizable.FiltersView.Button.resetFilters, role: .destructive) {
                model.presentResetConfirmation()
            }
            .confirmationDialog(
                L10n.Localizable.ConfirmationDialog.Title.reset,
                isPresented: $model.isResetConfirmationPresented, titleVisibility: .visible
            ) {
                Button(L10n.Localizable.ConfirmationDialog.Button.reset, role: .destructive) { model.reset() }
            }
            Toggle(L10n.Localizable.FiltersView.Title.advancedSettings, isOn: $model.filter.advanced)
        }
    }
}

/// The ten categories as tiles; a struck-through tile is excluded from results.
private struct FilterCategoryGrid: View {
    let model: FiltersModel

    @Environment(SettingsStore.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var toggles = 0

    var body: some View {
        let host = settings.galleryHost
        LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 100 : 80, maximum: 100))]) {
            ForEach(FiltersModel.categories) { category in
                CategoryToggleTile(
                    category.localizedName, color: category.color(for: host), isOn: !model.isExcluded(category)
                ) {
                    toggles += 1
                    model.toggleExclusion(of: category)
                }
            }
        }
        .padding(.vertical, Tokens.Spacing.small)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: toggles)
    }
}
