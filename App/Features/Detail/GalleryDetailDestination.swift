import EhFeatures
import EhModels
import SwiftUI

/// The gallery detail screen, for `Route.detail` and for galleries opened from links.
struct GalleryDetailDestination: View {
    let gallery: Gallery

    @State private var model: GalleryDetailModel

    init(gallery: Gallery) {
        self.gallery = gallery
        _model = State(initialValue: GalleryDetailModel(gallery: gallery))
    }

    var body: some View {
        GalleryDetailView(model: model)
    }
}
