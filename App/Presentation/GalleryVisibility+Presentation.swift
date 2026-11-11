import EhModels

extension GalleryVisibility {
    var localizedName: String {
        switch self {
        case .yes:
            return L10n.Localizable.Enum.GalleryVisibility.Value.yes
        case .no(let reason):
            let localizedReason = switch reason {
            case "Expunged": L10n.Localizable.Enum.GalleryVisibility.Value.No.Reason.expunged
            default: reason
            }
            return L10n.Localizable.Enum.GalleryVisibility.Value.no(localizedReason)
        }
    }
}
