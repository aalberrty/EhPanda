import Dispatch
import GRDB
import Synchronization

// Internal helpers that let tests check the schema, row counts and transactions without
// importing GRDB.
extension AppDatabase {
    /// Column names of every table created by the migrations, by table name.
    func schemaColumns() async throws -> [String: [String]] {
        try await writer.read { db in
            let tables = try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'
                """)
            var result = [String: [String]]()
            for table in tables {
                result[table] = try db.columns(in: table).map(\.name)
            }
            return result
        }
    }

    /// Names of every index, excluding SQLite's automatic ones.
    func indexNames() async throws -> Set<String> {
        try await writer.read { db in
            try Set(String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%'
                """))
        }
    }

    func rowCount(_ table: String) async throws -> Int {
        try await writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0
        }
    }

    /// How many write transactions were committed while `body` ran, for tests that check
    /// that something is saved in one. `body` runs on the caller's actor.
    func commitCount(
        isolation: isolated (any Actor)? = #isolation, during body: () async throws -> Void
    ) async throws -> Int {
        let counter = CommitCounter()
        try await writer.writeWithoutTransaction { db in
            db.add(transactionObserver: counter, extent: .observerLifetime)
        }
        try await body()
        // Lets a commit that is still on the writer's queue be counted.
        try await writer.writeWithoutTransaction { _ in }
        return counter.commits
    }

    /// Runs `body` while the writer is held, so nothing can be written and, on an in-memory
    /// database, nothing can be read either. For tests that check what does not wait for the
    /// database. `body` runs on the caller's actor.
    func whileWriterIsBusy(
        isolation: isolated (any Actor)? = #isolation, _ body: () async throws -> Void
    ) async throws {
        let gate = DispatchSemaphore(value: 0)
        let (entered, signal) = AsyncStream<Void>.makeStream()
        async let held: Void = writer.writeWithoutTransaction { _ in
            signal.yield()
            gate.wait()
        }
        for await _ in entered { break }
        let result: Result<Void, any Error>
        do {
            result = .success(try await body())
        } catch {
            result = .failure(error)
        }
        gate.signal()
        try await held
        try result.get()
    }
}

private final class CommitCounter: TransactionObserver, Sendable {
    private let count = Mutex(0)

    var commits: Int { count.withLock { $0 } }

    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { false }
    func databaseDidChange(with event: DatabaseEvent) {}
    func databaseDidCommit(_ db: Database) { count.withLock { $0 += 1 } }
    func databaseDidRollback(_ db: Database) {}
}
