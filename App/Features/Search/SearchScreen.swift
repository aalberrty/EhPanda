import EhFeatures
import EhModels
import SwiftUI

/// The Search tab's root (E-Search): Quick search words as chips, recent searches in two
/// columns, recently seen covers, and the search filter as chips above the search field.
///
/// On iOS 26 the search tab folds the tab bar and puts the field at the bottom; on iOS 18
/// the field sits in the navigation bar and the chips stay above the tab bar.
struct SearchScreen: View {
    @State private var model = SearchRootModel()
    @Environment(AppRouter.self) private var appRouter
    @Environment(StackRouter.self) private var stack
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            SearchRootSections(
                model: model, isRegularWidth: horizontalSizeClass == .regular,
                search: { model.search($0, on: stack) },
                openGallery: { stack.push(.detail($0)) }
            )
        }
        .scrollIndicators(.hidden)
        .floatingBar(edge: .bottom) {
            SearchFilterBar(showFilters: model.showFilters)
        }
        // While typing, the keyboard covers the chips instead of lifting them into the search
        // field, which rises above the keyboard on iOS 26.
        .ignoresSafeArea(.keyboard)
        .screenGround()
        .navigationTitle(L10n.Localizable.SearchView.Title.search)
        .tagSearchable(
            text: $model.keyword, prompt: L10n.Localizable.TabItem.Title.search,
            onSubmit: { model.submit(on: stack) }
        )
        .sheet(item: $model.sheet, onDismiss: { model.sheetDismissed(on: stack) }) { sheet in
            switch sheet {
            case .filters:
                FiltersSheet(range: .search)
            case .quickSearch, .newQuickSearchWord:
                QuickSearchSheet(startsAdding: sheet == .newQuickSearchWord, onSelect: model.selectQuickSearchWord)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.sheet) { _, new in new != nil }
        // `AppModel.selectTab` plays the re-selection haptic.
        .onChange(of: reselections) { model.rootReselected() }
        .task(id: model.reloadID) { await model.observe() }
    }

    private var reselections: Int {
        appRouter.rootReselectionCount(for: .search)
    }
}

/// Quick search (always, so its words stay editable), then Recently searched and Recently
/// seen when they have content.
private struct SearchRootSections: View {
    let model: SearchRootModel
    let isRegularWidth: Bool
    let search: (String) -> Void
    let openGallery: (Gallery) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.large) {
            let quickSearch = model.quickSearchKeywords
            SubSection(
                title: L10n.Localizable.SearchView.Section.Title.quickSearch,
                showsAll: !quickSearch.isEmpty, tint: .textSecondary, showAll: model.showQuickSearch
            ) {
                QuickSearchChips(
                    keywords: Array(quickSearch.prefix(SearchRootModel.keywordLimit(isRegularWidth: isRegularWidth))),
                    search: search, addWord: model.addQuickSearchWord
                )
            }
            let history = model.historySearchKeywords
            if !history.isEmpty {
                SubSection(title: L10n.Localizable.SearchView.Section.Title.recentlySearched, showsAll: false) {
                    KeywordRows(
                        rows: SearchRootModel.keywordRows(history, isRegularWidth: isRegularWidth),
                        search: search,
                        remove: { keyword in Task { await model.removeHistoryKeyword(keyword) } }
                    )
                }
            }
            if !model.recentGalleries.isEmpty {
                SubSection(title: L10n.Localizable.SearchView.Section.Title.recentlySeen, showsAll: false) {
                    RecentGalleries(galleries: model.recentGalleries, open: openGallery)
                }
            }
        }
        .padding(.vertical, Tokens.Spacing.small)
        .animation(.default, value: model.quickSearchWords)
        .animation(.default, value: model.historyKeywords)
        .animation(.default, value: model.recentGalleries)
    }
}
