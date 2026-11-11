import EhModels
import Foundation
import GRDB

// MARK: - Quick search words

extension AppDatabase {
    /// Quick-search words in the user's order.
    public func observeQuickSearchWords() -> some AsyncSequence<[QuickSearchWord], any Error> & Sendable {
        ValueObservation
            .tracking { db in
                try Row.fetchAll(
                    db, sql: "SELECT id, name, content FROM \(Schema.quickSearchWord) ORDER BY position, rowid"
                )
                .compactMap(Self.quickSearchWord(row:))
            }
            .values(in: writer, scheduling: .task)
    }

    /// Appends `word` after the existing ones.
    public func insertQuickSearchWord(_ word: QuickSearchWord) async throws {
        try await writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO \(Schema.quickSearchWord) (id, name, content, position)
                VALUES (?, ?, ?, (SELECT coalesce(max(position), -1) + 1 FROM \(Schema.quickSearchWord)))
                """,
                arguments: [word.id.uuidString, word.name, word.content]
            )
        }
    }

    /// Updates the name and content of the stored word with the same `id`.
    public func updateQuickSearchWord(_ word: QuickSearchWord) async throws {
        try await writer.write { db in
            try db.execute(
                sql: "UPDATE \(Schema.quickSearchWord) SET name = ?, content = ? WHERE id = ?",
                arguments: [word.name, word.content, word.id.uuidString]
            )
        }
    }

    public func deleteQuickSearchWord(id: UUID) async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM \(Schema.quickSearchWord) WHERE id = ?", arguments: [id.uuidString])
        }
    }

    /// Sets the order to `ids`. Stored words missing from `ids` keep their relative order
    /// after the listed ones.
    public func reorderQuickSearchWords(_ ids: [UUID]) async throws {
        try await writer.write { db in
            let stored = try String.fetchAll(
                db, sql: "SELECT id FROM \(Schema.quickSearchWord) ORDER BY position, rowid"
            )
            let listed = ids.map(\.uuidString)
            let listedSet = Set(listed)
            let order = listed + stored.filter { !listedSet.contains($0) }
            let statement = try db.makeStatement(
                sql: "UPDATE \(Schema.quickSearchWord) SET position = ? WHERE id = ?"
            )
            for (position, id) in order.enumerated() {
                try statement.execute(arguments: [position, id])
            }
        }
    }

    static func quickSearchWord(row: Row) -> QuickSearchWord? {
        guard let id = UUID(uuidString: row["id"]) else { return nil }
        return QuickSearchWord(id: id, name: row["name"], content: row["content"])
    }
}
