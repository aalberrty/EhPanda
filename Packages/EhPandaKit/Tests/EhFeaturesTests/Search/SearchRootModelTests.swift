import Dependencies
import EhDatabase
@testable import EhFeatures
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct SearchRootModelTests {
    private func makeModel(_ database: AppDatabase) -> SearchRootModel {
        withDependencies { $0.database = database } operation: { SearchRootModel() }
    }

    @Test func showsTheThreeSectionsFromTheDatabase() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordSearchKeywords(["old", "new"])
        try await database.insertQuickSearchWord(QuickSearchWord(name: "Glasses", content: "f:glasses$"))
        for index in 0..<12 {
            try await database.recordOpened(
                makeGallery(gid: "\(index)"), at: Date(timeIntervalSince1970: Double(index))
            )
        }
        let model = makeModel(database)
        let task = Task { await model.observe() }
        defer { task.cancel() }

        try await eventually {
            !model.historyKeywords.isEmpty && !model.quickSearchWords.isEmpty && !model.recentGalleries.isEmpty
        }

        #expect(model.historyKeywords == ["new", "old"])
        #expect(model.quickSearchKeywords == [SearchKeyword(keyword: "f:glasses$", title: "Glasses")])
        #expect(model.recentGalleries.count == SearchRootModel.recentGalleryLimit)
        #expect(model.recentGalleries.first?.gid == "11")
    }

    @Test func sectionsFollowDatabaseChanges() async throws {
        let database = try await TestDatabase.inMemory()
        let model = makeModel(database)
        let task = Task { await model.observe() }
        defer { task.cancel() }

        try await database.recordSearchKeyword("tag")
        try await eventually { model.historyKeywords == ["tag"] }
    }

    @Test func removingAHistoryKeywordDeletesIt() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordSearchKeywords(["a", "b"])
        let model = makeModel(database)
        let task = Task { await model.observe() }
        defer { task.cancel() }
        try await eventually { model.historyKeywords.count == 2 }

        await model.removeHistoryKeyword("a")

        try await eventually { model.historyKeywords == ["b"] }
        #expect(try await storedHistory(database) == ["b"])
    }

    @Test func quickSearchWordsAreTitledByNameAndDeduplicated() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.insertQuickSearchWord(QuickSearchWord(name: "", content: "a"))
        try await database.insertQuickSearchWord(QuickSearchWord(name: "", content: "a"))
        try await database.insertQuickSearchWord(QuickSearchWord(name: "Named", content: "a"))
        let model = makeModel(database)
        let task = Task { await model.observe() }
        defer { task.cancel() }
        try await eventually { model.quickSearchWords.count == 3 }

        #expect(model.quickSearchKeywords == [
            SearchKeyword(keyword: "a", title: "a"),
            SearchKeyword(keyword: "a", title: "Named")
        ])
    }

    @Test func submittingPushesResultsForTheKeyword() {
        let model = SearchRootModel()
        model.keyword = "language:english"

        model.submit()

        #expect(model.destination?.keyword == "language:english")
    }

    @Test func searchingTheSameKeywordTwicePushesANewScreen() {
        let model = SearchRootModel()
        model.search("a")
        let first = model.destination
        model.search("a")
        #expect(model.destination != first)
    }

    @Test func quickSearchPickSearchesOnceTheSheetIsGone() {
        let model = SearchRootModel()
        model.showQuickSearch()

        model.selectQuickSearchWord("f:glasses$")

        #expect(model.sheet == nil)
        #expect(model.keyword == "f:glasses$")
        #expect(model.destination == nil)

        model.sheetDismissed()
        #expect(model.destination?.keyword == "f:glasses$")

        // Dismissing a sheet without a pick pushes nothing.
        model.destination = nil
        model.showFilters()
        model.sheet = nil
        model.sheetDismissed()
        #expect(model.destination == nil)
    }

    @Test func reselectionPopsTheResultsThenReloads() {
        let model = SearchRootModel()
        model.search("a")

        model.rootReselected()
        #expect(model.destination == nil)
        #expect(model.reloadID == 0)

        model.rootReselected()
        #expect(model.reloadID == 1)
    }

    @Test func reselectionReloadRestartsTheObservation() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.recordSearchKeyword("a")
        let model = makeModel(database)
        var task = Task { await model.observe() }
        try await eventually { model.historyKeywords == ["a"] }

        // The view restarts `observe()` whenever `reloadID` changes.
        let reloadID = model.reloadID
        model.rootReselected()
        #expect(model.reloadID != reloadID)
        task.cancel()
        try await database.recordSearchKeyword("b")
        task = Task { await model.observe() }
        defer { task.cancel() }

        try await eventually { model.historyKeywords == ["b", "a"] }
    }

    @Test func keywordColumnsFollowTheWidth() {
        let items = Array(0..<25)

        #expect(SearchRootModel.columns(items, isRegularWidth: false) == [Array(0..<10)])
        #expect(SearchRootModel.columns(items, isRegularWidth: true) == [
            Array(stride(from: 0, to: 20, by: 2)), Array(stride(from: 1, to: 20, by: 2))
        ])
        #expect(SearchRootModel.columns([1], isRegularWidth: true) == [[1], []])
    }
}
