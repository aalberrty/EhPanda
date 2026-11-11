import Foundation

/// A gallery language. Raw values match the site's labels and are persisted.
public enum Language: String, Codable, Sendable, Hashable, CaseIterable {
    case invalid = "N/A"
    case other = "Other"
    case afrikaans = "Afrikaans"
    case albanian = "Albanian"
    case arabic = "Arabic"
    case bengali = "Bengali"
    case bosnian = "Bosnian"
    case bulgarian = "Bulgarian"
    case burmese = "Burmese"
    case catalan = "Catalan"
    case cebuano = "Cebuano"
    case chinese = "Chinese"
    case croatian = "Croatian"
    case czech = "Czech"
    case danish = "Danish"
    case dutch = "Dutch"
    case english = "English"
    case esperanto = "Esperanto"
    case estonian = "Estonian"
    case finnish = "Finnish"
    case french = "French"
    case georgian = "Georgian"
    case german = "German"
    case greek = "Greek"
    case hebrew = "Hebrew"
    case hindi = "Hindi"
    case hmong = "Hmong"
    case hungarian = "Hungarian"
    case indonesian = "Indonesian"
    case italian = "Italian"
    case japanese = "Japanese"
    case kazakh = "Kazakh"
    case khmer = "Khmer"
    case korean = "Korean"
    case kurdish = "Kurdish"
    case lao = "Lao"
    case latin = "Latin"
    case mongolian = "Mongolian"
    case ndebele = "Ndebele"
    case nepali = "Nepali"
    case norwegian = "Norwegian"
    case oromo = "Oromo"
    case pashto = "Pashto"
    case persian = "Persian"
    case polish = "Polish"
    case portuguese = "Portuguese"
    case punjabi = "Punjabi"
    case romanian = "Romanian"
    case russian = "Russian"
    case sango = "Sango"
    case serbian = "Serbian"
    case shona = "Shona"
    case slovak = "Slovak"
    case slovenian = "Slovenian"
    case somali = "Somali"
    case spanish = "Spanish"
    case swahili = "Swahili"
    case swedish = "Swedish"
    case tagalog = "Tagalog"
    case thai = "Thai"
    case tigrinya = "Tigrinya"
    case turkish = "Turkish"
    case ukrainian = "Ukrainian"
    case urdu = "Urdu"
    case vietnamese = "Vietnamese"
    case zulu = "Zulu"
}

extension Language {
    /// The languages the site's "excluded languages" setting lists, in its order.
    public static let allExcludedCases: [Self] = [
        .japanese, .english, .chinese, .dutch, .french, .german, .hungarian, .italian,
        .korean, .polish, .portuguese, .russian, .spanish, .thai, .vietnamese, .invalid, .other
    ]

    /// BCP 47 codes for the languages Live Text can recognise.
    public var codes: [String]? {
        switch self {
        case .english: ["en-US"]
        case .french: ["fr-FR"]
        case .italian: ["it-IT"]
        case .german: ["de-DE"]
        case .spanish: ["es-ES"]
        case .portuguese: ["pt-BR"]
        case .chinese: ["zh-Hans", "zh-Hant"]
        default: nil
        }
    }

    public var abbreviation: String {
        switch self {
        case .invalid, .other: "N/A"
        case .afrikaans: "AF"
        case .albanian: "SQ"
        case .arabic: "AR"
        case .bengali: "BN"
        case .bosnian: "BS"
        case .bulgarian: "BG"
        case .burmese: "MY"
        case .catalan: "CA"
        case .cebuano: "CEB"
        case .chinese: "ZH"
        case .croatian: "HR"
        case .czech: "CS"
        case .danish: "DA"
        case .dutch: "NL"
        case .english: "EN"
        case .esperanto: "EO"
        case .estonian: "ET"
        case .finnish: "FI"
        case .french: "FR"
        case .georgian: "KA"
        case .german: "DE"
        case .greek: "EL"
        case .hebrew: "HE"
        case .hindi: "HI"
        case .hmong: "HMN"
        case .hungarian: "HU"
        case .indonesian: "ID"
        case .italian: "IT"
        case .japanese: "JA"
        case .kazakh: "KK"
        case .khmer: "KM"
        case .korean: "KO"
        case .kurdish: "KU"
        case .lao: "LO"
        case .latin: "LA"
        case .mongolian: "MN"
        case .ndebele: "ND"
        case .nepali: "NE"
        case .norwegian: "NO"
        case .oromo: "OM"
        case .pashto: "PS"
        case .persian: "FA"
        case .polish: "PL"
        case .portuguese: "PT"
        case .punjabi: "PA"
        case .romanian: "RO"
        case .russian: "RU"
        case .sango: "SG"
        case .serbian: "SR"
        case .shona: "SN"
        case .slovak: "SK"
        case .slovenian: "SL"
        case .somali: "SO"
        case .spanish: "ES"
        case .swahili: "SW"
        case .swedish: "SV"
        case .tagalog: "TL"
        case .thai: "TH"
        case .tigrinya: "TI"
        case .turkish: "TR"
        case .ukrainian: "UK"
        case .urdu: "UR"
        case .vietnamese: "VI"
        case .zulu: "ZU"
        }
    }
}

