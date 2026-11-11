import Foundation

/// What a HUD shows. Present one with `.hud($configuration)`; set the binding to `nil` to hide it.
///
/// Replaces `TTProgressHUDConfig`. The presets mirror legacy `TTProgressHUD_Extension`: loading
/// HUDs stay until cleared, the others hide themselves after one second.
struct HUDConfiguration: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case loading
        case success
        case error
        /// Any SF Symbol, tinted with the accent colour.
        case symbol(String)
    }

    var kind: Kind
    var title: String?
    var caption: String?
    /// `nil` keeps the HUD up until the binding is cleared.
    var autoDismissDelay: Duration?

    init(kind: Kind, title: String? = nil, caption: String? = nil, autoDismissDelay: Duration? = nil) {
        self.kind = kind
        self.title = title
        self.caption = caption
        self.autoDismissDelay = autoDismissDelay
    }

    /// The text VoiceOver announces when the HUD appears.
    var announcement: String {
        [title, caption].compactMap(\.self).joined(separator: ", ")
    }
}

extension HUDConfiguration {
    static var loading: Self { loading(title: L10n.Localizable.Hud.Title.loading) }
    static var communicating: Self { loading(title: L10n.Localizable.Hud.Title.communicating) }
    static var error: Self { error(caption: nil) }
    static var savedToPhotoLibrary: Self { success(caption: L10n.Localizable.Hud.Caption.savedToPhotoLibrary) }
    static var copiedToClipboard: Self { success(caption: L10n.Localizable.Hud.Caption.copiedToClipboard) }

    static func loading(title: String? = nil) -> Self {
        HUDConfiguration(kind: .loading, title: title)
    }

    static func error(caption: String?) -> Self {
        autoDismissing(.error, title: L10n.Localizable.Hud.Title.error, caption: caption)
    }

    static func success(caption: String?) -> Self {
        autoDismissing(.success, title: L10n.Localizable.Hud.Title.success, caption: caption)
    }

    static func symbol(_ systemName: String, title: String? = nil, caption: String? = nil) -> Self {
        autoDismissing(.symbol(systemName), title: title, caption: caption)
    }

    static func autoDismissing(_ kind: Kind, title: String? = nil, caption: String? = nil) -> Self {
        HUDConfiguration(kind: kind, title: title, caption: caption, autoDismissDelay: Tokens.Duration.hudAutoDismiss)
    }
}
