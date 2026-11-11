import SwiftUI

/// A card's backdrop: a mesh gradient of its cover's palette over a neutral fill (legacy
/// `ColorfulView`). The mesh drifts slowly while `isAnimated` and holds still otherwise.
struct CardBackground: View {
    let palette: CardPalette?
    let isAnimated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the current animation started, so the drift begins from the resting shape.
    @State private var start = Date.now

    private var animates: Bool { isAnimated && !reduceMotion }

    var body: some View {
        ZStack {
            Rectangle().fill(.gray.opacity(0.2))
            if let palette {
                // 30 fps is plenty for a drift this slow and halves the work of the display rate.
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !animates)) { context in
                    let phase = animates ? context.date.timeIntervalSince(start) : 0
                    MeshGradient(
                        width: 3, height: 3,
                        points: Self.points(phase: phase),
                        colors: Self.colors(of: palette)
                    )
                }
                .opacity(0.75)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: palette)
        .onChange(of: animates) { _, animates in
            if animates { start = .now }
        }
        .accessibilityHidden(true)
    }

    /// A 3 × 3 mesh whose inner points circle slowly; phase 0 is the resting grid.
    private static func points(phase: TimeInterval) -> [SIMD2<Float>] {
        let first = Float(sin(phase * 0.7) * 0.2)
        let second = Float(sin(phase * 0.5 + 1) * 0.2 - sin(1) * 0.2)
        return [
            [0, 0], [0.5 + first, 0], [1, 0],
            [0, 0.5 + second], [0.5 + second, 0.5 + first], [1, 0.5 - first],
            [0, 1], [0.5 - second, 1], [1, 1]
        ]
    }

    private static func colors(of palette: CardPalette) -> [Color] {
        let colors = palette.colors.map(\.color)
        let color = { (index: Int) in colors.isEmpty ? Color.clear : colors[min(index, colors.count - 1)] }
        let background = color(0), primary = color(1), secondary = color(2), detail = color(3)
        return [
            background, primary, secondary,
            detail, primary, background,
            secondary, background, detail
        ]
    }
}

#Preview {
    let palette = CardPalette(colors: [
        .init(red: 0.9, green: 0.3, blue: 0.4), .init(red: 0.2, green: 0.4, blue: 0.9),
        .init(red: 0.9, green: 0.8, blue: 0.2), .init(red: 0.3, green: 0.8, blue: 0.5)
    ])
    VStack {
        CardBackground(palette: palette, isAnimated: true)
        CardBackground(palette: palette, isAnimated: false)
        CardBackground(palette: nil, isAnimated: false)
    }
    .padding()
    .preferredColorScheme(.dark)
}
