import Foundation

// Small helpers several targets of the package share; `package` keeps them out of the app.

extension String {
    package var firstLetterCapitalized: String {
        prefix(1).capitalized + dropFirst()
    }

    /// Whether the whole string is one link, as `NSDataDetector` sees it (legacy `isValidURL`).
    package var isValidURL: Bool {
        guard let detector = LinkDetector.shared,
              let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: utf16.count))
        else { return false }
        return match.range.length == utf16.count
    }

    /// `"namespace:key"` → `("namespace", "key")`; anything else → `(nil, self)`.
    var stringsBesideColon: (String?, String) {
        let strings = split(separator: ":").map(String.init)
        if strings.count == 2, !strings[0].isEmpty {
            return (strings[0], strings[1])
        }
        return (nil, self)
    }

    /// Repeatedly removes the first `opening…closing` span.
    func removingSpans(from opening: String, to closing: String) -> String {
        var result = self
        while let rangeA = result.range(of: opening),
              let rangeB = result.range(of: closing),
              rangeA.lowerBound < rangeB.upperBound
        {
            let unwanted = result[rangeA.lowerBound..<rangeB.upperBound]
            result = result.replacingOccurrences(of: unwanted, with: "")
        }
        return result
    }
}

private enum LinkDetector {
    // `NSRegularExpression` (and its `NSDataDetector` subclass) is immutable and documented
    // safe to use from several threads at once, so one instance serves every caller.
    static let shared = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )
}

extension URL {
    /// Appends query items the way the legacy `URL.appending(queryItems:)` did: through
    /// `URLComponents.queryItems`, which escapes `&`, `=` and `#` in values but leaves `+`
    /// as is, keeping any items already present. An empty list, or a URL that cannot be
    /// decomposed, leaves the URL untouched (no trailing `?`).
    package func appendingQueryItems(_ queryItems: [URLQueryItem]) -> URL {
        guard !queryItems.isEmpty,
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else { return self }
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url ?? self
    }
}

enum TitleTrimming {
    /// The part of a gallery title before the first `|`, without bracketed groups such as
    /// `[Artist]` or `(Event)`, trimmed of surrounding whitespace.
    static func trimmed(_ title: String) -> String {
        var title = title
        if let range = title.range(of: "|") {
            title = String(title[..<range.lowerBound])
        }
        return title
            .removingSpans(from: "(", to: ")")
            .removingSpans(from: "[", to: "]")
            .removingSpans(from: "{", to: "}")
            .removingSpans(from: "【", to: "】")
            .removingSpans(from: "「", to: "」")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
