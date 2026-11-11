import Foundation

/// Decodes with a default `JSONDecoder`, the configuration the legacy app persisted with
/// (dates as seconds since 2001-01-01, URLs as strings).
func decodeJSON<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

func roundTrip<T: Codable>(_ value: T) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
}
