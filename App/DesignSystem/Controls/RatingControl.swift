import SwiftUI

/// The detail screen's "give a rating" stars: drag or tap to pick, release to submit
/// (legacy `ActionSection` + `DetailReducer.updateRating`).
///
/// `rating` counts half stars, 1...10, like the site's API and legacy `userRating`. While the
/// finger moves the binding updates; on release `onCommit` receives the final value. The star
/// width comes from the control's own bounds rather than legacy's hard-coded 31 pt, so it works
/// with any font size. VoiceOver users swipe up or down to adjust; each step commits.
struct RatingControl: View {
    @Binding private var rating: Int
    private let onCommit: (Int) -> Void

    @State private var width: CGFloat = 0
    @State private var commitCount = 0

    init(rating: Binding<Int>, onCommit: @escaping (Int) -> Void) {
        _rating = rating
        self.onCommit = onCommit
    }

    var body: some View {
        RatingStars(
            rating: Double(rating) / 2,
            accessibilityLabel: L10n.Localizable.DetailView.ActionSection.Button.giveARating
        )
        .symbolEffect(.bounce, value: commitCount)
        .contentShape(.rect)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { rating = value(at: $0.location.x) }
                .onEnded { commit(value(at: $0.location.x)) }
        )
        .sensoryFeedback(.selection, trigger: rating)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: commit(min(rating + 1, 10))
            case .decrement: commit(max(rating - 1, 1))
            @unknown default: break
            }
        }
    }

    /// Each star is split in two: its leading half is the half-star value.
    private func value(at x: CGFloat) -> Int {
        guard width > 0 else { return rating }
        let halfStars = Int((x / (width / 5) * 2).rounded(.down)) + 1
        return min(max(halfStars, 1), 10)
    }

    private func commit(_ value: Int) {
        rating = value
        commitCount += 1
        onCommit(value)
    }
}

private struct RatingControlPreview: View {
    @State private var rating = 7
    @State private var committed: Int?

    var body: some View {
        VStack(spacing: Tokens.Spacing.medium) {
            RatingControl(rating: $rating) { committed = $0 }
                .font(.title)
                .foregroundStyle(.yellow)
            Text(verbatim: "rating \(rating), committed \(committed.map(String.init) ?? "–")")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SchemePreview { RatingControlPreview() }
}
