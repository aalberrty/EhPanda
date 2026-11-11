import Foundation

/// The site's date formats (legacy `Defaults.DateFormat`).
enum DateFormat {
    static let publish = "yyyy-MM-dd HH:mm"
    static let torrent = "yyyy-MM-dd HH:mm"
    static let comment = "dd MMMM yyyy, HH:mm"
    static let github = "yyyy-MM-dd'T'HH:mm:ss'Z'"
}

/// Cached UTC, `en_US_POSIX` formatters. Legacy created one per call, often inside loops.
enum DateFormatters {
    // `DateFormatter` is documented thread-safe for parsing since iOS 7 / macOS 10.9, and
    // these instances are never mutated after creation.
    private static let publish = make(format: DateFormat.publish)
    private static let comment = make(format: DateFormat.comment)
    private static let github = make(format: DateFormat.github)

    static func formatter(format: String) -> DateFormatter {
        switch format {
        case DateFormat.publish: publish // also `DateFormat.torrent`
        case DateFormat.comment: comment
        case DateFormat.github: github
        default: make(format: format)
        }
    }

    private static func make(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
