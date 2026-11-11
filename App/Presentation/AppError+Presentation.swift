import EhModels
import SFSafeSymbols

// `Error` types are nonisolated even under the target's default MainActor isolation;
// these members read `L10n`, which is MainActor-isolated, and are only used by views.
@MainActor
extension AppError {
    var symbol: SFSymbol {
        switch self {
        case .databaseCorrupted: .exclamationmarkTriangleFill
        case .ipBanned: .networkBadgeShieldHalfFilled
        case .copyrightClaim, .expunged: .trashCircleFill
        case .networkingFailed: .wifiExclamationmark
        case .parseFailed: .rectangleAndTextMagnifyingglass
        case .notFound, .unknown, .noUpdates, .webImageFailed: .questionmarkCircleFill
        }
    }

    var alertText: String {
        let tryLater = L10n.Localizable.ErrorView.Title.tryLater
        switch self {
        case .databaseCorrupted(let reason):
            var lines = [L10n.Localizable.ErrorView.Title.databaseCorrupted]
            if let reason {
                lines.append("(\(reason))")
            }
            return lines.joined(separator: "\n")
        case .copyrightClaim(let owner):
            return L10n.Localizable.ErrorView.Title.copyrightClaim(owner)
        case .ipBanned(let interval):
            return L10n.Localizable.ErrorView.Title.ipBanned(interval.localizedDescription)
        case .expunged(let reason):
            return reason == L10n.Constant.Website.Response.galleryUnavailable
                ? L10n.Localizable.ErrorView.Title.galleryUnavailable : reason
        case .networkingFailed:
            return [L10n.Localizable.ErrorView.Title.network, tryLater].joined(separator: "\n")
        case .parseFailed:
            return [L10n.Localizable.ErrorView.Title.parsing, tryLater].joined(separator: "\n")
        case .noUpdates, .webImageFailed:
            return ""
        case .notFound:
            return L10n.Localizable.ErrorView.Title.notFound
        case .unknown:
            return [L10n.Localizable.ErrorView.Title.unknown, tryLater].joined(separator: "\n")
        }
    }
}
