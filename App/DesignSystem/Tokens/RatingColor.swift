import SwiftUI

nonisolated extension ShapeStyle where Self == Color {
    /// Rating stars. On iOS 26 they take the text colour (bone in dark, ink in light), since
    /// colour comes only from covers and category marks; iOS 18 keeps v3's yellow.
    static var rating: Color { AppLook.isRedesigned ? .textPrimary : .yellow }
}
