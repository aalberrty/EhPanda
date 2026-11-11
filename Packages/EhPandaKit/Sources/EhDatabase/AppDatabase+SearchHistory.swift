import Foundation
import GRDB

// MARK: - Search history

extension AppDatabase {
    /// Legacy keeps the 20 most recent keywords (`SearchRootReducer.appendHistoryKeywords`).
    public static let searchHistoryLimit = 20

    /// Records that `keyword` was searched. See ``recordSearchKeywords(_:at:)``.
    public func recordSearchKeyword(_ keyword: String, at date: Date = .now) async throws {
        try await recordSearchKeywords([keyword], at: date)
    }

    /// Records searches in order, the last being the most recent.
    ///
    /// As in legacy, empty keywords are ignored, a keyword equal to a stored one ignoring
    /// case replaces it (taking the new spelling) and becomes the newest, and only the
    /// ``searchHistoryLimit`` newest keywords are kept.
    public func recordSearchKeywords(_ keywords: [String], at date: Date = .now) async throws {
        let keywords = keywords.filter { !$0.isEmpty }
        guard !keywords.isEmpty else { return }
        try await writer.write { db in
            var stored = try String.fetchAll(db, sql: "SELECT keyword FROM \(Schema.searchHistory)")
            let delete = try db.makeStatement(sql: "DELETE FROM \(Schema.searchHistory) WHERE keyword = ?")
            let insert = try db.makeStatement(
                sql: "INSERT INTO \(Schema.searchHistory) (keyword, lastUsedAt) VALUES (?, ?)"
            )
            for (offset, keyword) in keywords.enumerated() {
                for match in stored where match.caseInsensitiveCompare(keyword) == .orderedSame {
                    try delete.execute(arguments: [match])
                }
                stored.removeAll { $0.caseInsensitiveCompare(keyword) == .orderedSame }
                // Dates are stored with millisecond precision; keep the batch's order.
                let usedAt = date.addingTimeInterval(Double(offset - keywords.count + 1) / 1000)
                try insert.execute(arguments: [keyword, usedAt])
                stored.append(keyword)
            }
            try Self.trimSearchHistory(db)
        }
    }

    public func removeSearchKeyword(_ keyword: String) async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM \(Schema.searchHistory) WHERE keyword = ?", arguments: [keyword])
        }
    }

    public func clearSearchHistory() async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM \(Schema.searchHistory)")
        }
    }

    /// Keywords, most recently used first.
    public func observeSearchHistory() -> some AsyncSequence<[String], any Error> & Sendable {
        ValueObservation
            .tracking { db in
                try String.fetchAll(
                    db, sql: "SELECT keyword FROM \(Schema.searchHistory) ORDER BY lastUsedAt DESC, keyword"
                )
            }
            .values(in: writer, scheduling: .task)
    }

    static func trimSearchHistory(_ db: Database) throws {
        try db.execute(
            sql: """
            DELETE FROM \(Schema.searchHistory) WHERE keyword NOT IN
                (SELECT keyword FROM \(Schema.searchHistory) ORDER BY lastUsedAt DESC LIMIT ?)
            """,
            arguments: [searchHistoryLimit]
        )
    }
}
