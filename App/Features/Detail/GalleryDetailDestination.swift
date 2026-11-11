import EhFeatures
import EhModels
import SwiftUI

// Placeholder entry point. The feature that owns this screen replaces the body.
struct GalleryDetailDestination: View {
    let gallery: Gallery

    var body: some View {
        FeaturePlaceholder(name: "Gallery \(gallery.gid)")
    }
}
