import SwiftUI
import UIKit

// Share URLs and text with `ShareLink`, which needs no wrapper:
//
//     ShareLink(item: galleryURL)
//
// `ActivityView` remains only for items `ShareLink` cannot carry without re-encoding, such as a
// reader page's original image data (GIF, WebP) or a `UIImage` together with its file name.

/// `UIActivityViewController` for a `.sheet` (legacy `ActivityView`).
struct ActivityView: UIViewControllerRepresentable {
    private let items: [Any]

    init(items: [Any]) {
        self.items = items
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ActivityViewPreview: View {
    @State private var isPresented = false
    private let url = URL(string: "https://e-hentai.org")

    var body: some View {
        VStack(spacing: Tokens.Spacing.large) {
            if let url {
                ShareLink(item: url)
            }
            Button {
                isPresented = true
            } label: {
                Label { Text(verbatim: "Share image") } icon: { Image(systemName: "photo") }
            }
        }
        .glassButtonStyle()
        .sheet(isPresented: $isPresented) {
            ActivityView(items: [UIImage(systemName: "photo") as Any])
                .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    SchemePreview { ActivityViewPreview() }
}
