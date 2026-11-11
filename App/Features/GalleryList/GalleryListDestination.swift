import EhFeatures
import EhModels
import SwiftUI

// Placeholder entry point. The feature that owns this screen replaces the body.
struct GalleryListDestination: View {
    let kind: GalleryListKind

    var body: some View {
        FeaturePlaceholder(name: "List: \(kind)")
    }
}
