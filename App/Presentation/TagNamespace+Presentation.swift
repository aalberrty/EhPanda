import EhModels

extension TagNamespace {
    var localizedName: String {
        switch self {
        case .reclass: L10n.Localizable.Enum.TagNamespace.Value.reclass
        case .language: L10n.Localizable.Enum.TagNamespace.Value.language
        case .parody: L10n.Localizable.Enum.TagNamespace.Value.parody
        case .character: L10n.Localizable.Enum.TagNamespace.Value.character
        case .group: L10n.Localizable.Enum.TagNamespace.Value.group
        case .artist: L10n.Localizable.Enum.TagNamespace.Value.artist
        case .male: L10n.Localizable.Enum.TagNamespace.Value.male
        case .female: L10n.Localizable.Enum.TagNamespace.Value.female
        case .mixed: L10n.Localizable.Enum.TagNamespace.Value.mixed
        case .cosplayer: L10n.Localizable.Enum.TagNamespace.Value.cosplayer
        case .other: L10n.Localizable.Enum.TagNamespace.Value.other
        case .temp: L10n.Localizable.Enum.TagNamespace.Value.temp
        }
    }
}
