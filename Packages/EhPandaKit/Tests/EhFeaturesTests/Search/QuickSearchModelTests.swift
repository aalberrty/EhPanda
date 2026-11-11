import Dependencies
import EhDatabase
@testable import EhFeatures
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct QuickSearchModelTests {
    private func makeModel(_ database: AppDatabase) -> QuickSearchModel {
        withDependencies { $0.database = database } operation: { QuickSearchModel() }
    }

    /// A model observing `database`, with its first delivery received.
    private func observedModel(_ database: AppDatabase) async throws -> (QuickSearchModel, Task<Void, Never>) {
        let model = makeModel(database)
        let task = Task { await model.observe() }
        try await waitUntil { !model.isLoading }
        return (model, task)
    }

    @Test func loadsUntilTheFirstDelivery() async throws {
        let database = try await TestDatabase.inMemory()
        let model = makeModel(database)
        #expect(model.isLoading)

        let task = Task { await model.observe() }
        defer { task.cancel() }
        try await waitUntil { !model.isLoading }
        #expect(model.words.isEmpty)
    }

    @Test func addingAWordAppendsItAndClosesTheForm() async throws {
        let database = try await TestDatabase.inMemory()
        try await database.insertQuickSearchWord(QuickSearchWord(name: "", content: "first"))
        let (model, task) = try await observedModel(database)
        defer { task.cancel() }

        model.startAdding()
        #expect(model.editor == .newWord)
        model.draft.name = " Glasses "
        model.draft.content = "f:glasses$\n"
        await model.saveDraft()

        #expect(model.editor == nil)
        let stored = try await storedWords(database)
        #expect(stored.map(\.content) == ["first", "f:glasses$"])
        #expect(stored.last?.name == "Glasses")
        try await waitUntil { model.words.count == 2 }
    }

    @Test func emptyContentCannotBeSaved() async throws {
        let database = try await TestDatabase.inMemory()
        let (model, task) = try await observedModel(database)
        defer { task.cancel() }

        model.startAdding()
        model.draft.name = "Name only"
        model.draft.content = "  \n "
        #expect(!model.canSaveDraft)

        await model.saveDraft()

        #expect(model.editor == .newWord)
        #expect(try await storedWords(database).isEmpty)
    }

    @Test func editingAWordUpdatesIt() async throws {
        let database = try await TestDatabase.inMemory()
        let word = QuickSearchWord(name: "Old", content: "old")
        try await database.insertQuickSearchWord(word)
        let (model, task) = try await observedModel(database)
        defer { task.cancel() }

        model.startEditing(word)
        #expect(model.editor == .editWord(word.id))
        #expect(model.draft == word)
        model.draft.content = "new"
        await model.saveDraft()

        #expect(try await storedWords(database) == [QuickSearchWord(id: word.id, name: "Old", content: "new")])
        #expect(model.words.first?.content == "new")
    }

    @Test func deletingAsksForConfirmationFirst() async throws {
        let database = try await TestDatabase.inMemory()
        let word = QuickSearchWord(name: "", content: "a")
        try await database.insertQuickSearchWord(word)
        let (model, task) = try await observedModel(database)
        defer { task.cancel() }

        model.requestDeletion(of: word)
        #expect(model.pendingDeletion == word)
        #expect(try await storedWords(database) == [word])

        await model.confirmDeletion()

        #expect(model.pendingDeletion == nil)
        #expect(model.words.isEmpty)
        #expect(try await storedWords(database).isEmpty)
    }

    @Test func deletingFromEditModeRemovesTheRows() async throws {
        let database = try await TestDatabase.inMemory()
        let words = ["a", "b", "c"].map { QuickSearchWord(name: "", content: $0) }
        for word in words { try await database.insertQuickSearchWord(word) }
        let (model, task) = try await observedModel(database)
        defer { task.cancel() }
        try await waitUntil { model.words.count == 3 }

        await model.delete(atOffsets: IndexSet(integer: 1))

        #expect(model.words.map(\.content) == ["a", "c"])
        #expect(try await storedWords(database).map(\.content) == ["a", "c"])
    }

    @Test func movingReordersAndPersists() async throws {
        let database = try await TestDatabase.inMemory()
        let words = ["a", "b", "c"].map { QuickSearchWord(name: "", content: $0) }
        for word in words { try await database.insertQuickSearchWord(word) }
        let (model, task) = try await observedModel(database)
        defer { task.cancel() }
        try await waitUntil { model.words.count == 3 }

        // Drag "a" below "c".
        await model.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(model.words.map(\.content) == ["b", "c", "a"])
        #expect(try await storedWords(database).map(\.content) == ["b", "c", "a"])
    }

    @Test func moveFollowsListSemantics() {
        let items = ["a", "b", "c", "d"]
        #expect(QuickSearchModel.moving(items, fromOffsets: [3], toOffset: 0) == ["d", "a", "b", "c"])
        #expect(QuickSearchModel.moving(items, fromOffsets: [0], toOffset: 2) == ["b", "a", "c", "d"])
        #expect(QuickSearchModel.moving(items, fromOffsets: [0, 2], toOffset: 4) == ["b", "d", "a", "c"])
        #expect(QuickSearchModel.moving(items, fromOffsets: [1], toOffset: 1) == items)
    }

    @Test func editModeToggles() {
        let model = QuickSearchModel()
        model.toggleEditing()
        #expect(model.isEditing)
        model.toggleEditing()
        #expect(!model.isEditing)
    }
}
