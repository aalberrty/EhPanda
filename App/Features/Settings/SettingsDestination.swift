import EhFeatures
import EhModels
import SwiftUI

// Placeholder entry point. The feature that owns this screen replaces the body.
struct SettingsDestination: View {
    let route: SettingsRoute

    var body: some View {
        FeaturePlaceholder(name: "Setting: \(route)")
    }
}
