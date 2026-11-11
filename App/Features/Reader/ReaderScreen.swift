import EhModels
import SwiftUI

// Placeholder entry point. The reader feature replaces the body.
/// The full-screen reader for a gallery. Present it with `fullScreenCover`.
/// `initialPage` is 1-based; nil opens at the stored reading progress.
struct ReaderScreen: View {
    let gallery: Gallery
    var initialPage: Int?

    var body: some View {
        FeaturePlaceholder(name: "Reader \(gallery.gid)")
    }
}
