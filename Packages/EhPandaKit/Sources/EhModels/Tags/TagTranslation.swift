import Foundation

/// One entry of the EhTagTranslation database.
///
/// `value`, `description` and `linksString` are Markdown. Their plain-text and image
/// renderings are derived outside this module so they are not re-parsed on every access.
public struct TagTranslation: Codable, Sendable, Hashable {
    public let namespace: TagNamespace
    public let key: String
    public let value: String
    public var description: String?
    public var linksString: String?

    public init(
        namespace: TagNamespace,
        key: String,
        value: String,
        description: String? = nil,
        linksString: String? = nil
    ) {
        self.namespace = namespace
        self.key = key
        self.value = value
        self.description = description
        self.linksString = linksString
    }

    /// An exact-match search keyword, e.g. `f:"big breasts$"`.
    public var searchKeyword: String {
        [namespace.abbreviation ?? namespace.rawValue, ":",
         key.contains(" ") ? "\"\(key)$\"" : "\(key)$"].joined()
    }

    /// Scores this translation against `keyword`, favouring short values and prefix matches.
    public func getSuggestion(keyword: String, originalKeyword: String, matchesNamespace: Bool) -> TagSuggestion {
        func getWeight(value: String, range: Range<String.Index>) -> Float {
            namespace.weight * Float(keyword.count + 1) / Float(value.count)
                * (range.lowerBound == value.startIndex ? 2.0 : 1.0)
        }

        var weight: Float = .zero
        let keyRange = key.range(of: keyword, options: .caseInsensitive)
        let valueRange = value.range(of: keyword, options: .caseInsensitive)
        if let range = keyRange { weight += getWeight(value: key, range: range) }
        if let range = valueRange { weight += getWeight(value: value, range: range) }
        return .init(
            tag: self, weight: weight, keyRange: keyRange, valueRange: valueRange,
            originalKeyword: originalKeyword, matchesNamespace: matchesNamespace
        )
    }
}
