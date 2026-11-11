import Foundation

// Ports of the legacy `Extensions.swift` helpers the parser uses.

extension Data {
    /// The bytes up to the first NUL, with invalid UTF-8 sequences replaced by U+FFFD.
    ///
    /// Legacy built a C string from the bytes (`String(cString:)`), which stops at the first
    /// NUL and repairs invalid sequences the same way; this avoids its read past the buffer.
    var utf8InvalidCharactersRipped: Data {
        let bytes = prefix { $0 != 0 }
        return Data(String(decoding: bytes, as: UTF8.self).utf8)
    }
}

extension String {
    var firstLetterCapitalized: String {
        prefix(1).capitalized + dropFirst()
    }

    /// Whether the whole string is one link, as `NSDataDetector` sees it.
    var isValidURL: Bool {
        guard let detector = LinkDetector.shared,
              let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: utf16.count))
        else { return false }
        return match.range.length == utf16.count
    }
}

private enum LinkDetector {
    // `NSRegularExpression` (and its `NSDataDetector` subclass) is immutable and documented
    // safe to use from several threads at once.
    static let shared = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )
}

extension URL {
    /// Appends query items, keeping any already present. Returns `self` when the URL cannot
    /// be decomposed (legacy force-unwrapped there).
    func appendingQueryItems(_ queryItems: [URLQueryItem]) -> URL {
        guard !queryItems.isEmpty,
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else { return self }
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url ?? self
    }
}

/// Query keys the parser reads or writes (legacy `Defaults.URL.Component.Key`).
enum QueryKey {
    static let next = "next"
    static let skipServerIdentifier = "nl"
}

/// Site images the list parser must not mistake for covers (legacy `Defaults.URL`).
enum SiteImageURL {
    static let torrentDownload = "https://ehgt.org/g/t.png"
    static let torrentDownloadInvalid = "https://ehgt.org/g/td.png"
}
