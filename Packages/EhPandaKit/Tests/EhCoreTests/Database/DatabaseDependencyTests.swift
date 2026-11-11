import Dependencies
import EhCore
import EhDatabase
import EhModels
import Foundation
import Testing

@Suite struct DatabaseDependencyTests {
    @Test func testValueIsAnEmptyUsableDatabase() async throws {
        @Dependency(\.database) var database
        let gallery = try await database.gallery(gid: "1")
        #expect(gallery == nil)
    }

    @Test func overriddenDatabaseIsTheOneModelsSee() async throws {
        let seeded = try AppDatabase.makeInMemory()
        try await seeded.recordSearchKeyword("language:english", at: Date())

        try await withDependencies {
            $0.database = seeded
        } operation: {
            @Dependency(\.database) var database
            var keywords: [String] = []
            for try await value in database.observeSearchHistory() {
                keywords = value
                break
            }
            #expect(keywords == ["language:english"])
        }
    }
}
