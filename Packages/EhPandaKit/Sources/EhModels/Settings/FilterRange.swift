import Foundation

/// Which of the app's three filters a change applies to.
public enum FilterRange: Int, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case search
    case global
    case watched

    public var id: Int { rawValue }
}
