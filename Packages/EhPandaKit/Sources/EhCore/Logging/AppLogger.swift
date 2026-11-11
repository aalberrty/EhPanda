import Dependencies
import Foundation
import os

/// The app's logger.
///
/// Every message goes to `os.Logger` (subsystem `app.ehpanda`); messages at ``fileLevel`` and
/// above are also appended to rotating files that users can attach to bug reports. Calls never
/// block on I/O and are safe from any actor. Log events, not actions, frames or cells.
///
/// ```swift
/// @ObservationIgnored @Dependency(\.appLogger) private var logger
/// logger.info("Loaded \(galleries.count) galleries", category: "Home")
/// ```
public struct AppLogger: Sendable {
    public enum Level: Int, Sendable, Comparable, CaseIterable {
        case debug, info, warning, error

        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

        var label: String {
            switch self {
            case .debug: "DEBUG"
            case .info: "INFO"
            case .warning: "WARNING"
            case .error: "ERROR"
            }
        }

        var osLogType: OSLogType {
            switch self {
            case .debug: .debug
            case .info: .info
            case .warning: .default
            case .error: .error
            }
        }
    }

    public static let subsystem = "app.ehpanda"
    public static let defaultCategory = "App"

    /// Messages below this level are dropped before their text is built.
    public var minimumLevel: Level
    /// Messages at or above this level are also written to the log files.
    public var fileLevel: Level
    let sink: LogFileSink?

    /// A logger that writes files into `directory`. Create one per directory and share it:
    /// each instance starts a new file.
    public static func live(
        directory: URL,
        minimumLevel: Level = .debug,
        fileLevel: Level = .info
    ) -> AppLogger {
        AppLogger(minimumLevel: minimumLevel, fileLevel: fileLevel, sink: LogFileSink(directory: directory))
    }

    /// A logger that only writes to `os.Logger`.
    public static func console(minimumLevel: Level = .debug) -> AppLogger {
        AppLogger(minimumLevel: minimumLevel, fileLevel: .error, sink: nil)
    }

    init(minimumLevel: Level, fileLevel: Level, sink: LogFileSink?) {
        self.minimumLevel = minimumLevel
        self.fileLevel = fileLevel
        self.sink = sink
    }

    public func log(
        _ level: Level,
        _ message: @autoclosure () -> String,
        category: String = defaultCategory,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        guard level >= minimumLevel else { return }
        let text = message()
        Logger(subsystem: Self.subsystem, category: category)
            .log(level: level.osLogType, "\(text, privacy: .public)")
        guard level >= fileLevel, let sink else { return }
        sink.write(
            LogRecord(date: Date(), level: level, category: category, fileID: "\(fileID)", line: line, message: text)
        )
    }

    public func debug(
        _ message: @autoclosure () -> String,
        category: String = defaultCategory,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        log(.debug, message(), category: category, fileID: fileID, line: line)
    }

    public func info(
        _ message: @autoclosure () -> String,
        category: String = defaultCategory,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        log(.info, message(), category: category, fileID: fileID, line: line)
    }

    public func warning(
        _ message: @autoclosure () -> String,
        category: String = defaultCategory,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        log(.warning, message(), category: category, fileID: fileID, line: line)
    }

    public func error(
        _ message: @autoclosure () -> String,
        category: String = defaultCategory,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        log(.error, message(), category: category, fileID: fileID, line: line)
    }
}

// MARK: Log files

extension AppLogger {
    /// Log files, newest first. Includes files written by the legacy app.
    public func logFiles() async -> [LogFile] {
        await sink?.logFiles() ?? []
    }

    /// Log files, newest first, each with its line count and the dates of its first and last
    /// line. Computed where the files are read, so no line reaches the caller.
    public func logSummaries() async -> [LogSummary] {
        await sink?.summaries() ?? []
    }

    /// The non-empty lines of `file`, oldest first.
    public func lines(of file: LogFile) async throws -> [String] {
        guard let sink else { return [] }
        return try await sink.lines(of: file)
    }

    public func delete(_ file: LogFile) async {
        await sink?.delete(file)
    }

    public func deleteAllLogFiles() async {
        await sink?.deleteAll()
    }

    /// Waits until every message logged so far has been written.
    public func flush() async {
        await sink?.flush()
    }
}

// MARK: Dependency

extension AppLogger: DependencyKey {
    /// The legacy location, `Documents/logs`, so files written by the old app keep showing up.
    public static var defaultDirectory: URL {
        URL.documentsDirectory.appending(path: "logs", directoryHint: .isDirectory)
    }

    #if DEBUG
    public static let liveValue = AppLogger.live(directory: defaultDirectory)
    #else
    public static let liveValue = AppLogger.live(directory: defaultDirectory, minimumLevel: .info)
    #endif

    // Logging is ambient, so tests and previews get a console-only logger instead of an
    // unimplemented one that would fail every test touching a model that logs.
    public static let testValue = AppLogger.console()
    public static let previewValue = AppLogger.console()
}

extension DependencyValues {
    public var appLogger: AppLogger {
        get { self[AppLogger.self] }
        set { self[AppLogger.self] = newValue }
    }
}
