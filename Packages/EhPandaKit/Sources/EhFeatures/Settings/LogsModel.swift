import Dependencies
import EhCore
import EhModels
import Foundation
import Observation

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
        // The logger reads the files on its own queue; only the summaries arrive here.
        let summaries = await logger.logSummaries()
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
