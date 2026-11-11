import EhFeatures
import EhModels
import SwiftUI

/// The Search tab's root (legacy `SearchRootView`).
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
        .navigationTitle(L10n.Localizable.SearchView.Title.search)
        .tagSearchable(
            text: $model.keyword, prompt: L10n.Localizable.TabItem.Title.search,
            onSubmit: { model.submit(on: stack) }
        )
        .toolbar {
            ToolbarItem {
                ToolbarFeaturesMenu {
                    FiltersButton(action: model.showFilters)
                    QuickSearchButton(action: model.showQuickSearch)
                }
                .symbolRenderingMode(.hierarchical)
            }
        }
        .sheet(item: $model.sheet, onDismiss: { model.sheetDismissed(on: stack) }) { sheet in
            switch sheet {
            case .filters:
                FiltersSheet(range: .search)
            case .quickSearch:
                QuickSearchSheet(onSelect: model.selectQuickSearchWord)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.sheet) { _, new in new != nil }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: reselections)
        .onChange(of: reselections) { model.rootReselected() }
        .task(id: model.reloadID) { await model.observe() }
    }

    private var reselections: Int {
        appRouter.rootReselectionCount(for: .search)
    }
}

/// Quick Search, Recently Searched and Recently Seen, each shown only when it has content.
private struct SearchRootSections: View {
    let model: SearchRootModel
    let isRegularWidth: Bool
    let search: (String) -> Void
    let openGallery: (Gallery) -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.xLarge) {
            let quickSearch = model.quickSearchKeywords
            if !quickSearch.isEmpty {
                SubSection(
                    title: L10n.Localizable.SearchView.Section.Title.quickSearch,
                    tint: .primary, showAll: model.showQuickSearch
                ) {
                    KeywordColumns(
                        keywords: quickSearch, isRegularWidth: isRegularWidth, search: search, remove: nil
                    )
                }
            }
            let history = model.historySearchKeywords
            if !history.isEmpty {
                SubSection(title: L10n.Localizable.SearchView.Section.Title.recentlySearched, showsAll: false) {
                    KeywordColumns(
                        keywords: history, isRegularWidth: isRegularWidth, search: search,
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
        .padding(.vertical)
        .animation(.default, value: model.quickSearchWords)
        .animation(.default, value: model.historyKeywords)
        .animation(.default, value: model.recentGalleries)
    }
}
