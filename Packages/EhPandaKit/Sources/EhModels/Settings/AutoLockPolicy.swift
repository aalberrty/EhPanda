import Foundation

/// How long the app may stay in the background before it asks for authentication again.
/// The raw value is the delay in seconds; `.never` is `-1`.
public enum AutoLockPolicy: Int, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case never = -1
    case instantly = 0
    case sec15 = 15
    case min1 = 60
    case min5 = 300
    case min10 = 600
    case min30 = 1800

    public var id: Int { rawValue }
}
