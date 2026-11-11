import EhModels
import Foundation
import GRDB

/// A tag translation as stored, with the values legacy derived from Markdown on every access
/// precomputed once by the importer.
public struct StoredTagTranslation: Sendable, Hashable {
    /// The key legacy's `TagTranslator.translations` dictionary used: namespace + tag.
    public var key: String
    public var translation: TagTranslation
    /// The plain text of `translation.value`, or the value itself if it has none.
    public var displayValue: String
    /// The first image in `translation.value`'s Markdown.
    public var valueImageURL: URL?

    public init(key: String, translation: TagTranslation, displayValue: String, valueImageURL: URL?) {
        self.key = key
        self.translation = translation
        self.displayValue = displayValue
        self.valueImageURL = valueImageURL
    }

    /// `nil` if the stored namespace is no longer a known `TagNamespace`.
    init?(row: Row) {
        guard let namespace = TagNamespace(rawValue: row["namespace"]) else { return nil }
        self.init(
            key: row["key"],
            translation: TagTranslation(
                namespace: namespace,
                key: row["tag"],
                value: row["value"],
                description: row["description"],
                linksString: row["linksString"]
            ),
            displayValue: row["displayValue"],
            valueImageURL: row["valueImageURL"]
        )
    }

    var databaseArguments: StatementArguments {
        [
            key, translation.namespace.rawValue, translation.key, translation.value,
            displayValue, valueImageURL?.absoluteString,
            translation.description, translation.linksString
        ]
    }
}

/// What rendering a translated tag needs, kept in memory for every tag.
public struct TagTranslationDisplay: Sendable, Hashable {
    public var displayValue: String
    public var valueImageURL: URL?

    public init(displayValue: String, valueImageURL: URL?) {
        self.displayValue = displayValue
        self.valueImageURL = valueImageURL
    }
}
