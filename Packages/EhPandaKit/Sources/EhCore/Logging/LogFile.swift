import Foundation

/// A log file on disk, for the Logs screen.
public struct LogFile: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let url: URL
    /// When the file was started (from its name), or last modified for legacy files.
    public let date: Date
    /// Size in bytes.
    public let size: Int
}

/// File naming shared by the sink and the listing.
///
/// New files are `EhPanda-yyyyMMdd-HHmmss-SSS.log`, one per launch (a new one is also started
/// past ``LogFileSink/maxFileSize``). The legacy app's SwiftyBeaver files are `EhPanda.log` and
/// `EhPanda.log.1` … `EhPanda.log.9`; they are listed and pruned along with the new ones.
enum LogFileNaming {
    static let prefix = "EhPanda-"
    static let suffix = ".log"
    static let legacyName = "EhPanda.log"
    private static let stampLength = "yyyyMMdd-HHmmss-SSS".count

    static func makeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter
    }

    static func fileName(for date: Date, formatter: DateFormatter, attempt: Int) -> String {
        let stamp = formatter.string(from: date)
        return prefix + stamp + (attempt == 0 ? "" : "-\(attempt)") + suffix
    }

    static func isLegacy(_ name: String) -> Bool {
        name == legacyName || name.hasPrefix(legacyName + ".")
    }

    /// The start date encoded in a new-style name, or `nil` if `name` is not one.
    static func date(fromName name: String, formatter: DateFormatter) -> Date? {
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
        let stamp = name.dropFirst(prefix.count).prefix(stampLength)
        return formatter.date(from: String(stamp))
    }

    /// Log files in `directory`, newest first.
    static func list(in directory: URL, formatter: DateFormatter) -> [LogFile] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: .skipsHiddenFiles
        )) ?? []
        let files = urls.compactMap { url -> LogFile? in
            let name = url.lastPathComponent
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true
            else { return nil }
            let date: Date
            if let nameDate = Self.date(fromName: name, formatter: formatter) {
                date = nameDate
            } else if isLegacy(name) {
                date = values.contentModificationDate ?? .distantPast
            } else {
                return nil
            }
            return LogFile(name: name, url: url, date: date, size: values.fileSize ?? 0)
        }
        return files.sorted { lhs, rhs in
            lhs.date != rhs.date ? lhs.date > rhs.date : lhs.name > rhs.name
        }
    }
}
