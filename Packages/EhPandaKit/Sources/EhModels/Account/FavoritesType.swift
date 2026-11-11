import Foundation

/// A favorites folder, or all of them. Raw values are the site's `favcat` identifiers.
public enum FavoritesType: String, Codable, Sendable, Hashable, CaseIterable {
    case all = "all"
    case favorite0 = "favorite_0"
    case favorite1 = "favorite_1"
    case favorite2 = "favorite_2"
    case favorite3 = "favorite_3"
    case favorite4 = "favorite_4"
    case favorite5 = "favorite_5"
    case favorite6 = "favorite_6"
    case favorite7 = "favorite_7"
    case favorite8 = "favorite_8"
    case favorite9 = "favorite_9"

    public static func getTypeFrom(index: Int) -> FavoritesType {
        allCases.first(where: { $0.index == index }) ?? .all
    }

    /// The folder number 0–9, or `-1` for `.all`.
    public var index: Int {
        Int(rawValue.replacingOccurrences(of: "favorite_", with: "")) ?? -1
    }
}
