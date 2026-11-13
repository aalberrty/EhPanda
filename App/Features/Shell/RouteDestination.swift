import EhFeatures
import SwiftUI

/// Maps a `Route` to the entry view of the feature that owns it.
struct RouteDestination: View {
    let route: Route

    var body: some View {
        destination
            // E-Detail draws the gallery without the tab bar. Its child screens hide it as well,
            // so it does not come and go while moving between them; the system shows it again
            // on the screen below when the gallery is popped.
            .toolbarVisibility(route.showsTabBar ? .automatic : .hidden, for: .tabBar)
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

private extension Route {
    /// A gallery's detail screen and the screens pushed from it hide the tab bar.
    var showsTabBar: Bool {
        switch self {
        case .detail, .detailChild: false
        case .galleryList, .search, .typedSearch, .settings: true
        }
    }
}
