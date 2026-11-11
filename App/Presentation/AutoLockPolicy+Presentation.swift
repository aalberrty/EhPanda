import EhModels

extension AutoLockPolicy {
    var localizedName: String {
        switch self {
        case .never: L10n.Localizable.Enum.AutoLockPolicy.Value.never
        case .instantly: L10n.Localizable.Enum.AutoLockPolicy.Value.instantly
        case .sec15: L10n.Localizable.Common.Value.seconds("\(rawValue)")
        case .min1: L10n.Localizable.Common.Value.minute("\(rawValue / 60)")
        case .min5, .min10, .min30: L10n.Localizable.Common.Value.minutes("\(rawValue / 60)")
        }
    }
}
