import EhFeatures
import EhModels
import SwiftUI

/// The pushed list screens of the Home tab.
struct GalleryListDestination: View {
    let kind: GalleryListKind

    var body: some View {
        switch kind {
        case .frontpage:
            FilteredListScreen(
                source: .frontpage, title: L10n.Localizable.FrontpageView.Title.frontpage
            )
        case .popular:
            FilteredListScreen(source: .popular, title: L10n.Localizable.PopularView.Title.popular)
        case .toplists:
            ToplistsScreen()
        }
    }
}
