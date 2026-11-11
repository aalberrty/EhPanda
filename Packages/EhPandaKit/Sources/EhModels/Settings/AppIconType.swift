import Foundation

/// The app icons a user can pick. Raw values are persisted.
public enum AppIconType: Int, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case `default`
    case ukiyoe
    case developer
    case standWithUkraine2022
    // Misspelt in the legacy app; kept so ported code matches.
    case notMyPresidnet

    public var id: Int { rawValue }

    /// The alternate icon's base file name in the app bundle.
    public var filename: String {
        switch self {
        case .default: "AppIcon_Default"
        case .ukiyoe: "AppIcon_Ukiyoe"
        case .developer: "AppIcon_Developer"
        case .standWithUkraine2022: "AppIcon_StandWithUkraine2022"
        case .notMyPresidnet: "AppIcon_NotMyPresident"
        }
    }
}
