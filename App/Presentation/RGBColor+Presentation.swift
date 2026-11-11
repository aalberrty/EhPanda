import EhModels
import SwiftUI
import UIKit

extension RGBColor {
    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    /// The sRGB components of `color`, or `nil` when it cannot be expressed in RGB.
    init?(_ color: Color) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        self.init(red: Double(red), green: Double(green), blue: Double(blue))
    }
}
