import Dependencies
import EhDatabase
import Foundation
import Synchronization

/// The app database behind a dependency.
///
/// `AppDatabase` can only be opened asynchronously, while dependency values are created
/// synchronously, so the dependency holds this provider and callers `await` ``value``. The
/// database opens once, on first use; concurrent callers share that open.
///
/// Lives here until the persistence layer owns a database key; move it then.
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

extension AppDatabaseProvider: DependencyKey {
    /// The app opens the on-disk database at launch and sets it with
    /// `prepareDependencies { $0.database = AppDatabaseProvider(database) }`.
    public static let liveValue = AppDatabaseProvider {
        reportIssue("\\.database was used before the app set it.")
        throw DatabaseNotSetError()
    }

    struct DatabaseNotSetError: Error {}

    /// A fresh in-memory database per test.
    public static var testValue: AppDatabaseProvider {
        AppDatabaseProvider { try await AppDatabase.inMemory() }
    }

    public static var previewValue: AppDatabaseProvider { testValue }
}

extension DependencyValues {
    public var database: AppDatabaseProvider {
        get { self[AppDatabaseProvider.self] }
        set { self[AppDatabaseProvider.self] = newValue }
    }
}
