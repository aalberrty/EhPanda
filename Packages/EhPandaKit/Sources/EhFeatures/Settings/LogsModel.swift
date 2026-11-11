import Dependencies
import EhCore
import EhModels
import Foundation
import Observation

/// One row of the Logs screen: a log file and what its lines say about it.
nonisolated public struct LogSummary: Sendable, Hashable, Identifiable {
    public let file: LogFile
    /// Number of non-empty lines.
    public let recordCount: Int
    /// The date part (`yyyy-MM-dd`) of the first and last line, when the lines start with one.
    public let firstDate: String?
    public let lastDate: String?

    public var id: String { file.id }

    public init(file: LogFile, lines: [String]) {
        self.file = file
        recordCount = lines.count
        firstDate = lines.first.flatMap(Self.datePart)
        lastDate = lines.last.flatMap(Self.datePart)
    }

    /// Lines written by both the new logger and legacy SwiftyBeaver start with
    /// `yyyy-MM-dd HH:mm:ss.SSS`; legacy showed the text before the first space.
    static func datePart(of line: String) -> String? {
        guard let space = line.firstIndex(of: " ") else { return nil }
        let date = line[..<space]
        return date.isEmpty ? nil : String(date)
    }
}

/// The Logs screen: the log files on disk, newest first.
@Observable
public final class LogsModel {
    public private(set) var logs: [LogSummary] = []
    public private(set) var loadingState: LoadingState = .idle

    @ObservationIgnored @Dependency(\.appLogger) private var logger
    @ObservationIgnored @Dependency(\.applicationClient) private var application

    public init() {}

    /// The newest log, labelled "Latest".
    public var latestLog: LogFile? { logs.first?.file }

    public func load() async {
        guard !loadingState.isLoading else { return }
        loadingState = .loading
        // The logger reads files on its own queue; only the summaries arrive here.
        var summaries = [LogSummary]()
        for file in await logger.logFiles() {
            guard !Task.isCancelled else { break }
            let lines = (try? await logger.lines(of: file)) ?? []
            summaries.append(LogSummary(file: file, lines: lines))
        }
        guard !Task.isCancelled else {
            loadingState = .idle
            return
        }
        logs = summaries
        loadingState = .idle
    }

    public func delete(_ log: LogSummary) async {
        logs.removeAll { $0.id == log.id }
        await logger.delete(log.file)
    }

    /// Opens the logs folder in the Files app (the app shares its Documents folder).
    public func openLogsFolder() async {
        guard let url = Self.filesAppURL(for: AppLogger.defaultDirectory) else { return }
        _ = await application.openURL(url)
    }

    nonisolated static func filesAppURL(for directory: URL) -> URL? {
        URL(string: "shareddocuments://" + directory.path(percentEncoded: true))
    }
}

/// The log viewer: every line of one log file.
@Observable
public final class LogDetailModel {
    public let file: LogFile
    public private(set) var lines: [String] = []
    public private(set) var loadingState: LoadingState = .idle

    @ObservationIgnored @Dependency(\.appLogger) private var logger

    public init(file: LogFile) {
        self.file = file
    }

    public func load() async {
        guard !loadingState.isLoading else { return }
        loadingState = .loading
        do {
            let lines = try await logger.lines(of: file)
            guard !Task.isCancelled else {
                loadingState = .idle
                return
            }
            self.lines = lines
            loadingState = .idle
        } catch {
            loadingState = .failed(.notFound)
        }
    }
}
