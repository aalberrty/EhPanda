import EhModels

extension ArchiveResolution {
    var localizedName: String {
        switch self {
        case .x780, .x980, .x1280, .x1600, .x2400: rawValue
        case .original: L10n.Localizable.Enum.ArchiveResolution.Value.original
        }
    }
}

extension GalleryArchive.HathArchive {
    var price: String {
        switch gpPrice {
        case "Free": L10n.Localizable.Struct.HathArchive.Price.free
        default: gpPrice
        }
    }
}
