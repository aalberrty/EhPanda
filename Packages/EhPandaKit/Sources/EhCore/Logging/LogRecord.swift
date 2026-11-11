import Foundation

/// One message bound for the log file. The date is taken at the call site, not when written.
struct LogRecord: Sendable {
    let date: Date
    let level: AppLogger.Level
    let category: String
    let fileID: String
    let line: UInt
    let message: String

    /// `2026-11-10 08:30:15.123 INFO [Reader] EhFeatures/ReaderModel.swift:42 - message`
    ///
    /// The timestamp format matches the legacy SwiftyBeaver lines so both parse alike.
    /// Newlines are escaped so one record is always one line.
    func formatted(with formatter: DateFormatter) -> String {
        let text = message
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\(formatter.string(from: date)) \(level.label) [\(category)] \(fileID):\(line) - \(text)\n"
    }

    static func makeTimestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }
}
