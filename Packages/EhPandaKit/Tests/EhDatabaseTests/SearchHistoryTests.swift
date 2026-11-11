@testable import EhDatabase
import EhTestSupport
import Foundation
import Testing

@Suite struct SearchHistoryTests {
    func keywords(_ database: AppDatabase) async throws -> [String] {
        try await observe(database.observeSearchHistory(), changes: []).first ?? []
    }

    @Test func recordsNewestFirst() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordSearchKeyword("a", at: SampleData.date(1))
        try await database.recordSearchKeyword("b", at: SampleData.date(2))
        try await database.recordSearchKeywords(["c", "d"], at: SampleData.date(3))
        #expect(try await keywords(database) == ["d", "c", "b", "a"])
    }

    @Test func repeatedKeywordMovesToFrontWithNewSpelling() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordSearchKeyword("Glasses", at: SampleData.date(1))
        try await database.recordSearchKeyword("maid", at: SampleData.date(2))
        try await database.recordSearchKeyword("glasses", at: SampleData.date(3))
        #expect(try await keywords(database) == ["glasses", "maid"])
    }

    @Test func ignoresEmptyKeywords() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordSearchKeywords(["", "a", ""], at: SampleData.date(1))
        #expect(try await keywords(database) == ["a"])
    }

    @Test func keepsTwentyNewest() async throws {
        let database = try await TestDatabase.inMemory()
        for index in 0..<25 {
            try await database.recordSearchKeyword("k\(index)", at: SampleData.date(Double(index)))
        }
        let stored = try await keywords(database)
        #expect(stored.count == AppDatabase.searchHistoryLimit)
        #expect(stored.first == "k24")
        #expect(stored.last == "k5")
    }

    @Test func batchKeepsOrderAndDeduplicates() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordSearchKeywords(["a", "b", "A"], at: SampleData.date(1))
        #expect(try await keywords(database) == ["A", "b"])
    }

    @Test func removesAndClears() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordSearchKeywords(["a", "b", "c"], at: SampleData.date(1))
        try await database.removeSearchKeyword("b")
        #expect(try await keywords(database) == ["c", "a"])
        try await database.clearSearchHistory()
        #expect(try await keywords(database).isEmpty)
    }

    @Test func observationEmitsOnChange() async throws {
        let database = try await TestDatabase.inMemory()
        let values = try await observe(database.observeSearchHistory(), changes: [
            { try await database.recordSearchKeyword("a", at: SampleData.date(1)) },
            { try await database.recordSearchKeyword("b", at: SampleData.date(2)) },
            { try await database.removeSearchKeyword("a") }
        ])
        #expect(values == [[], ["a"], ["b", "a"], ["b"]])
    }
}
