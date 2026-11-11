import EhModels
import UIKit

extension PreferredColorScheme {
    var localizedName: String {
        switch self {
        case .automatic: L10n.Localizable.Enum.PreferredColorScheme.Value.automatic
        case .light: L10n.Localizable.Enum.PreferredColorScheme.Value.light
        case .dark: L10n.Localizable.Enum.PreferredColorScheme.Value.dark
        }
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .automatic: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}
