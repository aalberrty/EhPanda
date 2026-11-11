import EhModels
import Foundation

/// What legacy kept next to the translations in `TagTranslator`, persisted in `UserDefaults`.
public struct TagTranslationMetadata: Sendable, Equatable {
    /// The language of the stored database; `nil` before the first download and for custom
    /// translations.
    public var language: TranslatableLanguage?
    /// The publish date of the stored release; `.distantPast` when none.
    public var updatedDate: Date
    /// The stored translations were imported from a file and must not be replaced by downloads.
    public var hasCustomTranslations: Bool

    public init(
        language: TranslatableLanguage? = nil, updatedDate: Date = .distantPast, hasCustomTranslations: Bool = false
    ) {
        self.language = language
        self.updatedDate = updatedDate
        self.hasCustomTranslations = hasCustomTranslations
    }

    private enum Key {
        static let language = "tagTranslation.language"
        static let updatedDate = "tagTranslation.updatedDate"
        static let hasCustomTranslations = "tagTranslation.hasCustomTranslations"
    }

    init(defaults: UserDefaults) {
        self.init(
            language: defaults.string(forKey: Key.language).flatMap { code in
                TranslatableLanguage.allCases.first { $0.languageCode == code }
            },
            updatedDate: (defaults.object(forKey: Key.updatedDate) as? Date) ?? .distantPast,
            hasCustomTranslations: defaults.bool(forKey: Key.hasCustomTranslations)
        )
    }

    func save(to defaults: UserDefaults) {
        defaults.set(language?.languageCode, forKey: Key.language)
        defaults.set(updatedDate, forKey: Key.updatedDate)
        defaults.set(hasCustomTranslations, forKey: Key.hasCustomTranslations)
    }
}

/// The settings screen's view of a download or import.
public enum TagTranslationLoadingState: Sendable, Equatable {
    case idle
    case loading
    case failed(TagTranslationError)
}

public enum TagTranslationError: Error, Sendable, Equatable {
    /// The stored database is already the latest release.
    case noUpdates
    /// The download or the picked file was not a database, or it was empty.
    case parseFailed
    case networkingFailed
    /// Reading or writing the app database failed.
    case databaseFailed
}
