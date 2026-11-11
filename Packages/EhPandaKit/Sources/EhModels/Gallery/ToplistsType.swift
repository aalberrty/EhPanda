import Foundation

/// The toplist periods the site publishes.
public enum ToplistsType: Int, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case yesterday
    case pastMonth
    case pastYear
    case allTime

    public var id: Int { rawValue }

    /// The site's `tl` query value for this toplist.
    public var categoryIndex: Int {
        switch self {
        case .yesterday: 15
        case .pastMonth: 13
        case .pastYear: 12
        case .allTime: 11
        }
    }
}
