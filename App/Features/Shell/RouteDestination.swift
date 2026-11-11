import EhFeatures
import SwiftUI

/// Maps a `Route` to the entry view of the feature that owns it.
struct RouteDestination: View {
    let route: Route

    var body: some View {
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
