import EhFeatures
import SwiftUI

/// Maps a cross-feature `Route` to the entry view of the feature that owns it.
struct RouteDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case .galleryList(let kind):
            GalleryListDestination(kind: kind)
        case .search(let keyword):
            SearchResultsDestination(keyword: keyword)
        case .detail(let gallery):
            GalleryDetailDestination(gallery: gallery)
        case .settings(let route):
            SettingsDestination(route: route)
        }
    }
}
