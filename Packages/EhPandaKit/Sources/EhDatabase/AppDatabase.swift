import Foundation
import GRDB

/// The app's SQLite database.
///
/// Every public method is `async` and runs on GRDB's own serial writer queue or concurrent
/// reader pool, never on the caller's actor. Each method is one transaction.
public final class AppDatabase: Sendable {
    /// `DatabaseWriter` is `Sendable`; GRDB serializes writes and isolates reads itself.
    let writer: any DatabaseWriter

    private init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// Opens (creating if needed) the on-disk database at `url` in WAL mode and migrates it.
    @concurrent
    public static func open(at url: URL) async throws -> AppDatabase {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let pool = try DatabasePool(path: url.path, configuration: makeConfiguration())
        return try AppDatabase(writer: pool)
    }

    /// An empty, migrated database that lives only in memory. For tests and previews.
    @concurrent
    public static func inMemory() async throws -> AppDatabase {
        try makeInMemory()
    }

    /// Synchronous form of `inMemory()`, for the default dependency values of tests and
    /// previews, which cannot await. Creating an empty in-memory database is quick.
    public static func makeInMemory() throws -> AppDatabase {
        let queue = try DatabaseQueue(configuration: makeConfiguration())
        return try AppDatabase(writer: queue)
    }

    private static func makeConfiguration() -> Configuration {
        var configuration = Configuration()
        configuration.label = "EhPanda.AppDatabase"
        configuration.qos = .userInitiated
        return configuration
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        // Schema edits during development rebuild the database instead of requiring a migration.
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        Schema.registerMigrations(in: &migrator)
        return migrator
    }
}
