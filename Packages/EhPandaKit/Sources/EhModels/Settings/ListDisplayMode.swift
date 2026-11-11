import Foundation

public enum ListDisplayMode: Int, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case detail
    case thumbnail

    public var id: Int { rawValue }
}
