import Foundation

/// The failures the app shows to the user. Presentation (symbol, alert text) lives in the app.
public enum AppError: Error, Sendable, Identifiable, Hashable {
    case databaseCorrupted(String?)
    case copyrightClaim(String)
    case ipBanned(BanInterval)
    case expunged(String)
    case networkingFailed
    case webImageFailed
    case parseFailed
    case noUpdates
    case notFound
    case unknown

    public var id: String { localizedDescription }
}

extension AppError {
    /// Whether retrying the failed operation could succeed.
    public var isRetryable: Bool {
        switch self {
        case .databaseCorrupted, .ipBanned, .networkingFailed, .parseFailed,
             .noUpdates, .notFound, .unknown, .webImageFailed:
            true
        case .copyrightClaim, .expunged:
            false
        }
    }

    /// A short English summary for identity and logs; not shown to the user.
    public var localizedDescription: String {
        switch self {
        case .databaseCorrupted: "Database Corrupted"
        case .copyrightClaim: "Copyright Claim"
        case .ipBanned: "IP Banned"
        case .expunged: "Gallery Expunged"
        case .networkingFailed: "Network Error"
        case .webImageFailed: "Web image loading error"
        case .parseFailed: "Parse Error"
        case .noUpdates: "No updates available"
        case .notFound: "Not found"
        case .unknown: "Unknown Error"
        }
    }
}
