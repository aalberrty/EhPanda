import EhFeatures

// User-facing text and symbols for the reader's model types.

extension ReaderAutoPlayPolicy {
    var localizedName: String {
        switch seconds {
        case nil: L10n.Localizable.Enum.AutoPlayPolicy.Value.off
        case let seconds?: L10n.Localizable.Common.Value.seconds("\(seconds)")
        }
    }
}

extension ReaderImageAction {
    var localizedName: String {
        typealias Strings = L10n.Localizable.ReadingView.ContextMenu.Button
        return switch self {
        case .reload: Strings.reload
        case .copy: Strings.copy
        case .save: Strings.save
        case .saveOriginal: Strings.saveOriginal
        case .share: Strings.share
        }
    }

    var symbolName: String {
        switch self {
        case .reload: "arrow.counterclockwise"
        case .copy: "plus.square.on.square"
        case .save: "square.and.arrow.down"
        case .saveOriginal: "square.and.arrow.down.on.square"
        case .share: "square.and.arrow.up"
        }
    }
}

extension ReaderModel.Notice {
    var hud: HUDConfiguration {
        switch self {
        case .copiedToClipboard: .copiedToClipboard
        case .savedToPhotoLibrary: .savedToPhotoLibrary
        case .error: .error
        }
    }
}
