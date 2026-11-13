import EhModels
import SwiftUI
import UIKit

extension RGBColor {
    /// The tint the app uses for this accent colour setting.
    ///
    /// On iOS 26 the setting's default (system blue) gives the redesign's tint instead: bone in
    /// dark, ink in light. Any other colour the user picked wins, on both systems. iOS 18 keeps
    /// v3's behaviour and always uses the setting.
    nonisolated var appTint: Color {
        Color(uiColor: appTintUIColor)
    }

    /// `appTint` for UIKit (window tints).
    nonisolated var appTintUIColor: UIColor {
        guard AppLook.isRedesigned, isDefaultAccent else {
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        }
        return DesignColors.defaultTint
    }

    /// Whether this is the setting's default. Within half a step of 8 bits, so a value that went
    /// through a hex string or the legacy import still counts.
    private nonisolated var isDefaultAccent: Bool {
        let tolerance = 0.5 / 255
        let defaultAccent = RGBColor.systemBlue
        return abs(red - defaultAccent.red) < tolerance && abs(green - defaultAccent.green) < tolerance
            && abs(blue - defaultAccent.blue) < tolerance
    }
}
