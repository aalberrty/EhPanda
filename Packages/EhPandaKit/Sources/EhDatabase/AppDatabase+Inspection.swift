import GRDB

// Internal helpers that let tests check the schema and row counts without importing GRDB.
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
}
