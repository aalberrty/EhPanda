import EhModels

extension ReadingDirection {
    var localizedName: String {
        switch self {
        case .vertical: L10n.Localizable.Enum.ReadingDirection.Value.vertical
        case .rightToLeft: L10n.Localizable.Enum.ReadingDirection.Value.rightToLeft
        case .leftToRight: L10n.Localizable.Enum.ReadingDirection.Value.leftToRight
        }
    }
}
