@testable import EhDatabase
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct QuickSearchWordTests {
    func words(_ database: AppDatabase) async throws -> [QuickSearchWord] {
        try await observe(database.observeQuickSearchWords(), changes: []).first ?? []
    }

    @Test func insertAppendsInOrder() async throws {
        let database = try await TestDatabase.inMemory()
        let first = QuickSearchWord(name: "One", content: "f:glasses$")
        let second = QuickSearchWord(name: "Two", content: "l:chinese$")
        try await database.insertQuickSearchWord(first)
        try await database.insertQuickSearchWord(second)
        #expect(try await words(database) == [first, second])
    }

    @Test func updateChangesNameAndContent() async throws {
        let database = try await TestDatabase.inMemory()
        var word = QuickSearchWord(name: "One", content: "a")
        try await database.insertQuickSearchWord(word)
        word.name = "Renamed"
        word.content = "b"
        try await database.updateQuickSearchWord(word)
        #expect(try await words(database) == [word])
    }

    @Test func deleteRemovesWord() async throws {
        let database = try await TestDatabase.inMemory()
        let words = (0..<3).map { QuickSearchWord(name: "\($0)", content: "\($0)") }
        for word in words { try await database.insertQuickSearchWord(word) }
        try await database.deleteQuickSearchWord(id: words[1].id)
        #expect(try await self.words(database) == [words[0], words[2]])
    }

    @Test func reorderSetsOrder() async throws {
        let database = try await TestDatabase.inMemory()
        let words = (0..<4).map { QuickSearchWord(name: "\($0)", content: "\($0)") }
        for word in words { try await database.insertQuickSearchWord(word) }

        try await database.reorderQuickSearchWords([words[2].id, words[0].id, words[3].id, words[1].id])
        #expect(try await self.words(database) == [words[2], words[0], words[3], words[1]])

        // Words left out keep their relative order after the listed ones.
        try await database.reorderQuickSearchWords([words[1].id])
        #expect(try await self.words(database) == [words[1], words[2], words[0], words[3]])

        // Inserting after a reorder still appends.
        let fifth = QuickSearchWord(name: "4", content: "4")
        try await database.insertQuickSearchWord(fifth)
        #expect(try await self.words(database).last == fifth)
    }

    @Test func observationEmitsOnChange() async throws {
        let database = try await TestDatabase.inMemory()
        let word = QuickSearchWord(name: "One", content: "a")
        let values = try await observe(database.observeQuickSearchWords(), changes: [
            { try await database.insertQuickSearchWord(word) },
            { try await database.deleteQuickSearchWord(id: word.id) }
        ])
        #expect(values == [[], [word], []])
    }
}
