import Foundation
import GRDB

// MARK: - Tag translations

extension AppDatabase {
    /// Replaces every stored translation with `translations` in one transaction, reusing one
    /// prepared statement. Later duplicates of a key win.
    public func replaceTagTranslations(_ translations: [StoredTagTranslation]) async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM \(Schema.tagTranslation)")
            let statement = try db.makeStatement(sql: """
                INSERT OR REPLACE INTO \(Schema.tagTranslation)
                    (key, namespace, tag, value, displayValue, valueImageURL, description, linksString)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """)
            for translation in translations {
                try statement.execute(arguments: translation.databaseArguments)
            }
        }
    }

    /// Every translation's display data keyed by lookup key, built off the caller's actor.
    public func tagTranslationLookup() async throws -> [String: TagTranslationDisplay] {
        try await writer.read { db in
            var lookup = [String: TagTranslationDisplay]()
            lookup.reserveCapacity(try Self.tagTranslationCount(db))
            let rows = try Row.fetchCursor(
                db, sql: "SELECT key, displayValue, valueImageURL FROM \(Schema.tagTranslation)"
            )
            while let row = try rows.next() {
                lookup[row["key"]] = TagTranslationDisplay(
                    displayValue: row["displayValue"], valueImageURL: row["valueImageURL"]
                )
            }
            return lookup
        }
    }

    /// The full translations for `keys`; keys with no translation are absent from the result.
    public func tagTranslations(keys: [String]) async throws -> [String: StoredTagTranslation] {
        guard !keys.isEmpty else { return [:] }
        return try await writer.read { db in
            // Chunked to stay under SQLite's bound-parameter limit.
            var result = [String: StoredTagTranslation]()
            for start in stride(from: 0, to: keys.count, by: 500) {
                let chunk = Array(keys[start..<min(start + 500, keys.count)])
                let placeholders = databaseQuestionMarks(count: chunk.count)
                let rows = try Row.fetchCursor(
                    db,
                    sql: "SELECT * FROM \(Schema.tagTranslation) WHERE key IN (\(placeholders))",
                    arguments: StatementArguments(chunk)
                )
                while let row = try rows.next() {
                    if let translation = StoredTagTranslation(row: row) {
                        result[translation.key] = translation
                    }
                }
            }
            return result
        }
    }

    /// Translations whose tag or display value contains `keyword`, case-insensitively for
    /// ASCII. Prefix matches come first, then shorter tags. The caller ranks the final list.
    public func searchTagTranslations(matching keyword: String, limit: Int) async throws -> [StoredTagTranslation] {
        guard !keyword.isEmpty, limit > 0 else { return [] }
        let escaped = Self.escapeLikePattern(keyword)
        return try await writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM \(Schema.tagTranslation)
                WHERE tag LIKE :contains ESCAPE '\\' OR displayValue LIKE :contains ESCAPE '\\'
                ORDER BY (tag LIKE :prefix ESCAPE '\\' OR displayValue LIKE :prefix ESCAPE '\\') DESC,
                    length(tag), tag
                LIMIT :limit
                """,
                arguments: ["contains": "%\(escaped)%", "prefix": "\(escaped)%", "limit": limit]
            )
            .compactMap(StoredTagTranslation.init(row:))
        }
    }

    public func tagTranslationCount() async throws -> Int {
        try await writer.read { db in try Self.tagTranslationCount(db) }
    }

    public func deleteAllTagTranslations() async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM \(Schema.tagTranslation)")
        }
    }

    private static func tagTranslationCount(_ db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(Schema.tagTranslation)") ?? 0
    }

    static func escapeLikePattern(_ text: String) -> String {
        var escaped = ""
        for character in text {
            if character == "\\" || character == "%" || character == "_" {
                escaped.append("\\")
            }
            escaped.append(character)
        }
        return escaped
    }
}
