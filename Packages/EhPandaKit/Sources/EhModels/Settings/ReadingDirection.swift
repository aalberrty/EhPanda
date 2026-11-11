import Foundation

public enum ReadingDirection: Int, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case vertical
    case rightToLeft
    case leftToRight

    public var id: Int { rawValue }
}
