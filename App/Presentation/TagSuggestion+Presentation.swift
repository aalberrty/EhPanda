import EhModels

extension TagSuggestion {
    /// `namespace:key` as Markdown, with the matched part (and a matched namespace) linked
    /// so it renders in the accent colour.
    var displayKey: String {
        let namespace = tag.namespace.rawValue
        let parts = Self.segments(of: tag.key, around: keyRange)
        return [
            matchesNamespace ? namespace.linkStyled : namespace, ":",
            parts.before, parts.match.isEmpty ? "" : parts.match.linkStyled, parts.after
        ].joined()
    }

    /// `displayText` (the plain-text rendering of `tag.value`) as Markdown with the matched
    /// part linked.
    func displayValue(for displayText: String) -> String {
        let parts = Self.segments(of: displayText, around: valueRange)
        return [parts.before, parts.match.isEmpty ? "" : parts.match.linkStyled, parts.after].joined()
    }
}

private extension String {
    var linkStyled: String {
        "[\(self)](\(GalleryHost.ehentai.url.absoluteString))"
    }
}
