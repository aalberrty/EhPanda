import EhDatabase
import EhModels
import Foundation

/// The detail feature's only access to tag translations.
///
/// A gallery has a few dozen tags, so their translations are looked up once per tag list (one
/// indexed query, off the main actor) rather than per chip while rendering.
nonisolated enum DetailTagTranslator {
    static func snapshot(for tags: [GalleryTag], database: AppDatabase) async -> TagTranslationSnapshot {
        let keys = tags.flatMap(\.contents).map(TagTranslationSnapshot.key(for:))
        guard !keys.isEmpty, let stored = try? await database.tagTranslations(keys: keys) else { return .empty }
        var displays = [String: TagTranslationDisplayValue]()
        var details = [String: TagDetail]()
        for (key, translation) in stored {
            displays[key] = TagTranslationDisplayValue(
                text: translation.displayValue, imageURL: translation.valueImageURL
            )
            details[key] = tagDetail(of: translation)
        }
        return TagTranslationSnapshot(displays: displays, details: details)
    }

    /// The tag detail sheet's content, or `nil` when the translation has no description (legacy
    /// offered "Detail" only then).
    ///
    /// The description and links are Markdown. Rendering them to plain text, images and links
    /// belongs to the tag translation service, which is not on this branch yet; until it is,
    /// no tag offers a detail sheet.
    private static func tagDetail(of translation: StoredTagTranslation) -> TagDetail? {
        nil
    }
}
