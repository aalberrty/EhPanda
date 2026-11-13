import Dependencies
import EhFeatures
import EhModels
import SwiftUI

/// The Home tab root: the Popular pager, the Frontpage wall and the Toplists columns (E-Home).
/// Watched and History live in the Library tab; the Popular list opens from the pager.
struct HomeScreen: View {
    @State private var model = HomeModel()

    @Environment(StackRouter.self) private var stack
    @Environment(AppRouter.self) private var router

    var body: some View {
        content
            .animation(.default, value: model.cards.isEmpty)
            .screenGround()
            .navigationTitle(L10n.Localizable.HomeView.Title.home)
            .toolbar { reloadItem }
            // The model owns the loads, so pushing a gallery does not cancel them.
            .onAppear { model.loadIfNeeded() }
            // `AppModel.selectTab` plays the re-selection haptic.
            .onChange(of: router.rootReselectionCount(for: .home)) {
                model.reloadAll()
            }
    }

    /// The whole page waits for Popular, as in legacy; the other sections fill in on their own.
    @ViewBuilder
    private var content: some View {
        if !model.cards.isEmpty {
            HomeSectionsView(model: model, open: open, openList: openList)
        } else if let error = model.popularState.failed {
            ErrorStateView(error: error, retry: model.reloadAll)
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
            VStack(spacing: 0) {
                HomePopularPager(galleries: model.cards, open: open, openPopular: { openList(.popular) })
                    .padding(.top, Tokens.Spacing.small)
                FrontpageSection(model: model, open: open, openList: openList)
                ToplistsSection(model: model, open: open, openList: openList)
            }
            .padding(.bottom, Tokens.Spacing.xLarge)
        }
        .scrollIndicators(.hidden)
    }
}

private struct FrontpageSection: View {
    let model: HomeModel
    let open: (Gallery) -> Void
    let openList: (GalleryListKind) -> Void

    var body: some View {
        let galleries = model.frontpage
        let isLoading = model.frontpageState.isLoading
        // Placeholders cover the first load; a failed first load hides the section, as in legacy.
        if !galleries.isEmpty || isLoading {
            VStack(spacing: Tokens.Spacing.xSmall) {
                HomeSectionHeader(
                    title: L10n.Localizable.HomeView.Section.Title.frontpage, isLoading: isLoading,
                    reload: model.reloadFrontpage, showAll: { openList(.frontpage) }
                )
                HomeFrontpageWall(galleries: galleries, showsPlaceholders: galleries.isEmpty, open: open)
            }
            .padding(.top, 14)
        }
    }
}

private struct ToplistsSection: View {
    let model: HomeModel
    let open: (Gallery) -> Void
    let openList: (GalleryListKind) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HomeSectionHeader(
                title: L10n.Localizable.HomeView.Section.Title.toplists, isLoading: model.isLoadingToplists,
                reload: model.reloadToplists, showAll: { openList(.toplists) }
            )
            HomeToplists(
                periods: ToplistsType.allCases.map { ToplistsPeriod(type: $0, galleries: model.toplists(for: $0)) },
                open: open
            )
        }
        .padding(.top, 22)
    }
}

private struct HomeScreenPreview: View {
    @Dependency(\.settings) private var settings

    var body: some View {
        NavigationStack {
            HomeScreen()
        }
        .environment(StackRouter())
        .environment(AppRouter())
        .environment(settings)
        .environment(CoverPaletteStore())
    }
}

#Preview {
    HomeScreenPreview()
}
