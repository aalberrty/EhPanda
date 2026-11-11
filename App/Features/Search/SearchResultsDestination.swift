import EhFeatures
import EhModels
import SwiftUI

// Placeholder entry point. The feature that owns this screen replaces the body.
struct SearchResultsDestination: View {
    let keyword: String

    var body: some View {
        FeaturePlaceholder(name: "Search: \(keyword)")
    }
}
