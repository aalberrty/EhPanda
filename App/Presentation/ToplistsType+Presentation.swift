import EhModels

extension ToplistsType {
    var localizedName: String {
        switch self {
        case .yesterday: L10n.Localizable.Enum.ToplistsType.Value.yesterday
        case .pastMonth: L10n.Localizable.Enum.ToplistsType.Value.pastMonth
        case .pastYear: L10n.Localizable.Enum.ToplistsType.Value.pastYear
        case .allTime: L10n.Localizable.Enum.ToplistsType.Value.allTime
        }
    }
}
