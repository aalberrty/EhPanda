import Foundation

/// Encoding and decoding of JSON columns.
///
/// Columns are read leniently: a value that no longer decodes (for example after a model
/// change) yields `nil` so one stale row can never make a whole list fail to load.
enum JSONColumn {
    static func encode<Value: Encodable>(_ value: Value) throws -> String {
        let data = try JSONEncoder().encode(value)
        // JSONEncoder always produces UTF-8.
        return String(decoding: data, as: UTF8.self)
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from text: String?) -> Value? {
        guard let text else { return nil }
        return try? JSONDecoder().decode(type, from: Data(text.utf8))
    }
}
