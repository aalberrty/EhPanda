import Dependencies
import EhDatabase
@testable import EhFeatures
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct SearchResultsModelTests {
    private func makeModel(
        _ env: ListTestEnvironment, keyword: String, recordsHistory: Bool
    ) -> SearchResultsModel {
        env.make { SearchResultsModel(keyword: keyword, recordsHistory: recordsHistory) }
    }

    @Test func aTypedSearchRecordsItsKeyword() async throws {
        let env = try ListTestEnvironment()
        let model = makeModel(env, keyword: "language:english", recordsHistory: true)

        await model.start()
        await model.start()

        #expect(try await storedHistory(env.database) == ["language:english"])
        #expect(model.lastKeyword == "language:english")
    }

    @Test func aDetailSearchNeverRecords() async throws {
        let env = try ListTestEnvironment()
        let model = makeModel(env, keyword: "uploader:\"someone\"", recordsHistory: false)

        await model.start()
        model.keyword = "other"
        await model.submit()
        await model.selectQuickSearchWord("f:glasses$")

        #expect(try await storedHistory(env.database).isEmpty)
        #expect(model.lastKeyword == "f:glasses$")
    }

    @Test func searchesTheKeywordWithTheSearchFilter() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        env.filterStore.searchFilter.misc = true
        let model = makeModel(env, keyword: "language:english", recordsHistory: true)

        await model.list.loadIfNeeded()

        #expect(model.list.source == .search(keyword: "language:english"))
        #expect(env.query("f_search", ofRequest: 0) == "language:english")
        #expect(model.list.phase == .content)
        await model.list.loadMore()
        #expect(env.query("next", ofRequest: 1) == ListFixture.frontpageLastID)
        #expect(env.query("f_search", ofRequest: 1) == "language:english")
    }

    @Test func resubmittingSearchesTheNewKeywordAndRecordsIt() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        let model = makeModel(env, keyword: "a", recordsHistory: true)
        await model.start()
        await model.list.loadIfNeeded()
        let request = model.list.loadRequest

        model.keyword = "b"
        await model.submit()

        #expect(model.lastKeyword == "b")
        #expect(model.list.loadRequest != request)
        await model.list.loadIfNeeded()
        #expect(env.query("f_search", ofRequest: 1) == "b")
        #expect(try await storedHistory(env.database) == ["b", "a"])
    }

    @Test func anEmptyFieldSearchesTheLastNonEmptyKeyword() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.frontpage))
        let model = makeModel(env, keyword: "a", recordsHistory: true)
        await model.start()
        model.keyword = "b"
        await model.submit()

        model.keyword = ""
        await model.submit()

        #expect(model.lastKeyword == "b")
        #expect(model.keyword == "")
        #expect(model.list.source == .search(keyword: "b"))
        await model.list.loadIfNeeded()
        #expect(env.query("f_search", ofRequest: 0) == "b")
        #expect(try await storedHistory(env.database) == ["b", "a"])
    }

    @Test func quickSearchClosesTheSheetAndSearchesTheWord() async throws {
        let env = try ListTestEnvironment()
        let model = makeModel(env, keyword: "a", recordsHistory: true)
        model.showQuickSearch()
        #expect(model.sheet == .quickSearch)

        await model.selectQuickSearchWord("f:glasses$")

        #expect(model.sheet == nil)
        #expect(model.keyword == "f:glasses$")
        #expect(model.lastKeyword == "f:glasses$")
        #expect(model.list.source == .search(keyword: "f:glasses$"))
        #expect(try await storedHistory(env.database) == ["f:glasses$"])
    }

    @Test func filtersOpenAsASheet() throws {
        let env = try ListTestEnvironment()
        let model = makeModel(env, keyword: "a", recordsHistory: false)
        model.showFilters()
        #expect(model.sheet == .filters)
    }
}
