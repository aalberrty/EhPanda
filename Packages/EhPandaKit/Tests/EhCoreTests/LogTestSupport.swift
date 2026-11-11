import Foundation
@testable import EhCore

/// A fresh temporary log directory, removed by `cleanUp()`.
struct TemporaryLogDirectory {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "EhCoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    func cleanUp() {
        try? FileManager.default.removeItem(at: url)
    }

    func makeLogger(
        minimumLevel: AppLogger.Level = .debug,
        fileLevel: AppLogger.Level = .info,
        maxFileCount: Int = LogFileSink.defaultMaxFileCount,
        maxFileSize: Int = LogFileSink.defaultMaxFileSize,
        launchedAt date: Date = Date()
    ) -> AppLogger {
        AppLogger(
            minimumLevel: minimumLevel,
            fileLevel: fileLevel,
            sink: LogFileSink(directory: url, maxFileCount: maxFileCount, maxFileSize: maxFileSize, now: { date })
        )
    }

    func writeFile(named name: String, contents: String, modified: Date) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let fileURL = url.appending(path: name)
        try Data(contents.utf8).write(to: fileURL)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: fileURL.path)
    }
}

/// Launch dates one minute apart, in order.
func launchDate(_ index: Int) -> Date {
    Date(timeIntervalSinceReferenceDate: 800_000_000 + Double(index) * 60)
}
