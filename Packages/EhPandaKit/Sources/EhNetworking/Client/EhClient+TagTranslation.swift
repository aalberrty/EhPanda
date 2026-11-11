import EhModels
import Foundation

extension EhClient {
    /// Publication date of the newest tag-translation release for `language`.
    /// Throws `AppError.noUpdates` when it is not newer than `updatedDate`.
    public func tagTranslationReleaseDate(
        language: TranslatableLanguage, after updatedDate: Date
    ) async throws -> Date {
        throw AppError.unknown
    }

    /// Downloads and decodes the tag-translation database for `language`.
    public func tagTranslations(
        language: TranslatableLanguage
    ) async throws -> [String: TagTranslation] {
        throw AppError.unknown
    }
}
