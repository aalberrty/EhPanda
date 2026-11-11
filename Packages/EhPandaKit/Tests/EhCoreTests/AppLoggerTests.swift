import Foundation
import Synchronization
import Testing
@testable import EhCore

@Suite struct AppLoggerTests {
    @Test func writesInfoAndAboveToOneFile() async throws {
        let directory = TemporaryLogDirectory()
        defer { directory.cleanUp() }
        let logger = directory.makeLogger()

        logger.debug("debug message")
        logger.info("info message", category: "Reader")
        logger.warning("warning message")
        logger.error("multi\nline")
        await logger.flush()

        let files = await logger.logFiles()
        #expect(files.count == 1)
        let file = try #require(files.first)
        #expect(file.name.hasPrefix("EhPanda-") && file.name.hasSuffix(".log"))
        #expect(file.size > 0)

        let lines = try await logger.lines(of: file)
        #expect(lines.count == 3)
        #expect(lines[0].contains(" INFO [Reader] EhCoreTests/AppLoggerTests.swift:"))
        #expect(lines[0].hasSuffix(" - info message"))
        #expect(lines[1].contains(" WARNING [App] "))
        #expect(lines[2].hasSuffix(" - multi\\nline"))
        // Same timestamp layout as the legacy SwiftyBeaver files: "yyyy-MM-dd HH:mm:ss.SSS ".
        #expect(LogRecord.makeTimestampFormatter().date(from: String(lines[0].prefix(23))) != nil)
    }

    @Test func dropsMessagesBelowMinimumLevelWithoutBuildingThem() async throws {
        let directory = TemporaryLogDirectory()
        defer { directory.cleanUp() }
        let logger = directory.makeLogger(minimumLevel: .warning, fileLevel: .debug)
        let evaluations = Mutex(0)
        func message(_ text: String) -> String {
            evaluations.withLock { $0 += 1 }
            return text
        }

        logger.debug(message("debug"))
        logger.info(message("info"))
        logger.warning(message("warning"))
        logger.error(message("error"))
        await logger.flush()

        #expect(evaluations.withLock { $0 } == 2)
        let file = try #require(await logger.logFiles().first)
        let lines = try await logger.lines(of: file)
        #expect(lines.map { $0.components(separatedBy: " - ").last } == ["warning", "error"])
    }

    @Test func fileLevelFiltersWhatReachesTheFile() async throws {
        let directory = TemporaryLogDirectory()
        defer { directory.cleanUp() }
        let logger = directory.makeLogger(fileLevel: .error)

        logger.debug("a")
        logger.info("b")
        logger.warning("c")
        await logger.flush()
        #expect(await logger.logFiles().isEmpty)

        logger.error("d")
        await logger.flush()
        let file = try #require(await logger.logFiles().first)
        #expect(try await logger.lines(of: file).count == 1)
    }

    @Test func eachLaunchStartsANewFileListedNewestFirst() async throws {
        let directory = TemporaryLogDirectory()
        defer { directory.cleanUp() }

        for index in 0..<3 {
            let logger = directory.makeLogger(launchedAt: launchDate(index))
            logger.info("launch \(index)")
            await logger.flush()
        }

        let logger = directory.makeLogger(launchedAt: launchDate(3))
        let files = await logger.logFiles()
        #expect(files.count == 3)
        #expect(files.map(\.date) == [launchDate(2), launchDate(1), launchDate(0)])
        #expect(try await logger.lines(of: files[0]).first?.hasSuffix("launch 2") == true)
    }

    @Test func sameLaunchDateGetsAUniqueName() async throws {
        let directory = TemporaryLogDirectory()
        defer { directory.cleanUp() }
        for _ in 0..<2 {
            let logger = directory.makeLogger(launchedAt: launchDate(0))
            logger.info("x")
            await logger.flush()
        }
        let files = await directory.makeLogger().logFiles()
        #expect(Set(files.map(\.name)).count == 2)
    }

    @Test func startsANewFileWhenTheCurrentOneIsFull() async throws {
        let directory = TemporaryLogDirectory()
        defer { directory.cleanUp() }
        let logger = directory.makeLogger(maxFileSize: 300)

        for index in 0..<10 {
            logger.info("message number \(index)")
        }
        await logger.flush()

        let files = await logger.logFiles()
        #expect(files.count > 1)
        #expect(files.allSatisfy { $0.size <= 300 })
        var total = 0
        for file in files {
            total += try await logger.lines(of: file).count
        }
        #expect(total == 10)
    }

    @Test func keepsOnlyTheNewestFilesIncludingLegacyOnes() async throws {
        let directory = TemporaryLogDirectory()
        defer { directory.cleanUp() }
        let old = Date(timeIntervalSinceReferenceDate: 700_000_000)
        try directory.writeFile(named: "EhPanda.log", contents: "legacy\n", modified: old)
        try directory.writeFile(named: "EhPanda.log.1", contents: "older legacy\n", modified: old - 60)
        try directory.writeFile(named: "notes.txt", contents: "keep me\n", modified: old)

        for index in 0..<4 {
            let logger = directory.makeLogger(maxFileCount: 3, launchedAt: launchDate(index))
            logger.info("launch \(index)")
            await logger.flush()
        }

        let files = await directory.makeLogger().logFiles()
        #expect(files.map(\.date) == [launchDate(3), launchDate(2), launchDate(1)])
        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.url.path)
        #expect(remaining.contains("notes.txt"))
        #expect(!remaining.contains("EhPanda.log"))
    }

    @Test func listsAndReadsLegacyFiles() async throws {
        let directory = TemporaryLogDirectory()
        defer { directory.cleanUp() }
        let old = Date(timeIntervalSinceReferenceDate: 700_000_000)
        try directory.writeFile(named: "EhPanda.log", contents: "a\n\nb\n", modified: old)
        try directory.writeFile(named: "EhPanda.log.1", contents: "c\n", modified: old - 60)

        let logger = directory.makeLogger(launchedAt: launchDate(0))
        logger.info("new")
        await logger.flush()

        let files = await logger.logFiles()
        #expect(files.map(\.name).suffix(2) == ["EhPanda.log", "EhPanda.log.1"])
        #expect(try await logger.lines(of: files[1]) == ["a", "b"])
    }

    @Test func deletesOneOrAllFilesAndKeepsLogging() async throws {
        let directory = TemporaryLogDirectory()
        defer { directory.cleanUp() }
        try directory.writeFile(named: "EhPanda.log", contents: "legacy\n", modified: .distantPast)
        let logger = directory.makeLogger()
        logger.info("before")
        await logger.flush()
        #expect(await logger.logFiles().count == 2)

        let current = try #require(await logger.logFiles().first)
        await logger.delete(current)
        #expect(await logger.logFiles().map(\.name) == ["EhPanda.log"])

        logger.info("after delete")
        await logger.flush()
        #expect(await logger.logFiles().count == 2)

        await logger.deleteAllLogFiles()
        #expect(await logger.logFiles().isEmpty)

        logger.info("after delete all")
        await logger.flush()
        let file = try #require(await logger.logFiles().first)
        #expect(try await logger.lines(of: file).count == 1)
    }

    @Test func concurrentLoggingLosesNoLines() async throws {
        let directory = TemporaryLogDirectory()
        defer { directory.cleanUp() }
        let logger = directory.makeLogger()
        let taskCount = 50
        let linesPerTask = 200

        await withTaskGroup(of: Void.self) { group in
            for task in 0..<taskCount {
                group.addTask {
                    for line in 0..<linesPerTask {
                        logger.info("task \(task) line \(line)")
                    }
                }
            }
        }
        await logger.flush()

        let files = await logger.logFiles()
        #expect(files.count == 1)
        let lines = try await logger.lines(of: try #require(files.first))
        #expect(lines.count == taskCount * linesPerTask)
        #expect(Set(lines.map { $0.components(separatedBy: " - ").last }).count == taskCount * linesPerTask)
    }

    @Test func consoleLoggerHasNoFiles() async throws {
        let logger = AppLogger.console()
        logger.error("console only")
        await logger.flush()
        #expect(await logger.logFiles().isEmpty)
    }
}
