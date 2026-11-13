import Dependencies
import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The tab bar and the navigation stack of each tab, the gallery sheet for links opened from
/// outside the app and the New Dawn greeting.
///
/// Feature screens never reference each other. A feature shows another feature's screen by
/// pushing a `Route` onto the `StackRouter` in its environment; `RouteDestination` maps the
/// route to the owning feature's entry view. Settings is an ordinary tab on iPad too.
struct MainTabView: View {
    let model: AppModel

    // Shared services, created by the launch off the main actor. They are injected into the
    // environment so views read the individual properties they render; models reach the same
    // instances through `@Dependency`.
    @Dependency(\.filterStore) private var filterStore
    @Dependency(\.userStore) private var userStore
    @Dependency(\.tagTranslationService) private var tagTranslationService
    @Dependency(\.accountSession) private var accountSession

    var body: some View {
        let router = model.router
        TabView(selection: selectedTab) {
            Tab(L10n.Localizable.TabItem.Title.home, systemImage: "house", value: AppTab.home) {
                RoutedStack(router: router.home) { HomeScreen() }
            }
            Tab(L10n.Localizable.TabItem.Title.library, systemImage: "books.vertical", value: AppTab.library) {
                RoutedStack(router: router.library) { LibraryScreen() }
            }
            Tab(L10n.Localizable.TabItem.Title.setting, systemImage: "gearshape", value: AppTab.settings) {
                RoutedStack(router: router.settings) { SettingsScreen() }
            }
            // Last, as drawn: iOS 26 sets the search tab apart at the trailing end anyway.
            Tab(value: AppTab.search, role: .search) {
                RoutedStack(router: router.search) { SearchScreen() }
            }
        }
        .sheet(item: presentedGallery) { gallery in
            RoutedStack(router: router.presented) {
                // The link's target (an image page or a comment) is honoured once.
                GalleryDetailDestination(
                    gallery: gallery, intent: router.takePresentedGalleryTarget(for: gallery.gid).map(DetailIntent.init)
                )
            }
                // The detail screen in this sheet may receive the greeting; only the topmost
                // presenter can show it.
                .newDawnSheet(router: router, isTopmost: true)
        }
        .newDawnSheet(router: router, isTopmost: router.presentedGallery == nil)
        .hud(linkHUD)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: model.tabReselectionFeedback)
        .sensoryFeedback(.impact(weight: .light), trigger: router.presentedGallery?.gid) { _, new in new != nil }
        .task(id: model.links.request) { await model.links.handleRequest() }
        .task(id: model.activationRequest) { await model.performActivationWork() }
        .environment(filterStore)
        .environment(userStore)
        .environment(tagTranslationService)
        .environment(accountSession)
    }

    /// Routed through the model so that re-selecting a tab pops or reloads it, with haptics.
    private var selectedTab: Binding<AppTab> {
        Binding(get: { model.router.selectedTab }, set: { model.selectTab($0) })
    }

    private var presentedGallery: Binding<Gallery?> {
        Binding(
            get: { model.router.presentedGallery },
            set: { if $0 == nil { model.router.dismissPresentedGallery() } }
        )
    }

    /// Progress of a link being opened; the error HUD clears itself.
    private var linkHUD: Binding<HUDConfiguration?> {
        Binding(
            get: {
                switch model.links.progress {
                case .loading: .loading
                case .failed: .error
                case nil: nil
                }
            },
            set: { if $0 == nil { model.links.progress = nil } }
        )
    }
}
