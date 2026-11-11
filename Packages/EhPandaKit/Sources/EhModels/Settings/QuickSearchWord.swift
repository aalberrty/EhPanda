import Foundation

/// A saved search keyword with a user-chosen name.
public struct QuickSearchWord: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var content: String

    public init(id: UUID = .init(), name: String, content: String) {
        self.id = id
        self.name = name
        self.content = content
    }

    public static var empty: Self { .init(name: "", content: "") }
}
