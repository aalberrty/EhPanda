import EhFeatures
import EhModels
import SwiftUI

/// The tab bar and the navigation stack of each tab.
///
/// Feature screens never reference each other. A feature shows another feature's screen by
/// pushing a `Route` onto the `StackRouter` in its environment; `RouteDestination` maps the
/// route to the owning feature's entry view.
struct AppShellView: View {
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: selectedTab) {
            Tab(L10n.Localizable.TabItem.Title.home, systemImage: "house", value: AppTab.home) {
                RoutedStack(router: router.home) { HomeScreen() }
            }
            Tab(L10n.Localizable.TabItem.Title.favorites, systemImage: "heart", value: AppTab.favorites) {
                RoutedStack(router: router.favorites) { FavoritesScreen() }
            }
            Tab(value: AppTab.search, role: .search) {
                RoutedStack(router: router.search) { SearchScreen() }
            }
            Tab(L10n.Localizable.TabItem.Title.setting, systemImage: "gearshape", value: AppTab.settings) {
                RoutedStack(router: router.settings) { SettingsScreen() }
            }
        }
        .environment(router)
        .sheet(item: presentedGallery) { gallery in
            RoutedStack(router: router.presented) { GalleryDetailDestination(gallery: gallery) }
        }
    }

    /// Routed through `select` so that tapping the current tab pops to its root or reloads it.
    private var selectedTab: Binding<AppTab> {
        Binding(get: { router.selectedTab }, set: { router.select($0) })
    }

    private var presentedGallery: Binding<Gallery?> {
        Binding(
            get: { router.presentedGallery },
            set: { if $0 == nil { router.dismissPresentedGallery() } }
        )
    }
}

/// A `NavigationStack` bound to a `StackRouter`, which it also exposes to its content.
struct RoutedStack<Root: View>: View {
    @Bindable var router: StackRouter
    @ViewBuilder var root: Root

    var body: some View {
        NavigationStack(path: $router.path) {
            root.navigationDestination(for: Route.self) { route in
                RouteDestination(route: route)
            }
        }
        .environment(router)
    }
}

#Preview {
    AppShellView()
}
