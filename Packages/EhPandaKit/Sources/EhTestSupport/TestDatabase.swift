import EhDatabase
import Foundation

/// Databases for tests.
public enum TestDatabase {
    /// An empty, migrated in-memory database.
    public static func inMemory() async throws -> AppDatabase {
        try await AppDatabase.inMemory()
    }

    /// An empty, migrated on-disk database (WAL mode) in a fresh temporary directory.
    /// Remove `directory` when done.
    public static func onDisk() async throws -> (database: AppDatabase, directory: URL) {
        let directory = try makeTemporaryDirectory()
        let database = try await AppDatabase.open(at: directory.appendingPathComponent("EhPanda.sqlite"))
        return (database, directory)
    }

    /// A new, empty directory under the system temporary directory.
    public static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EhPandaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
