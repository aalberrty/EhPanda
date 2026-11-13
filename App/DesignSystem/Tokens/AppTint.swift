import EhModels
import SwiftUI
import UIKit

extension RGBColor {
    /// The tint the app uses for this accent colour setting.
    ///
    /// On iOS 26 the setting's default (system blue) gives the redesign's tint instead: bone in
    /// dark, ink in light. Any other colour the user picked wins, on both systems. iOS 18 keeps
    /// v3's behaviour and always uses the setting.
    var appTint: Color {
        Color(uiColor: appTintUIColor)
    }

    /// Text and symbols on a fill of `appTint`: the ground colour on the redesign's bone and ink
    /// tint, white on an accent colour, as before.
    var appTintForeground: Color {
        AppLook.isRedesigned && isDefaultAccent ? DesignColors.onSelectedFill : .white
    }

    /// `appTint` for UIKit (window tints).
    var appTintUIColor: UIColor {
        guard AppLook.isRedesigned, isDefaultAccent else {
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        }
        return DesignColors.defaultTint
    }

    /// Whether this is the setting's default, system blue. Legacy stored its default
    /// (`Color.blue`) resolved for the appearance and system it ran on, so every variant counts:
    /// light, dark and high contrast, as iOS 18 and earlier drew them and as this system does.
    private var isDefaultAccent: Bool {
        let tolerance = 1.5 / 255
        return Self.defaultAccentVariants.contains { variant in
            abs(red - variant.red) < tolerance && abs(green - variant.green) < tolerance
                && abs(blue - variant.blue) < tolerance
        }
    }

    private static let defaultAccentVariants: [RGBColor] = {
        // System blue up to iOS 18: light, dark, and both with Increase Contrast.
        var variants: [RGBColor] = [
            .systemBlue, RGBColor(hex: "0A84FF"), RGBColor(hex: "0040DD"), RGBColor(hex: "409CFF")
        ].compactMap(\.self)
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection { traits in
                    traits.userInterfaceStyle = style
                    traits.accessibilityContrast = contrast
                }
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                if UIColor.systemBlue.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                    variants.append(RGBColor(red: red, green: green, blue: blue))
                }
            }
        }
        return variants
    }()
}
