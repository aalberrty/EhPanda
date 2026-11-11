import EhModels

extension ListDisplayMode {
    var localizedName: String {
        switch self {
        case .detail: L10n.Localizable.Enum.ListDisplayMode.Value.detail
        case .thumbnail: L10n.Localizable.Enum.ListDisplayMode.Value.thumbnail
        }
    }
}
