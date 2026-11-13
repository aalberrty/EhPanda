import SwiftUI
import UIKit

// The semantic colours of the redesign, usable wherever a `Color` or a `ShapeStyle` goes:
// `.background(.ground)`, `.foregroundStyle(.textSecondary)`, `Color.hairline`.
//
// On iOS 26 they are the warm palette of the mockups (dark: warm near-black ground and bone
// text; light: warm off-white ground and ink text), with stronger values under Increase
// Contrast. On iOS 18 each resolves to the system colour v3 uses today, so that look stays.
nonisolated extension ShapeStyle where Self == Color {
    /// Behind a whole screen. iOS 18: `systemBackground`.
    static var ground: Color { DesignColors.ground }
    /// Behind a grouped list (Settings, forms). The same warm ground on iOS 26; iOS 18:
    /// `systemGroupedBackground`.
    static var groundGrouped: Color { DesignColors.groundGrouped }
    /// A card or sheet raised off the ground (the long-press peek). iOS 18: `secondarySystemBackground`.
    static var raised: Color { DesignColors.raised }
    /// A row of a grouped list. iOS 18: `secondarySystemGroupedBackground`.
    static var raisedGrouped: Color { DesignColors.raisedGrouped }

    /// Titles and body text. iOS 18: `label`.
    static var textPrimary: Color { DesignColors.textPrimary }
    /// Supporting text: uploader, meta lines, "Show all", the category name. iOS 18: `secondaryLabel`.
    static var textSecondary: Color { DesignColors.textSecondary }
    /// Quieter labels that must still be read: tag namespaces, chip prefixes. iOS 18:
    /// `secondaryLabel`, because `tertiaryLabel` is too faint for text.
    static var textTertiary: Color { DesignColors.textTertiary }

    /// Separators and dividers. iOS 18: `separator`.
    static var hairline: Color { DesignColors.hairline }
    /// Unselected chips and tag pills. iOS 18: `tertiarySystemFill`, as `TagChip` uses today.
    static var chipFill: Color { DesignColors.chipFill }
    /// A selected chip or segment: bone in dark, ink in light. iOS 18: `label`.
    static var selectedFill: Color { DesignColors.selectedFill }
    /// Text on `selectedFill`. iOS 18: `systemBackground`.
    static var onSelectedFill: Color { DesignColors.onSelectedFill }
    /// The faint ring around covers that lifts them off the ground. iOS 18: clear (no ring).
    static var coverEdge: Color { DesignColors.coverEdge }
}

/// The values behind the tokens above, and the glass tints `Glass.swift` reads.
nonisolated enum DesignColors {
    static let ground = dynamic(dark: .init(0x100E0C), light: .init(0xF6F2EB), legacy: .systemBackground)
    static let groundGrouped = dynamic(dark: .init(0x100E0C), light: .init(0xF6F2EB), legacy: .systemGroupedBackground)
    static let raised = dynamic(dark: .init(0x1C1917), light: .init(0xFFFCF7), legacy: .secondarySystemBackground)
    static let raisedGrouped = dynamic(
        dark: .init(0x1C1917), light: .init(0xFFFCF7), legacy: .secondarySystemGroupedBackground
    )

    static let textPrimary = dynamic(dark: .init(0xF4EFE7), light: .init(0x1A1612), legacy: .label)
    static let textSecondary = dynamic(
        dark: .init(0xCFC7BC), light: .init(0x574F46),
        darkHighContrast: .init(0xE4DDD3), lightHighContrast: .init(0x3F3832), legacy: .secondaryLabel
    )
    static let textTertiary = dynamic(
        dark: .init(0xB3AA9F), light: .init(0x61594F),
        darkHighContrast: .init(0xCFC7BC), lightHighContrast: .init(0x4A433B), legacy: .secondaryLabel
    )

    static let hairline = dynamic(
        dark: .init(0xF4EFE7, alpha: 0.12), light: .init(0x1A1612, alpha: 0.12),
        darkHighContrast: .init(0xF4EFE7, alpha: 0.28), lightHighContrast: .init(0x1A1612, alpha: 0.28),
        legacy: .separator
    )
    static let chipFill = dynamic(
        dark: .init(0xF4EFE7, alpha: 0.10), light: .init(0x1A1612, alpha: 0.07),
        darkHighContrast: .init(0xF4EFE7, alpha: 0.18), lightHighContrast: .init(0x1A1612, alpha: 0.14),
        legacy: .tertiarySystemFill
    )
    static let selectedFill = dynamic(dark: .init(0xF4EFE7), light: .init(0x1A1612), legacy: .label)
    static let onSelectedFill = dynamic(dark: .init(0x100E0C), light: .init(0xF6F2EB), legacy: .systemBackground)
    static let coverEdge = dynamic(
        dark: .init(0xF4EFE7, alpha: 0.10), light: .init(0x1A1612, alpha: 0.06), legacy: .clear
    )

    /// The ring around a category dot: at least 3:1 against the ground in both appearances, so
    /// dots whose colour is close to the ground (Image Set in dark, Artist CG in light) still show.
    /// The same on iOS 18, which needs it for the same dots.
    static let categoryRing = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(Swatch(0xF4EFE7, alpha: 0.4)) : UIColor(Swatch(0x1A1612, alpha: 0.5))
    })

    /// The redesign's default tint: bone in dark, ink in light (iOS 26 only, see `AppTint`).
    static let defaultTint = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(Swatch(0xF4EFE7)) : UIColor(Swatch(0x1A1612))
    }

    /// Glass over the cover glow (the detail page's panels), warmed toward the ground so text
    /// on it holds while the glow shows through.
    static let glassPanelTint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(Swatch(0x16120F, alpha: 0.34)) : UIColor(Swatch(0xFFFFFF, alpha: 0.5))
    })
    /// Glass of bars and controls that sit over bright covers (list toolbars, the reader):
    /// darker in dark, paler in light, so bone and ink controls stay legible on any cover.
    static let glassBarTint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(Swatch(0x16120F, alpha: 0.62)) : UIColor(Swatch(0xF6F2EB, alpha: 0.62))
    })

    /// An sRGB hex colour.
    struct Swatch: Sendable {
        let hex: UInt32
        let alpha: CGFloat

        init(_ hex: UInt32, alpha: CGFloat = 1) {
            self.hex = hex
            self.alpha = alpha
        }

        var red: CGFloat { CGFloat((hex >> 16) & 0xFF) / 255 }
        var green: CGFloat { CGFloat((hex >> 8) & 0xFF) / 255 }
        var blue: CGFloat { CGFloat(hex & 0xFF) / 255 }
    }

    /// The redesign's colour on iOS 26, `legacy` on iOS 18.
    private static func dynamic(
        dark: Swatch, light: Swatch, darkHighContrast: Swatch? = nil, lightHighContrast: Swatch? = nil,
        legacy: UIColor
    ) -> Color {
        guard AppLook.isRedesigned else { return Color(uiColor: legacy) }
        return Color(uiColor: UIColor { traits in
            let isHighContrast = traits.accessibilityContrast == .high
            let swatch = traits.userInterfaceStyle == .dark
                ? (isHighContrast ? darkHighContrast ?? dark : dark)
                : (isHighContrast ? lightHighContrast ?? light : light)
            return UIColor(swatch)
        })
    }
}

extension UIColor {
    nonisolated convenience init(_ swatch: DesignColors.Swatch) {
        self.init(red: swatch.red, green: swatch.green, blue: swatch.blue, alpha: swatch.alpha)
    }
}
