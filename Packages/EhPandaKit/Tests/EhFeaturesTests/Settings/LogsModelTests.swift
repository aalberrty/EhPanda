import Dependencies
import EhCore
import EhFeatures
import EhTestSupport
import Foundation
import Testing

@Suite struct LogsModelTests {
    private func makeLogger() throws -> (AppLogger, URL) {
        let directory = try TestDatabase.makeTemporaryDirectory()
        return (AppLogger.live(directory: directory, fileLevel: .info), directory)
    }

    @Test func listsLogFilesWithTheirRecordCountAndDates() async throws {
        let (logger, directory) = try makeLogger()
        defer { try? FileManager.default.removeItem(at: directory) }
        logger.info("first")
        logger.error("second")
        logger.debug("not written to the file")
        await logger.flush()
        let legacyLines = "2024-01-02 10:00:00.000 INFO a\n2024-01-03 11:00:00.000 INFO b\n\n2024-01-04 12:00:00.000 c\n"
        let legacyFile = directory.appending(path: "EhPanda.log.1")
        try legacyLines.write(to: legacyFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: legacyFile.path()
        )

        let model = withDependencies { $0.appLogger = logger } operation: { LogsModel() }
        await model.load()

        #expect(model.loadingState == .idle)
        #expect(model.logs.count == 2)
        let current = try #require(model.logs.first)
        #expect(current.file.name.hasPrefix("EhPanda-"))
        #expect(model.latestLog == current.file)
        #expect(current.recordCount == 2)
        #expect(current.firstDate?.count == "yyyy-MM-dd".count)
        let legacy = try #require(model.logs.last)
        #expect(legacy.file.name == "EhPanda.log.1")
        #expect(legacy.recordCount == 3)
        #expect(legacy.firstDate == "2024-01-02")
        #expect(legacy.lastDate == "2024-01-04")
    }

    @Test func emptyDirectoryListsNothing() async throws {
        let (logger, directory) = try makeLogger()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = withDependencies { $0.appLogger = logger } operation: { LogsModel() }

        await model.load()

        #expect(model.logs.isEmpty)
        #expect(model.loadingState == .idle)
    }

    @Test func deletingRemovesTheRowAndTheFile() async throws {
        let (logger, directory) = try makeLogger()
        defer { try? FileManager.default.removeItem(at: directory) }
        logger.info("message")
        await logger.flush()
        let model = withDependencies { $0.appLogger = logger } operation: { LogsModel() }
        await model.load()
        let log = try #require(model.logs.first)
        model.selectedLog = log.file

        await model.delete(log)

        #expect(model.logs.isEmpty)
        #expect(model.selectedLog == nil)
        #expect(!FileManager.default.fileExists(atPath: log.file.url.path()))
        await model.load()
        #expect(model.logs.isEmpty)
    }

    @Test func detailReadsEveryLine() async throws {
        let (logger, directory) = try makeLogger()
        defer { try? FileManager.default.removeItem(at: directory) }
        logger.info("one")
        logger.info("two\nstill two")
        await logger.flush()
        let file = try #require(await logger.logFiles().first)
        let model = withDependencies { $0.appLogger = logger } operation: { LogDetailModel(file: file) }

        await model.load()

        #expect(model.loadingState == .idle)
        #expect(model.lines.count == 2)
        #expect(model.lines[0].hasSuffix("- one"))
        #expect(model.lines[1].hasSuffix("- two\\nstill two"))
    }

    @Test func detailOfAMissingFileFails() async throws {
        let (logger, directory) = try makeLogger()
        defer { try? FileManager.default.removeItem(at: directory) }
        logger.info("message")
        await logger.flush()
        let file = try #require(await logger.logFiles().first)
        await logger.delete(file)
        let model = withDependencies { $0.appLogger = logger } operation: { LogDetailModel(file: file) }

        await model.load()

        #expect(model.loadingState == .failed(.notFound))
        #expect(model.lines.isEmpty)
    }

    @Test func openingTheFolderUsesTheFilesAppScheme() async {
        let opened = SettingsTestLock<URL?>(nil)
        let model = withDependencies {
            $0.applicationClient.openURL = { url in
                opened.withLock { $0 = url }
                return true
            }
        } operation: { LogsModel() }

        await model.openLogsFolder()

        let url = opened.withLock { $0 }
        #expect(url?.scheme == "shareddocuments")
        #expect(url?.absoluteString.hasSuffix("/logs/") == true)
    }
}
