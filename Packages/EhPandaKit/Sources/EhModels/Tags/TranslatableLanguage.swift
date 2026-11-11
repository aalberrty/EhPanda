import Foundation

/// The languages the tag translation database is available in.
/// Persisted in Swift's synthesized enum form, e.g. `{"simplifiedChinese":{}}`.
public enum TranslatableLanguage: Codable, Sendable, Hashable, CaseIterable {
    case english
    case japanese
    case simplifiedChinese
    case traditionalChinese
}

extension TranslatableLanguage {
    /// The first translatable language matching the user's most preferred language.
    public static var current: TranslatableLanguage? {
        Locale.preferredLanguages.first.flatMap(matching(preferredLanguage:))
    }

    /// The translatable language whose code appears in `preferredLanguage`, e.g. `zh-Hans-CN`.
    public static func matching(preferredLanguage: String) -> TranslatableLanguage? {
        allCases.first { preferredLanguage.contains($0.languageCode) }
    }

    public var languageCode: String {
        switch self {
        case .english: "en"
        case .japanese: "ja"
        case .simplifiedChinese: "zh-Hans"
        case .traditionalChinese: "zh-Hant"
        }
    }

    /// The GitHub repository (`owner/name`) that publishes this language's database.
    public var repoName: String {
        switch self {
        case .english: "EhPanda-Team/EhTagTranslation_Database_EN"
        case .japanese: "EhPanda-Team/EhTagTranslation_Database_JPN"
        case .simplifiedChinese, .traditionalChinese: "EhTagTranslation/Database"
        }
    }

    /// The release asset to download from `repoName`.
    public var remoteFilename: String {
        "db.raw.json"
    }
}
