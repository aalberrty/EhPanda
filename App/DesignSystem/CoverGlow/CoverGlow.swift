import EhCore
import EhModels
import SwiftUI

/// The cover glow: a static mesh of a gallery's cover colours behind a page (iOS 26), or what
/// v3 shows there on iOS 18.
///
/// Place it as a background; it fills what it is given and loads the palette itself, from the
/// shared `CoverPaletteStore`, so a palette Home already made shows at once. It draws once and
/// stays put while the page scrolls over it. When the gallery changes it fades to the new colours.
///
/// - `.page`: the detail page's full-screen glow, opaque, ignoring the safe area. Dark
///   appearance dims the colours toward the ground; light lifts them to a pastel wash. iOS 18:
///   the blurred cover backdrop at the top of the page.
/// - `.quiet`: a fainter glow that fades out toward its bottom edge, for Home's Popular pager.
///   Transparent, so it sits on the screen's ground. iOS 18: nothing.
struct CoverGlow: View {
    nonisolated enum Style: Sendable {
        case page
        case quiet
    }

    private let galleryID: String
    private let coverURL: URL?
    private let style: Style

    /// `coverURL` replaces the gallery's own when given, e.g. the detail's cover for a gallery
    /// opened from a link, which has none until its detail loads.
    init(gallery: Gallery, coverURL: URL? = nil, style: Style) {
        galleryID = gallery.id
        self.coverURL = coverURL ?? gallery.coverURL
        self.style = style
    }

    var body: some View {
        Group {
            if AppLook.isRedesigned {
                CoverGlowMesh(galleryID: galleryID, coverURL: coverURL, style: style)
            } else if style == .page {
                CoverBackdrop(url: coverURL)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct CoverGlowMesh: View {
    let galleryID: String
    let coverURL: URL?
    let style: CoverGlow.Style

    @Environment(CoverPaletteStore.self) private var palettes
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = palettes.palette(for: galleryID)
        let layout = CoverGlowLayout(style: style, isDark: colorScheme == .dark)
        MeshGradient(
            width: CoverGlowLayout.columns, height: layout.rows, points: layout.points,
            colors: layout.colors(for: palette)
        )
        .animation(.easeInOut(duration: 0.5), value: palette)
        .ignoresSafeArea(edges: style == .page ? .all : [])
        .task(id: coverURL) { await palettes.load(galleryID: galleryID, coverURL: coverURL) }
    }
}

/// Where each palette colour goes in the mesh and how strongly, for one style and appearance.
///
/// Modelled on E-Detail: the cover's main colour as a haze at the top centre, the first two
/// accents high on the left and right, their darker shades lower down, and the first accent
/// again along the bottom edge. Light appearance lifts every colour toward white first.
private nonisolated struct CoverGlowLayout {
    static let columns = 3

    let style: CoverGlow.Style
    let isDark: Bool

    var rows: Int {
        style == .page ? 4 : 3
    }

    var points: [SIMD2<Float>] {
        switch style {
        case .page:
            [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.28], [0.5, 0.3], [1, 0.26],
                [0, 0.62], [0.5, 0.6], [1, 0.66],
                [0, 1], [0.5, 1], [1, 1]
            ]
        case .quiet:
            [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.45], [0.5, 0.5], [1, 0.45],
                [0, 1], [0.5, 1], [1, 1]
            ]
        }
    }

    /// One (palette index, strength) per mesh point; `nil` is the bare ground.
    private var stops: [(index: Int, strength: Double)?] {
        switch (style, isDark) {
        case (.page, true):
            [
                (1, 0.62), (0, 0.30), (2, 0.66),
                (1, 0.50), (0, 0.12), (2, 0.55),
                (3, 0.52), nil, (4, 0.56),
                (3, 0.22), (1, 0.34), (4, 0.22)
            ]
        case (.page, false):
            [
                (1, 0.42), (0, 0.62), (2, 0.40),
                (1, 0.32), (0, 0.18), (2, 0.30),
                (3, 0.32), nil, (4, 0.32),
                (3, 0.14), (1, 0.24), (4, 0.14)
            ]
        case (.quiet, true):
            [
                (1, 0.42), (0, 0.16), (2, 0.48),
                (1, 0.26), (3, 0.20), (2, 0.30),
                (1, 0), (3, 0), (2, 0)
            ]
        case (.quiet, false):
            [
                (1, 0.30), (0, 0.42), (2, 0.28),
                (1, 0.18), (3, 0.16), (2, 0.20),
                (1, 0), (3, 0), (2, 0)
            ]
        }
    }

    func colors(for palette: CoverPalette?) -> [Color] {
        let ground = isDark ? Self.darkGround : Self.lightGround
        return stops.map { stop in
            guard let stop, let palette, !palette.colors.isEmpty else {
                // No palette yet: the page shows its ground, the quiet glow nothing.
                return style == .page ? ground.color : ground.color.opacity(0)
            }
            let color = toned(palette.colors[min(stop.index, palette.colors.count - 1)])
            switch style {
            case .page: return ground.mixed(with: color, by: stop.strength).color
            case .quiet: return color.color.opacity(stop.strength)
            }
        }
    }

    /// Dark: colours brighter than 75 % are dimmed, so a white or yellow cover glows rather
    /// than glares. Light: dark colours are lifted to at least 70 % brightness, so a dark cover
    /// still gives a pastel wash rather than grey.
    private func toned(_ color: CoverPalette.RGB) -> CoverPalette.RGB {
        let brightness = color.brightness
        if isDark {
            return brightness > 0.75 ? color.scaled(by: 0.75 / brightness) : color
        }
        let lifted = color.mixed(with: Self.white, by: 0.2)
        let target = 0.7
        guard lifted.brightness < target else { return lifted }
        return lifted.mixed(with: Self.white, by: (target - lifted.brightness) / (1 - lifted.brightness))
    }

    // The tokens' iOS 26 grounds (`ColorTokens.swift`), as components for mixing.
    private static let darkGround = CoverPalette.RGB(red: 16 / 255, green: 14 / 255, blue: 12 / 255)
    private static let lightGround = CoverPalette.RGB(red: 246 / 255, green: 242 / 255, blue: 235 / 255)
    private static let white = CoverPalette.RGB(red: 1, green: 1, blue: 1)
}

#Preview("Page") {
    let store = CoverPaletteStore()
    HStack(spacing: 0) {
        ForEach([ColorScheme.dark, .light], id: \.self) { scheme in
            ZStack {
                CoverGlow(gallery: .preview, style: .page)
                Text(verbatim: "Morning Light Sketchbook")
                    .font(.title2.bold())
                    .foregroundStyle(.textPrimary)
                    .padding()
                    .glassPanel()
            }
            .environment(\.colorScheme, scheme)
        }
    }
    .environment(store)
}
