import Dependencies
import EhModels
import Foundation

/// Where the tag translation database comes from (GitHub releases in the app).
///
/// Both closures run off the main actor and should honour task cancellation.
public struct TagTranslationRemote: Sendable {
    /// The publish date of the latest database release for a language. The stored date of the
    /// current copy is passed so an implementation may answer from a conditional request; it
    /// returns that date (or an earlier one) when it knows nothing newer exists.
    public var latestReleaseDate: @Sendable (_ language: TranslatableLanguage, _ storedDate: Date) async throws -> Date
    /// Downloads and decodes the database for a language, keyed as `TagTranslator` stores
    /// translations (`EhTagTranslationDatabaseResponse.tagTranslations`).
    public var downloadDatabase: @Sendable (_ language: TranslatableLanguage) async throws -> [String: TagTranslation]

    public init(
        latestReleaseDate: @escaping @Sendable (TranslatableLanguage, Date) async throws -> Date,
        downloadDatabase: @escaping @Sendable (TranslatableLanguage) async throws -> [String: TagTranslation]
    ) {
        self.latestReleaseDate = latestReleaseDate
        self.downloadDatabase = downloadDatabase
    }
}

extension TagTranslationRemote: TestDependencyKey {
    public static let testValue = TagTranslationRemote(
        latestReleaseDate: unimplemented("TagTranslationRemote.latestReleaseDate"),
        downloadDatabase: unimplemented("TagTranslationRemote.downloadDatabase")
    )

    /// Never has updates, so previews keep whatever is stored.
    public static let previewValue = TagTranslationRemote(
        latestReleaseDate: { _, storedDate in storedDate },
        downloadDatabase: { _ in [:] }
    )
}

extension DependencyValues {
    public var tagTranslationRemote: TagTranslationRemote {
        get { self[TagTranslationRemote.self] }
        set { self[TagTranslationRemote.self] = newValue }
    }
}
