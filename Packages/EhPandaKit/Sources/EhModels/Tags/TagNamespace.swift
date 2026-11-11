import Foundation

public enum TagNamespace: String, Codable, Sendable, Hashable, CaseIterable {
    case reclass
    case language
    case parody
    case character
    case group
    case artist
    case male
    case female
    case mixed
    case cosplayer
    case other
    case temp

    /// Raw value → search abbreviation, for every namespace that has one.
    public static let abbreviations: [String: String] = .init(
        uniqueKeysWithValues: allCases.compactMap { namespace in
            namespace.abbreviation.map { (namespace.rawValue, $0) }
        }
    )
}

extension TagNamespace {
    /// How strongly a match in this namespace ranks among tag suggestions.
    public var weight: Float {
        switch self {
        case .reclass: 1
        case .language: 2
        case .parody: 3.3
        case .character: 2.8
        case .group: 2.2
        case .artist: 2.5
        case .male: 8.5
        case .female: 9
        case .mixed: 8
        case .cosplayer: 2.4
        case .other: 10
        case .temp: 0.1
        }
    }

    /// The short prefix the site accepts in searches, e.g. `f` for `female`.
    public var abbreviation: String? {
        switch self {
        case .reclass: "r"
        case .language: "l"
        case .parody: "p"
        case .character: "c"
        case .group: "g"
        case .artist: "a"
        case .male: "m"
        case .female: "f"
        case .mixed: "x"
        case .cosplayer: "cos"
        case .other: "o"
        case .temp: nil
        }
    }
}
