import Foundation

/// Hands the legacy `TagTranslator` blob to the tag translation service.
enum LiveLegacyTagTranslations {
    struct Unavailable: Error, CustomStringConvertible {
        var description: String { "The tag translation service is not available in this build." }
    }

    // TODO(tag-translation-service): call the service's legacy import once it is merged.
    // Until then the stage fails, so the old store is kept and the import retried next launch.
    @MainActor
    static func importBlob(_ data: Data) async throws {
        throw Unavailable()
    }
}
