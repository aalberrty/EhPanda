import SwiftUI

/// Five stars showing a 0–5 rating in half-star steps (legacy `RatingView`).
///
/// Size and colour come from the environment: `.font(.caption).foregroundStyle(.yellow)`.
/// VoiceOver reads it as one element, e.g. "Average rating, 3.5/5".
struct RatingStars: View {
    private let rating: Double
    private let label: String

    init(rating: Double, accessibilityLabel: String = L10n.Localizable.GalleryInfosView.Title.averageRating) {
        self.rating = Self.halfRounded(rating)
        label = accessibilityLabel
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: Self.symbolName(forStar: index, rating: rating))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Self.accessibilityValue(for: rating))
    }

    /// Rounds to the nearest half like legacy `Float.halfRounded` (x.25 rounds up to x.5).
    static func halfRounded(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max((value * 2).rounded() / 2, 0), 5)
    }

    static func symbolName(forStar index: Int, rating: Double) -> String {
        let remaining = rating - Double(index)
        if remaining >= 1 { return "star.fill" }
        if remaining >= 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }

    static func accessibilityValue(for rating: Double) -> String {
        rating.formatted(.number.precision(.fractionLength(0...1))) + "/5"
    }
}

private struct RatingStarsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            ForEach(Array(stride(from: 0.0, through: 5.0, by: 0.5)), id: \.self) { rating in
                HStack {
                    RatingStars(rating: rating).foregroundStyle(.yellow)
                    Text(rating, format: .number).font(.caption).foregroundStyle(.secondary)
                }
            }
            RatingStars(rating: 3.74).font(.caption).foregroundStyle(.primary)
        }
    }
}

#Preview {
    SchemePreview { RatingStarsPreview() }
}
