import SwiftUI

// The one place that picks Liquid Glass (iOS 26) or its iOS 18 stand-in. Call sites use these
// instead of `glassEffect`, `GlassEffectContainer` or the `.glass` button styles directly.

extension View {
    /// Glass behind the view in `shape`; a regular material with a hairline edge on iOS 18.
    /// `isInteractive` makes the glass react to touches, which a material cannot.
    func glassSurface(in shape: some Shape, isInteractive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, isInteractive: isInteractive))
    }

    /// `.buttonStyle(.glass)`; `.bordered` on iOS 18.
    func glassButtonStyle() -> some View {
        modifier(GlassButtonStyle(isProminent: false))
    }

    /// `.buttonStyle(.glassProminent)`; `.borderedProminent` on iOS 18.
    func glassProminentButtonStyle() -> some View {
        modifier(GlassButtonStyle(isProminent: true))
    }
}

/// A `GlassEffectContainer`, so neighbouring glass shapes blend; a plain group on iOS 18.
struct GlassGroup<Content: View>: View {
    private let spacing: CGFloat?
    private let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

private struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    let isInteractive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(isInteractive), in: shape)
        } else {
            // The hairline stands in for glass's lit edge, which keeps the surface visible on
            // backgrounds close to the material's own colour.
            content
                .background(.regularMaterial, in: shape)
                .overlay { shape.stroke(.quaternary, lineWidth: 1) }
        }
    }
}

private struct GlassButtonStyle: ViewModifier {
    let isProminent: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if isProminent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else if isProminent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}
