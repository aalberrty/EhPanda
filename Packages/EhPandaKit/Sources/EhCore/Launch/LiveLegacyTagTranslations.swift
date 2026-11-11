import Dependencies
import Foundation

/// Hands the legacy `TagTranslator` blob to the tag translation service.
enum LiveLegacyTagTranslations {
    // An unreadable blob is skipped (retrying could not help). A failed database write
    // throws, so the migrator keeps the legacy store and retries this stage next launch.
    @MainActor
    static func importBlob(_ data: Data) async throws {
        @Dependency(\.tagTranslationService) var service
        try await service.importLegacyTranslator(data)
    }
}
