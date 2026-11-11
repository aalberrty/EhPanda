import EhModels

extension AppIconType {
    var localizedName: String {
        switch self {
        case .default: L10n.Localizable.Enum.AppIconType.Value.default
        case .ukiyoe: L10n.Localizable.Enum.AppIconType.Value.ukiyoe
        case .developer: L10n.Localizable.Enum.AppIconType.Value.developer
        case .standWithUkraine2022: L10n.Localizable.Enum.AppIconType.Value.standWithUkraine2022
        case .notMyPresidnet: L10n.Localizable.Enum.AppIconType.Value.notMyPresident
        }
    }
}
