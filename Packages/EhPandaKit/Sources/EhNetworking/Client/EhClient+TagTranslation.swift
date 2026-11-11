import EhModels
import EhParser
import Foundation

extension EhClient {
    /// Publication date of the newest tag-translation release for `language`.
    /// Throws `AppError.noUpdates` when it is not newer than `updatedDate`.
    public func tagTranslationReleaseDate(
        language: TranslatableLanguage, after updatedDate: Date
    ) async throws -> Date {
        try await perform { builder in
            let data = try await body(builder.tagTranslatorRelease(language: language))
            return try Parser.parseTagTranslatorReleaseDate(data: data, updatedDate: updatedDate)
        }
    }

    /// Downloads and decodes the tag-translation database for `language`.
    ///
    /// The translations are returned as published; legacy's conversion to Traditional
    /// Chinese for `.traditionalChinese` is left to the caller (it needs OpenCC, in `EhCore`).
    public func tagTranslations(
        language: TranslatableLanguage
    ) async throws -> [String: TagTranslation] {
        try await perform { builder in
            let data = try await body(builder.tagTranslatorDownload(language: language))
            return try Parser.parseTagTranslations(data: data)
        }
    }
}
