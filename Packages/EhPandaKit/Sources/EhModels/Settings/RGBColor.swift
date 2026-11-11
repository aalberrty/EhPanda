import Foundation

/// An opaque sRGB colour with components in `0...1`.
///
/// Encodes as `{"red", "green", "blue"}`, the shape the legacy app used for SwiftUI colours,
/// so persisted accent and tag colours keep decoding.
public struct RGBColor: Codable, Sendable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Parses a six-digit hex string such as `"FF8800"` (no `#`).
    public init?(hex: String) {
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// The iOS system blue, the legacy default accent colour.
    public static let systemBlue = RGBColor(red: 0, green: 122 / 255, blue: 1)

    /// Whether dark text reads better on this colour than white text.
    ///
    /// Same perceived-brightness rule the legacy parser used to pick tag text colours.
    public var isLight: Bool {
        (red * 0.299 + green * 0.587 + blue * 0.114) * 255 > 151
    }
}
