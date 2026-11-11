import SwiftUI

/// Stand-in for a cover or preview while it loads (legacy `Placeholder(style: .activity)`).
///
/// With an aspect ratio it sizes itself like the image it replaces; with `nil` it fills whatever
/// it is proposed. `.activity` shows a spinner, which Core Animation drives off the render loop
/// and stays cheap in long lists; `.shimmer` sweeps a highlight and suits short, skeleton-like
/// screens.
struct ImagePlaceholder: View {
    enum Style {
        case activity
        case shimmer
        case plain
        /// The load failed: a static fill with a photo symbol.
        case failure
    }

    private let aspectRatio: CGFloat?
    private let cornerRadius: CGFloat
    private let style: Style

    init(aspectRatio: CGFloat? = Tokens.Aspect.cover, cornerRadius: CGFloat = Tokens.Radius.image, style: Style = .activity) {
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
        self.style = style
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.fill.tertiary)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                switch style {
                case .activity:
                    ProgressView()
                case .failure:
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                case .shimmer, .plain:
                    EmptyView()
                }
            }
            .shimmering(style == .shimmer)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Sweeps a soft highlight across the view while `isActive`. Stops under Reduce Motion.
    func shimmering(_ isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

private struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive, !reduceMotion {
            content.overlay { ShimmerHighlight().mask(content) }
        } else {
            content
        }
    }
}

private struct ShimmerHighlight: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.35), .clear],
            startPoint: .leading, endPoint: .trailing
        )
        // `visualEffect` reads the size without a GeometryReader and without affecting layout.
        .visualEffect { [phase] content, proxy in
            content.offset(x: proxy.size.width * phase)
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

private struct PlaceholdersPreview: View {
    var body: some View {
        VStack(spacing: Tokens.Spacing.large) {
            HStack(spacing: Tokens.Spacing.small) {
                ImagePlaceholder().frame(width: 72)
                ImagePlaceholder(style: .shimmer).frame(width: 72)
                ImagePlaceholder(style: .plain).frame(width: 72)
                ImagePlaceholder(style: .failure).frame(width: 72)
            }
            Text(verbatim: "Skeleton title line")
                .font(.headline)
                .redacted(reason: .placeholder)
                .shimmering()
        }
    }
}

#Preview {
    SchemePreview { PlaceholdersPreview() }
}
