import Foundation

/// The failures the app shows to the user. Presentation (symbol, alert text) lives in the app.
public enum AppError: Error, Sendable, Identifiable, Hashable {
    case databaseCorrupted(String?)
    case copyrightClaim(String)
    case ipBanned(BanInterval)
    case expunged(String)
    case networkingFailed
    case webImageFailed
    /// The site answered with something the app could not read and did not recognise.
    case parseFailed
    /// ExHentai did not accept the session: it answers a missing, stale or unentitled login
    /// with an empty page (or, in older versions, an image) instead of content.
    case exhentaiAccessDenied
    /// The page needs a login and the site sent its login prompt instead: there is no login,
    /// or it has expired.
    case loginRequired
    /// The server failed with this HTTP status and sent no readable page.
    case serverError(Int)
    case noUpdates
    case notFound
    case unknown

    public var id: String { localizedDescription }
}

extension AppError {
    /// Whether retrying the failed operation could succeed. A login problem is retryable
    /// because the user can fix it (log in again, switch hosts) and then retry.
    public var isRetryable: Bool {
        switch self {
        case .databaseCorrupted, .ipBanned, .networkingFailed, .parseFailed,
             .exhentaiAccessDenied, .loginRequired, .serverError,
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
        case .exhentaiAccessDenied: "ExHentai Access Denied"
        case .loginRequired: "Login Required"
        case .serverError(let status): "Server Error \(status)"
        case .noUpdates: "No updates available"
        case .notFound: "Not found"
        case .unknown: "Unknown Error"
        }
    }
}
