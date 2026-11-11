import Dependencies
import EhCore
import EhFeatures
import SwiftUI

/// Preview helper: `content` in a navigation stack with the stores and router the settings
/// screens read from the environment (preview values: empty, in-memory defaults).
struct SettingsPreview<Content: View>: View {
    @Dependency(\.settings) private var settings
    @State private var router = StackRouter()
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            content
        }
        .environment(settings)
        .environment(router)
    }
}
