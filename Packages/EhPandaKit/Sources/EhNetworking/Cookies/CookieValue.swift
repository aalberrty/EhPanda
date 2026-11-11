import EhModels

/// The value of one cookie as the account settings screen shows it.
public struct CookieValue: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        /// A live cookie with a usable value.
        case valid
        /// No unexpired cookie with a non-empty value exists.
        case notFound
        /// The cookie exists but has expired; `rawValue` is empty.
        case expired
        /// The cookie holds `CookieValueConstant.mystery`, which grants no access.
        case mystery
    }

    public static let empty = CookieValue(rawValue: "", status: .notFound)

    public let rawValue: String
    public let status: Status

    public init(rawValue: String, status: Status) {
        self.rawValue = rawValue
        self.status = status
    }

    /// A value is present but unusable.
    public var isInvalid: Bool { status != .valid && !rawValue.isEmpty }
}

/// One editable cookie row.
public struct CookieState: Equatable, Sendable {
    public static let empty = CookieState(key: "", value: .empty)

    public let key: String
    public var value: CookieValue
    public var editingText: String

    public init(key: String, value: CookieValue, editingText: String = "") {
        self.key = key
        self.value = value
        self.editingText = editingText
    }
}

/// The login cookies of one host.
public struct CookiesState: Equatable, Sendable {
    public static func empty(_ host: GalleryHost) -> Self {
        .init(host: host, igneous: .empty, memberID: .empty, passHash: .empty)
    }

    public let host: GalleryHost
    public var igneous: CookieState
    public var memberID: CookieState
    public var passHash: CookieState

    public init(host: GalleryHost, igneous: CookieState, memberID: CookieState, passHash: CookieState) {
        self.host = host
        self.igneous = igneous
        self.memberID = memberID
        self.passHash = passHash
    }

    public var allCases: [CookieState] { [igneous, memberID, passHash] }
}
