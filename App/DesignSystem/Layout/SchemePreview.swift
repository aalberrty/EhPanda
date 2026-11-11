import SwiftUI

/// Preview helper: renders `content` twice, in light and in dark, each on the system background.
struct SchemePreview<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                    content
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .environment(\.colorScheme, scheme)
                }
            }
        }
    }
}
