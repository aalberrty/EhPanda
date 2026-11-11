import Foundation

/// One of the user's settings profiles on the site's settings page.
public struct EhProfile: Comparable, Identifiable, Hashable, Sendable {
    public var id: Int { value }

    public let value: Int
    public let name: String
    public let isSelected: Bool

    public init(value: Int, name: String, isSelected: Bool) {
        self.value = value
        self.name = name
        self.isSelected = isSelected
    }

    public static let empty = EhProfile(value: 0, name: "", isSelected: true)

    public static func < (lhs: EhProfile, rhs: EhProfile) -> Bool {
        lhs.value < rhs.value
    }

    /// The site's default profile, which cannot be deleted.
    public var isDefault: Bool {
        value == 1
    }
}

/// A profile operation; the raw value is the site's `profile_action` form value.
public enum EhProfileAction: String, Sendable, Hashable {
    case create
    case delete
    case rename
    case `default`
}

/// Whether the app's own settings profile exists on the site.
public struct VerifyEhProfileResponse: Sendable, Equatable {
    /// The value of the EhPanda profile, when one exists.
    public let profileValue: Int?
    public let isProfileNotFound: Bool

    public init(profileValue: Int?, isProfileNotFound: Bool) {
        self.profileValue = profileValue
        self.isProfileNotFound = isProfileNotFound
    }
}
