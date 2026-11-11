import Dependencies
import Foundation

/// Hands the legacy `TagTranslator` blob to the tag translation service.
enum LiveLegacyTagTranslations {
    // `importLegacyTranslator` logs and swallows its own failures (an unreadable blob or a
    // failed database write), so this stage cannot fail and is never retried.
    @MainActor
    static func importBlob(_ data: Data) async throws {
        @Dependency(\.tagTranslationService) var service
        await service.importLegacyTranslator(data)
    }
}
