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
        case .exhentaiAccessDenied: .personCropCircleBadgeXmark
        case .loginRequired: .personCropCircleBadgeQuestionmarkFill
        case .serverError: .serverRack
        case .notFound, .unknown, .noUpdates, .webImageFailed: .questionmarkCircleFill
        }
    }

    /// A short headline above `alertText` in full-screen error views, for the errors whose
    /// explanation is longer than a line. Legacy errors keep their single message.
    var headline: String? {
        switch self {
        case .parseFailed: L10n.Localizable.ErrorView.Headline.parseFailed
        case .exhentaiAccessDenied: L10n.Localizable.ErrorView.Headline.exhentaiAccessDenied
        case .loginRequired: L10n.Localizable.ErrorView.Headline.loginRequired
        case .serverError: L10n.Localizable.ErrorView.Headline.serverError
        case .databaseCorrupted, .copyrightClaim, .ipBanned, .expunged, .networkingFailed,
             .webImageFailed, .noUpdates, .notFound, .unknown:
            nil
        }
    }

    /// What happened and what to do about it. Stands on its own where no headline is shown
    /// (HUD captions, footers).
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
        case .exhentaiAccessDenied:
            return L10n.Localizable.ErrorView.Title.exhentaiAccessDenied
        case .loginRequired:
            return L10n.Localizable.ErrorView.Title.loginRequired
        case .serverError(let status):
            return [L10n.Localizable.ErrorView.Title.serverError("\(status)"), tryLater].joined(separator: "\n")
        case .noUpdates, .webImageFailed:
            return ""
        case .notFound:
            return L10n.Localizable.ErrorView.Title.notFound
        case .unknown:
            return [L10n.Localizable.ErrorView.Title.unknown, tryLater].joined(separator: "\n")
        }
    }
}

extension ErrorStateView {
    /// The error's headline, explanation and symbol, with an optional retry button.
    init(
        error: AppError, retryTitle: String = L10n.Localizable.ErrorView.Button.retry,
        retry: (() -> Void)? = nil
    ) {
        self.init(
            title: error.headline, message: error.alertText, systemImage: error.symbol.rawValue,
            retryTitle: retryTitle, retry: retry
        )
    }
}
