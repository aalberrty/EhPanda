import Foundation

/// A gallery category. Raw values match the site's labels and are persisted.
public enum Category: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case doujinshi = "Doujinshi"
    case manga = "Manga"
    case artistCG = "Artist CG"
    case gameCG = "Game CG"
    case western = "Western"
    case nonH = "Non-H"
    case imageSet = "Image Set"
    case cosplay = "Cosplay"
    case asianPorn = "Asian Porn"
    case misc = "Misc"
    case `private` = "Private"

    public var id: String { rawValue }

    /// The order the favorites page lists categories in.
    public static let allFavoritesCases: [Self] = [.misc] + allCases.dropLast(2)
    /// Every category a search filter can toggle (all but `.private`).
    public static let allFiltersCases: [Self] = Array(allCases.dropLast())

    /// The bit this category occupies in the site's `f_cats` filter mask.
    ///
    /// `.private` is never part of a filter; asking for its value is a programming error.
    public var filterValue: Int {
        switch self {
        case .doujinshi: 2
        case .manga: 4
        case .artistCG: 8
        case .gameCG: 16
        case .western: 512
        case .nonH: 256
        case .imageSet: 32
        case .cosplay: 64
        case .asianPorn: 128
        case .misc: 1
        case .private: preconditionFailure("`Private` doesn't have a `filterValue`!")
        }
    }
}
