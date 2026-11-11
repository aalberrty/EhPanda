import Foundation
import SQLite3

/// Builds a legacy (EhPanda 2.x, Core Data model version 7) store with raw SQL, so tests
/// need no binary fixture. Tables and columns match a store written by the last release.
///
/// The connection runs in WAL mode with automatic checkpoints off, so until ``close()`` the
/// inserted rows live only in `Model.sqlite-wal`, as they can on a user's device.
public final class LegacyStoreBuilder {
    public enum Value {
        case int(Int)
        case double(Double)
        case text(String)
        case blob(Data)
        case null
    }

    /// Every legacy table with its columns, in declaration order.
    public static let schema: [(table: String, columns: [(name: String, type: String)])] = [
        ("ZAPPENVMO", [
            ("Z_PK", "INTEGER PRIMARY KEY"), ("Z_ENT", "INTEGER"), ("Z_OPT", "INTEGER"),
            ("ZGLOBALFILTER", "BLOB"), ("ZHISTORYKEYWORDS", "BLOB"), ("ZQUICKSEARCHWORDS", "BLOB"),
            ("ZSEARCHFILTER", "BLOB"), ("ZSETTING", "BLOB"), ("ZTAGTRANSLATOR", "BLOB"),
            ("ZUSER", "BLOB"), ("ZWATCHEDFILTER", "BLOB")
        ]),
        ("ZGALLERYMO", [
            ("Z_PK", "INTEGER PRIMARY KEY"), ("Z_ENT", "INTEGER"), ("Z_OPT", "INTEGER"),
            ("ZPAGECOUNT", "INTEGER"), ("ZLASTOPENDATE", "TIMESTAMP"), ("ZPOSTEDDATE", "TIMESTAMP"),
            ("ZRATING", "FLOAT"), ("ZCATEGORY", "VARCHAR"), ("ZGID", "VARCHAR"), ("ZTITLE", "VARCHAR"),
            ("ZTOKEN", "VARCHAR"), ("ZUPLOADER", "VARCHAR"), ("ZCOVERURL", "VARCHAR"),
            ("ZGALLERYURL", "VARCHAR"), ("ZTAGS", "BLOB")
        ]),
        ("ZGALLERYDETAILMO", [
            ("Z_PK", "INTEGER PRIMARY KEY"), ("Z_ENT", "INTEGER"), ("Z_OPT", "INTEGER"),
            ("ZFAVORITEDCOUNT", "INTEGER"), ("ZISFAVORITED", "INTEGER"), ("ZPAGECOUNT", "INTEGER"),
            ("ZRATINGCOUNT", "INTEGER"), ("ZTORRENTCOUNT", "INTEGER"), ("ZPOSTEDDATE", "TIMESTAMP"),
            ("ZRATING", "FLOAT"), ("ZSIZECOUNT", "FLOAT"), ("ZUSERRATING", "FLOAT"),
            ("ZCATEGORY", "VARCHAR"), ("ZGID", "VARCHAR"), ("ZJPNTITLE", "VARCHAR"),
            ("ZLANGUAGE", "VARCHAR"), ("ZSIZETYPE", "VARCHAR"), ("ZTITLE", "VARCHAR"),
            ("ZUPLOADER", "VARCHAR"), ("ZARCHIVEURL", "VARCHAR"), ("ZCOVERURL", "VARCHAR"),
            ("ZPARENTURL", "VARCHAR"), ("ZVISIBILITY", "BLOB")
        ]),
        ("ZGALLERYSTATEMO", [
            ("Z_PK", "INTEGER PRIMARY KEY"), ("Z_ENT", "INTEGER"), ("Z_OPT", "INTEGER"),
            ("ZREADINGPROGRESS", "INTEGER"), ("ZGID", "VARCHAR"), ("ZCOMMENTS", "BLOB"),
            ("ZIMAGEURLS", "BLOB"), ("ZORIGINALIMAGEURLS", "BLOB"), ("ZPREVIEWCONFIG", "BLOB"),
            ("ZPREVIEWURLS", "BLOB"), ("ZTAGS", "BLOB"), ("ZTHUMBNAILURLS", "BLOB")
        ]),
        ("Z_PRIMARYKEY", [
            ("Z_ENT", "INTEGER PRIMARY KEY"), ("Z_NAME", "VARCHAR"), ("Z_SUPER", "INTEGER"), ("Z_MAX", "INTEGER")
        ]),
        ("Z_METADATA", [("Z_VERSION", "INTEGER PRIMARY KEY"), ("Z_UUID", "VARCHAR(255)"), ("Z_PLIST", "BLOB")]),
        ("Z_MODELCACHE", [("Z_CONTENT", "BLOB")])
    ]

    public struct BuilderError: Error, CustomStringConvertible {
        public let description: String
    }

    /// The directory holding the store; remove it with ``removeDirectory()``.
    public let directory: URL
    /// `Model.sqlite` inside ``directory``.
    public let url: URL
    private var connection: OpaquePointer?
    private var columns: [String: Set<String>] = [:]
    private var nextPrimaryKey = 1

    /// Creates a store in a new temporary directory.
    ///
    /// - Parameters:
    ///   - omittingTables: legacy tables to leave out, as in stores from older releases.
    ///   - omittingColumns: columns to leave out, by table.
    public init(omittingTables: Set<String> = [], omittingColumns: [String: Set<String>] = [:]) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyStore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("Model.sqlite")
        guard sqlite3_open(url.path, &connection) == SQLITE_OK else {
            throw BuilderError(description: "Cannot open \(url.path)")
        }
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA wal_autocheckpoint = 0")
        for (table, definitions) in Self.schema where !omittingTables.contains(table) {
            let omitted = omittingColumns[table] ?? []
            let kept = definitions.filter { !omitted.contains($0.name) }
            try execute("CREATE TABLE \(table) (\(kept.map { "\($0.name) \($0.type)" }.joined(separator: ", ")))")
            columns[table] = Set(kept.map(\.name))
        }
    }

    deinit {
        sqlite3_close(connection)
    }

    /// Converts a date to Core Data's timestamp: seconds since 2001-01-01 00:00:00 UTC.
    public static func timestamp(_ date: Date) -> Value {
        .double(date.timeIntervalSinceReferenceDate)
    }

    public func execute(_ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(connection, sql, nil, nil, &message) == SQLITE_OK else {
            let text = message.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(message)
            throw BuilderError(description: "\(text) in: \(sql)")
        }
    }

    /// Inserts a row, filling `Z_PK`, `Z_ENT` and `Z_OPT`. Values for columns the table was
    /// built without are dropped; inserting into a table that was left out does nothing.
    public func insert(into table: String, _ values: [String: Value]) throws {
        guard let tableColumns = columns[table] else { return }
        var row = values
        row["Z_PK"] = row["Z_PK"] ?? .int(nextPrimaryKey)
        row["Z_ENT"] = row["Z_ENT"] ?? .int(1)
        row["Z_OPT"] = row["Z_OPT"] ?? .int(1)
        nextPrimaryKey += 1
        let kept = row.filter { tableColumns.contains($0.key) }.sorted { $0.key < $1.key }
        let sql = "INSERT INTO \(table) (\(kept.map(\.key).joined(separator: ", "))) "
            + "VALUES (\(Array(repeating: "?", count: kept.count).joined(separator: ", ")))"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw BuilderError(description: "Cannot prepare: \(sql)")
        }
        defer { sqlite3_finalize(statement) }
        for (offset, entry) in kept.enumerated() {
            bind(entry.value, at: Int32(offset + 1), in: statement)
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw BuilderError(description: "Cannot insert: \(sql)")
        }
    }

    /// Closes the connection, which checkpoints the WAL into `Model.sqlite`.
    public func close() {
        sqlite3_close(connection)
        connection = nil
    }

    public func removeDirectory() {
        close()
        try? FileManager.default.removeItem(at: directory)
    }

    private func bind(_ value: Value, at index: Int32, in statement: OpaquePointer?) {
        // SQLITE_TRANSIENT: SQLite copies the bytes before the call returns.
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        switch value {
        case .int(let int): sqlite3_bind_int64(statement, index, Int64(int))
        case .double(let double): sqlite3_bind_double(statement, index, double)
        case .text(let text): sqlite3_bind_text(statement, index, text, -1, transient)
        case .blob(let data):
            data.withUnsafeBytes { bytes in
                _ = sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), transient)
            }
        case .null: sqlite3_bind_null(statement, index)
        }
    }
}
