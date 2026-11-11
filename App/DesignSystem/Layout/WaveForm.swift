import SwiftUI

/// The animated wave behind the login screen (legacy `WaveForm`).
///
/// Drawn with `Canvas` on the animation timeline; the timeline pauses under Reduce Motion. Stack
/// two with different amplitudes and directions, and add `.drawingGroup()` around them.
struct WaveForm: View {
    private let color: Color
    private let amplitude: CGFloat
    private let isReversed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(color: Color, amplitude: CGFloat, isReversed: Bool = false) {
        self.color = color
        self.amplitude = amplitude
        self.isReversed = isReversed
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { [color, amplitude, isReversed] context, size in
                // One wave period scrolls across the width every four seconds.
                let phase = timeline.date.timeIntervalSinceReferenceDate.remainder(dividingBy: 4)
                let offset = phase * size.width / 4
                let path = Self.wavePath(in: size, amplitude: amplitude)

                context.translateBy(x: isReversed ? -offset : offset, y: 0)
                context.fill(path, with: .color(color))
                context.translateBy(x: -size.width, y: 0)
                context.fill(path, with: .color(color))
                context.translateBy(x: size.width * 2, y: 0)
                context.fill(path, with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }

    nonisolated private static func wavePath(in size: CGSize, amplitude: CGFloat) -> Path {
        Path { path in
            let midHeight = size.height / 2
            path.move(to: CGPoint(x: 0, y: midHeight))
            path.addCurve(
                to: CGPoint(x: size.width, y: midHeight),
                control1: CGPoint(x: size.width * 0.4, y: midHeight + amplitude),
                control2: CGPoint(x: size.width * 0.65, y: midHeight - amplitude)
            )
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
        }
    }
}

private struct WaveFormPreview: View {
    var body: some View {
        ZStack {
            WaveForm(color: Color(.systemGray2).opacity(0.2), amplitude: 100, isReversed: true)
            WaveForm(color: Color(.systemGray).opacity(0.2), amplitude: 120)
        }
        .drawingGroup()
        .frame(height: 300)
    }
}

#Preview {
    SchemePreview { WaveFormPreview() }
}
