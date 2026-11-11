import Foundation

/// The downloaded tag translation database plus when and for which language it was fetched.
public struct TagTranslator: Codable, Sendable, Equatable, CustomStringConvertible {
    public var language: TranslatableLanguage?
    public var hasCustomTranslations: Bool
    public var updatedDate: Date
    /// Keyed by namespace raw value + tag key, e.g. `"femalebig breasts"`.
    public var translations: [String: TagTranslation]

    public init(
        language: TranslatableLanguage? = nil,
        hasCustomTranslations: Bool = false,
        updatedDate: Date = .distantPast,
        translations: [String: TagTranslation] = [:]
    ) {
        self.language = language
        self.hasCustomTranslations = hasCustomTranslations
        self.updatedDate = updatedDate
        self.translations = translations
    }

    /// Translates `word`, which is either `key` or `namespace:key`.
    ///
    /// - Parameter display: renders a translation's value as plain text; the Markdown
    ///   rendering lives outside this module.
    /// - Returns: the translated text (keeping any `namespace:` prefix) and the matching
    ///   translation, or `word` unchanged and `nil`.
    public func lookup(
        word: String, returnOriginal: Bool, display: (TagTranslation) -> String
    ) -> (String, TagTranslation?) {
        guard !returnOriginal else { return (word, nil) }
        let (lhs, rhs) = word.stringsBesideColon

        var key = rhs
        if let lhs {
            key = lhs + rhs
        }
        guard let translation = translations[key] else { return (word, nil) }

        var result = display(translation)
        if let lhs {
            result = [lhs, ":", result].joined()
        }
        return (result, translation)
    }

    public var description: String {
        let params: [String: Any] = [
            "language": language as Any,
            "updatedDate": updatedDate,
            "translationsCount": translations.count,
            "hasCustomTranslations": hasCustomTranslations
        ]
        return "TagTranslator(\(params))"
    }
}

// MARK: Legacy decoding

extension TagTranslator {
    private enum CodingKeys: String, CodingKey {
        case language, hasCustomTranslations, updatedDate, translations
    }

    // Synthesized decoding would reject JSON missing a key that has a default value.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeIfPresent(TranslatableLanguage.self, forKey: .language)
        hasCustomTranslations = try container.decodeIfPresent(Bool.self, forKey: .hasCustomTranslations) ?? false
        updatedDate = try container.decodeIfPresent(Date.self, forKey: .updatedDate) ?? .distantPast
        translations = try container.decodeIfPresent([String: TagTranslation].self, forKey: .translations) ?? [:]
    }
}
