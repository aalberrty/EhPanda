import Foundation

// Ports of the legacy `Extensions.swift` helpers the parser uses. String and URL helpers shared
// with other targets live in `EhModels`.

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
