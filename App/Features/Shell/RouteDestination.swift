import EhFeatures
import SwiftUI

/// Maps a `Route` to the entry view of the feature that owns it.
struct RouteDestination: View {
    let route: Route
    @Environment(StackRouter.self) private var stack

    var body: some View {
        destination
            // The tab bar follows the top screen of the stack. SwiftUI combines the visibility
            // every screen in a stack states, so only the top screen states one: a gallery below
            // a search would otherwise keep the bar hidden on the search, and a list below a
            // gallery stating `.visible` would show it on the gallery.
            .toolbarVisibility(Visibility(stack.tabBarVisibility(for: route)), for: .tabBar)
    }

    @ViewBuilder
    private var destination: some View {
        switch route {
        case .galleryList(let kind):
            GalleryListDestination(kind: kind)
        case .search(let keyword):
            SearchResultsDestination(keyword: keyword, recordsHistory: false)
        case .typedSearch(let keyword):
            SearchResultsDestination(keyword: keyword, recordsHistory: true)
        case .detail(let gallery, let intent):
            GalleryDetailDestination(gallery: gallery, intent: intent)
        case .detailChild(let route):
            GalleryDetailChildDestination(route: route)
        case .settings(let route):
            SettingsDestination(route: route)
        }
    }
}

private extension Visibility {
    init(_ visibility: TabBarVisibility) {
        switch visibility {
        case .automatic: self = .automatic
        case .visible: self = .visible
        case .hidden: self = .hidden
        }
    }
}
