import EhDatabase
import Foundation
import Synchronization

/// A database that is resolved on first use.
///
/// The tag translation service is created before the launch sequence has opened the
/// database, so it holds this provider and `await`s ``value`` when it needs the database.
/// The database is resolved once; concurrent callers share that resolution.
public final class AppDatabaseProvider: Sendable {
    private let open: @Sendable () async throws -> AppDatabase
    private let opening = Mutex<Task<AppDatabase, any Error>?>(nil)

    public init(open: @escaping @Sendable () async throws -> AppDatabase) {
        self.open = open
    }

    /// A provider for a database that is already open.
    public convenience init(_ database: AppDatabase) {
        self.init(open: { database })
    }

    /// The database, opening it on first use. A failed open is retried by the next call.
    public var value: AppDatabase {
        get async throws {
            let task = opening.withLock { task in
                if let task { return task }
                let open = self.open
                let newTask = Task { try await open() }
                task = newTask
                return newTask
            }
            do {
                return try await task.value
            } catch {
                opening.withLock { if $0 == task { $0 = nil } }
                throw error
            }
        }
    }
}
