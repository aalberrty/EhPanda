import Foundation

public enum PreferredColorScheme: Int, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    public var id: Int { rawValue }
}
