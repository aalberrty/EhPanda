import EhFeatures
import EhModels
import SwiftUI

/// The Home tab root: Popular cards, the Frontpage cover strip, the Toplists columns and
/// shortcuts to the other lists.
struct HomeScreen: View {
    @State private var model = HomeModel()

    @Environment(StackRouter.self) private var stack
    @Environment(AppRouter.self) private var router

    var body: some View {
        content
            .animation(.default, value: model.cards.isEmpty)
            .navigationTitle(L10n.Localizable.HomeView.Title.home)
            .toolbar { reloadItem }
            .task { await model.run() }
            .onChange(of: router.rootReselectionCount(for: .home)) {
                model.reloadAll()
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: router.rootReselectionCount(for: .home))
    }

    /// The whole page waits for Popular, as in legacy; the other sections fill in on their own.
    @ViewBuilder
    private var content: some View {
        if !model.cards.isEmpty {
            HomeSectionsView(model: model, open: open, openList: openList)
        } else if let error = model.popularState.failed {
            ErrorStateView(message: error.alertText, systemImage: error.symbol.rawValue, retry: model.reloadAll)
        } else {
            LoadingStateView()
        }
    }

    private var reloadItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if model.popularState.isLoading {
                ProgressView()
            } else {
                Button(action: model.reloadAll) {
                    Label(L10n.Localizable.ReadingView.ContextMenu.Button.reload, systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    private func open(_ gallery: Gallery) {
        stack.push(.detail(gallery))
    }

    private func openList(_ kind: GalleryListKind) {
        stack.push(.galleryList(kind))
    }
}

/// The loaded page. Each section reads only the model properties it renders.
private struct HomeSectionsView: View {
    let model: HomeModel
    let open: (Gallery) -> Void
    let openList: (GalleryListKind) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Spacing.xxLarge) {
                HomeCardCarousel(cards: model.cards, open: open)
                FrontpageSection(model: model, open: open, openList: openList)
                ToplistsSection(model: model, open: open, openList: openList)
                SubSection(title: L10n.Localizable.HomeView.Section.Title.other, showsAll: false) {
                    HomeShortcuts(open: openList)
                }
            }
            .padding(.vertical, Tokens.Spacing.small)
        }
        .scrollIndicators(.hidden)
    }
}

private struct FrontpageSection: View {
    let model: HomeModel
    let open: (Gallery) -> Void
    let openList: (GalleryListKind) -> Void

    var body: some View {
        let count = model.frontpage.count
        let isLoading = model.frontpageState.isLoading
        // Legacy hid the strip until it had a full column; placeholders cover the first load.
        if HomeSections.showsCoverStrip(galleryCount: count) || (count == 0 && isLoading) {
            SubSection(
                title: L10n.Localizable.HomeView.Section.Title.frontpage, tint: .secondary, isLoading: isLoading,
                reload: model.reloadFrontpage, showAll: { openList(.frontpage) }
            ) {
                HomeCoverStrip(columns: model.coverColumns, showsPlaceholders: count == 0, open: open)
            }
        }
    }
}

private struct ToplistsSection: View {
    let model: HomeModel
    let open: (Gallery) -> Void
    let openList: (GalleryListKind) -> Void

    var body: some View {
        SubSection(
            title: L10n.Localizable.HomeView.Section.Title.toplists, tint: .secondary,
            isLoading: model.isLoadingToplists,
            reload: model.reloadToplists, showAll: { openList(.toplists) }
        ) {
            HomeToplists(
                periods: ToplistsType.allCases.map { ToplistsPeriod(type: $0, galleries: model.toplists(for: $0)) },
                open: open
            )
        }
    }
}

#Preview {
    NavigationStack {
        HomeScreen()
    }
    .environment(StackRouter())
    .environment(AppRouter())
}
