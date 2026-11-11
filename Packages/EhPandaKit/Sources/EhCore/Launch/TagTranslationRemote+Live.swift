import Dependencies
import EhModels
import EhNetworking
import Foundation

extension TagTranslationRemote {
    /// The remote on top of `client`: the publish date of the latest GitHub release, then that
    /// release's `db.raw.json`.
    public static func client(_ client: EhClient) -> TagTranslationRemote {
        TagTranslationRemote(
            latestReleaseDate: { language, storedDate in
                do {
                    return try await client.tagTranslationReleaseDate(language: language, after: storedDate)
                } catch AppError.noUpdates {
                    // The service reads "not newer than the stored date" as no update.
                    return storedDate
                }
            },
            downloadDatabase: { language in
                try await client.tagTranslations(language: language)
            }
        )
    }
}

extension TagTranslationRemote: DependencyKey {
    /// Resolves `\.ehClient` per call, so it always uses the app's one network stack.
    public static let liveValue = TagTranslationRemote(
        latestReleaseDate: { language, storedDate in
            @Dependency(\.ehClient) var client
            return try await TagTranslationRemote.client(client).latestReleaseDate(language, storedDate)
        },
        downloadDatabase: { language in
            @Dependency(\.ehClient) var client
            return try await TagTranslationRemote.client(client).downloadDatabase(language)
        }
    )
}
