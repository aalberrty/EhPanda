import SwiftUI

// The one place that picks Liquid Glass (iOS 26) or its iOS 18 stand-in. Call sites use these
// instead of `glassEffect`, `GlassEffectContainer` or the `.glass` button styles directly.
//
// iOS 18 does not imitate Liquid Glass: every tone falls back to the material v3 uses today.

/// How strongly a glass surface is tinted, by what it sits over.
enum GlassTone {
    /// Plain Liquid Glass: floating controls over ordinary content.
    case regular
    /// Panels over the cover glow (the detail page's figures, previews, tags and comments):
    /// glass warmed toward the ground, so text on it holds while the glow shows through.
    case panel
    /// Bars and controls over bright covers (list toolbars, the reader's controls, buttons on
    /// a cover): darker glass in dark appearance, paler in light, so controls stay legible.
    case bar
}

extension View {
    /// Glass behind the view in `shape`, tinted for `tone`; on iOS 18 a material (the bar
    /// material for `.bar`) with a hairline edge. `isInteractive` makes the glass react to
    /// touches, which a material cannot.
    func glassSurface(in shape: some Shape, tone: GlassTone = .regular, isInteractive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, tone: tone, isInteractive: isInteractive))
    }

    /// A glass panel over the cover glow: `glassSurface` with the `.panel` tone in a
    /// continuous rounded rectangle (24 pt by default, as drawn in E-Detail).
    func glassPanel(cornerRadius: CGFloat = Tokens.Radius.panel) -> some View {
        glassSurface(in: .rect(cornerRadius: cornerRadius, style: .continuous), tone: .panel)
    }

    /// `.buttonStyle(.glass)`, tinted for `tone` on iOS 26.1 and later; `.bordered` on iOS 18.
    func glassButtonStyle(tone: GlassTone = .regular) -> some View {
        modifier(GlassButtonStyle(isProminent: false, tone: tone))
    }

    /// `.buttonStyle(.glassProminent)` in the tint; `.borderedProminent` on iOS 18.
    func glassProminentButtonStyle() -> some View {
        modifier(GlassButtonStyle(isProminent: true, tone: .regular))
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

@available(iOS 26, *)
private extension GlassTone {
    func glass(isInteractive: Bool = false) -> Glass {
        switch self {
        case .regular: .regular.interactive(isInteractive)
        case .panel: .regular.tint(DesignColors.glassPanelTint).interactive(isInteractive)
        case .bar: .regular.tint(DesignColors.glassBarTint).interactive(isInteractive)
        }
    }
}

private struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    let tone: GlassTone
    let isInteractive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(tone.glass(isInteractive: isInteractive), in: shape)
        } else {
            // The hairline stands in for glass's lit edge, which keeps the surface visible on
            // backgrounds close to the material's own colour.
            content
                .background(tone == .bar ? Material.bar : Material.regularMaterial, in: shape)
                .overlay { shape.stroke(.quaternary, lineWidth: 1) }
        }
    }
}

private struct GlassButtonStyle: ViewModifier {
    let isProminent: Bool
    let tone: GlassTone

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if isProminent {
                content.buttonStyle(.glassProminent)
            } else if tone == .regular {
                content.buttonStyle(.glass)
            } else if #available(iOS 26.1, *) {
                content.buttonStyle(.glass(tone.glass()))
            } else {
                // iOS 26.0 has no tinted glass button style; plain glass is the nearest.
                content.buttonStyle(.glass)
            }
        } else if isProminent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}
