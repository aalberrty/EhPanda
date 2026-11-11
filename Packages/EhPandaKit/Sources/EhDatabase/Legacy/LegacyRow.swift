import Foundation
import GRDB

/// Lenient access to a row of the legacy Core Data store.
///
/// Stores from older releases may lack columns, and SQLite does not enforce declared types,
/// so every accessor tolerates a missing column and any storage class instead of trapping.
struct LegacyRow {
    let row: Row

    private func storage(_ column: String) -> DatabaseValue.Storage {
        guard row.hasColumn(column) else { return .null }
        let value: DatabaseValue = row[column]
        return value.storage
    }

    func string(_ column: String) -> String? {
        switch storage(column) {
        case .string(let string): string
        case .int64(let int): String(int)
        case .double(let double): String(double)
        case .blob(let data): String(data: data, encoding: .utf8)
        case .null: nil
        }
    }

    func double(_ column: String) -> Double? {
        switch storage(column) {
        case .double(let double): double
        case .int64(let int): Double(int)
        case .string(let string): Double(string)
        case .blob, .null: nil
        }
    }

    func int(_ column: String) -> Int? {
        switch storage(column) {
        case .int64(let int): Int(exactly: int)
        case .double(let double): Int(exactly: double.rounded(.towardZero))
        case .string(let string): Int(string)
        case .blob, .null: nil
        }
    }

    func data(_ column: String) -> Data? {
        switch storage(column) {
        case .blob(let data): data
        case .string(let string): Data(string.utf8)
        case .int64, .double, .null: nil
        }
    }

    func url(_ column: String) -> URL? {
        string(column).flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    func date(_ column: String) -> Date? {
        double(column).map(LegacyDate.date(fromCoreDataTimestamp:))
    }
}

/// Core Data stores dates as seconds since 2001-01-01 00:00:00 UTC, as do the legacy JSON
/// blobs (`JSONEncoder`'s default date strategy).
enum LegacyDate {
    static func date(fromCoreDataTimestamp timestamp: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: timestamp)
    }
}
