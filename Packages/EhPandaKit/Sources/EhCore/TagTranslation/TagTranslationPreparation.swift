import EhDatabase
import EhModels
import Foundation
import OpenCC

/// Pure transformations between downloaded translations, stored rows and what the UI shows.
///
/// Everything here is synchronous and CPU-bound; call it from a `@concurrent` context, never
/// from the main actor.
public enum TagTranslationPreparation {
    /// Converts to Traditional Chinese when `preferredLanguages` is given, then prepares rows,
    /// in parallel chunks with one OpenCC converter and URL detector each.
    @concurrent
    public static func prepare(
        _ translations: [String: TagTranslation], traditionalChineseFor preferredLanguages: [String]?
    ) async -> [StoredTagTranslation] {
        let entries = Array(translations)
        let chunkCount = min(max(ProcessInfo.processInfo.activeProcessorCount, 1), 8, max(entries.count / 2_000, 1))
        let chunkSize = max((entries.count + chunkCount - 1) / chunkCount, 1)
        return await withTaskGroup(of: [StoredTagTranslation].self) { group in
            for start in stride(from: 0, to: entries.count, by: chunkSize) {
                let chunk = entries[start..<min(start + chunkSize, entries.count)]
                // Created here, one at a time: SwiftyOpenCC's dictionary cache is not safe to
                // fill concurrently. Each converter is then used by its task alone.
                let converter = preferredLanguages.flatMap(traditionalChineseConverter(preferredLanguages:))
                group.addTask { prepareChunk(chunk, converter: converter) }
            }
            var rows = [StoredTagTranslation]()
            rows.reserveCapacity(entries.count)
            for await chunkRows in group { rows += chunkRows }
            return rows
        }
    }

    private static func prepareChunk(
        _ entries: ArraySlice<(key: String, value: TagTranslation)>, converter: ChineseConverter?
    ) -> [StoredTagTranslation] {
        entries.map { key, translation in
            let translation = converter.map { traditionalChineseConverted(translation, with: $0) } ?? translation
            let (displayValue, imageURL) = TagMarkdown.display(of: translation.value)
            return StoredTagTranslation(
                key: key, translation: translation, displayValue: displayValue, valueImageURL: imageURL
            )
        }
    }

    /// Legacy `displayValue` and `valueImageURL` of one translation.
    public static func display(of translation: TagTranslation) -> TagTranslationDisplay {
        let (text, imageURL) = TagMarkdown.display(of: translation.value)
        return TagTranslationDisplay(displayValue: text, valueImageURL: imageURL)
    }

    /// What the tag detail sheet shows, or `nil` when the translation has no description text
    /// (legacy offered the detail only then).
    public static func detail(of stored: StoredTagTranslation) -> TagDetail? {
        guard let description = descriptionPlainText(of: stored.translation), !description.isEmpty else {
            return nil
        }
        return TagDetail(
            title: stored.displayValue,
            description: description,
            imageURLs: stored.translation.description.map { TagMarkdown.images($0) } ?? [],
            links: stored.translation.linksString.map(TagMarkdown.links) ?? []
        )
    }

    /// Legacy `descriptionPlainText`: back-ticks become spaces so that tag names written as
    /// code stay in the text, then every top-level text node is joined without separators.
    public static func descriptionPlainText(of translation: TagTranslation) -> String? {
        translation.description.map { TagMarkdown.texts($0.replacingOccurrences(of: "`", with: " ")).joined() }
    }

    /// Legacy `descriptionImageURLs`.
    public static func descriptionImageURLs(of translation: TagTranslation) -> [URL] {
        translation.description.map { TagMarkdown.images($0) } ?? []
    }

    /// Legacy `links`.
    public static func links(of translation: TagTranslation) -> [URL] {
        translation.linksString.map(TagMarkdown.links) ?? []
    }
}

// MARK: Traditional Chinese

extension TagTranslationPreparation {
    /// The OpenCC options legacy used for the user's most preferred language: Hong Kong or
    /// Taiwan standard when the language mentions the region, plain traditionalisation otherwise.
    static func traditionalChineseOptions(preferredLanguage: String) -> ChineseConverter.Options {
        if preferredLanguage.contains("HK") {
            [.traditionalize, .hkStandard]
        } else if preferredLanguage.contains("TW") {
            [.traditionalize, .twStandard, .twIdiom]
        } else {
            [.traditionalize]
        }
    }

    static func traditionalChineseConverter(preferredLanguages: [String]) -> ChineseConverter? {
        guard let preferredLanguage = preferredLanguages.first else { return nil }
        return try? ChineseConverter(options: traditionalChineseOptions(preferredLanguage: preferredLanguage))
    }

    static func traditionalChineseConverted(
        _ translation: TagTranslation, with converter: ChineseConverter
    ) -> TagTranslation {
        // OpenCC's dictionaries hold only CJK text, so ASCII values convert to themselves.
        let isASCII = translation.value.utf8.allSatisfy { $0 < 0x80 }
        var value = isASCII ? translation.value : converter.convert(translation.value)
        // A fix-up legacy applied after conversion.
        if value == "full color" { value = "全彩" }
        return TagTranslation(
            namespace: translation.namespace, key: translation.key, value: value,
            description: translation.description, linksString: translation.linksString
        )
    }

    /// Legacy `chtConverted`: converts each translation's value (not its description or links)
    /// from the Simplified Chinese database. Returns `translations` unchanged when there is no
    /// preferred language or the converter cannot be created.
    public static func traditionalChineseConverted(
        _ translations: [String: TagTranslation], preferredLanguages: [String]
    ) -> [String: TagTranslation] {
        guard let converter = traditionalChineseConverter(preferredLanguages: preferredLanguages) else {
            return translations
        }
        return translations.mapValues { traditionalChineseConverted($0, with: converter) }
    }
}
