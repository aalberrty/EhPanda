import EhModels
import SwiftUI

// The Objective-C runtime also exports a `Category` type. Declaring the name in this module
// makes it win over both imports, so app code can keep writing plain `Category`.
typealias Category = EhModels.Category

extension Category {
    /// The category colour from the asset catalog; each host has its own palette.
    func color(for host: GalleryHost) -> Color {
        Color("\(host.rawValue)/\(rawValue)")
    }

    var localizedName: String {
        switch self {
        case .doujinshi: L10n.Localizable.Enum.Category.Value.doujinshi
        case .manga: L10n.Localizable.Enum.Category.Value.manga
        case .artistCG: L10n.Localizable.Enum.Category.Value.artistCG
        case .gameCG: L10n.Localizable.Enum.Category.Value.gameCG
        case .western: L10n.Localizable.Enum.Category.Value.western
        case .nonH: L10n.Localizable.Enum.Category.Value.nonH
        case .imageSet: L10n.Localizable.Enum.Category.Value.imageSet
        case .cosplay: L10n.Localizable.Enum.Category.Value.cosplay
        case .asianPorn: L10n.Localizable.Enum.Category.Value.asianPorn
        case .misc: L10n.Localizable.Enum.Category.Value.misc
        case .private: L10n.Localizable.Enum.Category.Value.private
        }
    }
}
