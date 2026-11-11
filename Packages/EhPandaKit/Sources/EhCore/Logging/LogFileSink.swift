import Foundation
import os

/// Appends log lines to the current log file on a private serial queue.
///
/// A serial `DispatchQueue` rather than an actor: callers enqueue without `await`, and FIFO
/// order keeps lines from one thread in the order they were logged.
final class LogFileSink: @unchecked Sendable {
    // @unchecked: `directory`, `maxFileCount`, `maxFileSize`, `now` and `queue` are immutable
    // and Sendable; `state` is mutable but only ever touched on `queue`.
    static let defaultMaxFileCount = 10
    static let defaultMaxFileSize = 5 * 1024 * 1024

    let directory: URL
    let maxFileCount: Int
    let maxFileSize: Int
    private let now: @Sendable () -> Date
    private let queue = DispatchQueue(label: "app.ehpanda.log-file-sink", qos: .utility)
    private let state = State()

    private final class State {
        var handle: FileHandle?
        var currentURL: URL?
        var currentSize = 0
        let lineFormatter = LogRecord.makeTimestampFormatter()
        let nameFormatter = LogFileNaming.makeFormatter()
    }

    init(
        directory: URL,
        maxFileCount: Int = defaultMaxFileCount,
        maxFileSize: Int = defaultMaxFileSize,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.directory = directory
        self.maxFileCount = max(1, maxFileCount)
        self.maxFileSize = maxFileSize
        self.now = now
    }

    deinit {
        try? state.handle?.close()
    }

    func write(_ record: LogRecord) {
        queue.async { [self] in append(record) }
    }

    func flush() async {
        await onQueue {}
    }

    func logFiles() async -> [LogFile] {
        await onQueue { LogFileNaming.list(in: self.directory, formatter: self.state.nameFormatter) }
    }

    func lines(of file: LogFile) async throws -> [String] {
        try await onQueue {
            try String(contentsOf: file.url, encoding: .utf8)
                .split(whereSeparator: \.isNewline)
                .map(String.init)
        }
    }

    func delete(_ file: LogFile) async {
        await onQueue {
            if file.url.standardizedFileURL == self.state.currentURL?.standardizedFileURL {
                self.closeCurrentFile()
            }
            try? FileManager.default.removeItem(at: file.url)
        }
    }

    func deleteAll() async {
        await onQueue {
            self.closeCurrentFile()
            for file in LogFileNaming.list(in: self.directory, formatter: self.state.nameFormatter) {
                try? FileManager.default.removeItem(at: file.url)
            }
        }
    }

    // MARK: Queue-confined

    private func onQueue<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try body() }) }
        }
    }

    private func onQueue<T: Sendable>(_ body: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: body()) }
        }
    }

    private func append(_ record: LogRecord) {
        let data = Data(record.formatted(with: state.lineFormatter).utf8)
        if state.handle == nil || (state.currentSize > 0 && state.currentSize + data.count > maxFileSize) {
            startNewFile()
        }
        guard let handle = state.handle else { return }
        do {
            try handle.write(contentsOf: data)
            state.currentSize += data.count
        } catch {
            Self.report("Failed to write log file: \(error)")
            closeCurrentFile()
        }
    }

    private func startNewFile() {
        closeCurrentFile()
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let date = now()
            var attempt = 0
            var url: URL
            repeat {
                let name = LogFileNaming.fileName(for: date, formatter: state.nameFormatter, attempt: attempt)
                url = directory.appending(path: name, directoryHint: .notDirectory)
                attempt += 1
            } while fileManager.fileExists(atPath: url.path(percentEncoded: false))
            guard fileManager.createFile(atPath: url.path(percentEncoded: false), contents: nil) else {
                Self.report("Failed to create log file at \(url.path(percentEncoded: false))")
                return
            }
            state.handle = try FileHandle(forWritingTo: url)
            state.currentURL = url
            state.currentSize = 0
            prune()
        } catch {
            Self.report("Failed to open log file: \(error)")
        }
    }

    /// Keeps the newest `maxFileCount` files, including the one just started.
    private func prune() {
        let files = LogFileNaming.list(in: directory, formatter: state.nameFormatter)
        let current = state.currentURL?.standardizedFileURL
        for file in files.dropFirst(maxFileCount) where file.url.standardizedFileURL != current {
            try? FileManager.default.removeItem(at: file.url)
        }
    }

    private func closeCurrentFile() {
        try? state.handle?.close()
        state.handle = nil
        state.currentURL = nil
        state.currentSize = 0
    }

    private static func report(_ message: String) {
        Logger(subsystem: AppLogger.subsystem, category: "Logging").error("\(message, privacy: .public)")
    }
}
