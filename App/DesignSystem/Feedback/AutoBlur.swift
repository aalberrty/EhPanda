import SwiftUI

extension View {
    /// Blurs the view for privacy, e.g. while the app is inactive or locked (legacy `autoBlur`).
    ///
    /// Touches are ignored while the blur is visible. The radius change animates briefly.
    func autoBlur(radius: Double) -> some View {
        blur(radius: radius)
            .allowsHitTesting(radius < 1)
            .accessibilityHidden(radius >= 1)
            .animation(.linear(duration: 0.1), value: radius)
    }
}

private struct AutoBlurPreview: View {
    @State private var isBlurred = true

    var body: some View {
        VStack(spacing: Tokens.Spacing.large) {
            VStack(alignment: .leading) {
                Text(verbatim: "Private content").font(.headline)
                RatingStars(rating: 4).foregroundStyle(.yellow)
            }
            .autoBlur(radius: isBlurred ? 10 : 0)
            Toggle(isOn: $isBlurred) { Text(verbatim: "Blur") }
        }
    }
}

#Preview {
    SchemePreview { AutoBlurPreview() }
}
