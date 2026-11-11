import Foundation

extension String {
    var firstLetterCapitalized: String {
        prefix(1).capitalized + dropFirst()
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
