import EhFeatures
import SwiftUI

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
