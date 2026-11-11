import EhModels

extension FilterRange {
    var localizedName: String {
        switch self {
        case .search: L10n.Localizable.Enum.FilterRange.Value.search
        case .global: L10n.Localizable.Enum.FilterRange.Value.global
        case .watched: L10n.Localizable.Enum.FilterRange.Value.watched
        }
    }
}
