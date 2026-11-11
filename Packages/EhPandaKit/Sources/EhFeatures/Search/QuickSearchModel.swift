import Dependencies
import EhCore
import EhDatabase
import EhModels
import Foundation
import Observation

/// The Quick Search sheet: saved keywords that can be added, edited, deleted and reordered.
@Observable
public final class QuickSearchModel {
    public private(set) var words: [QuickSearchWord] = []
    /// True until the database has delivered the words once.
    public private(set) var isLoading = true
    public var isEditing = false

    /// The word form pushed inside the sheet, and the values it edits.
    public var editor: QuickSearchEditor?
    public var draft = QuickSearchWord.empty
    /// The word awaiting confirmation in the delete dialog.
    public var pendingDeletion: QuickSearchWord?

    @ObservationIgnored @Dependency(\.database) private var database

    public init() {}

    /// Keeps `words` current until the calling task is cancelled.
    public func observe() async {
        do {
            for try await words in database.observeQuickSearchWords() {
                self.words = words
                isLoading = false
            }
        } catch {
            // Only a broken database fails an observation; show what we have.
            isLoading = false
        }
    }

    public func toggleEditing() {
        isEditing.toggle()
    }

    // MARK: Form

    public func startAdding() {
        draft = .empty
        editor = .newWord
    }

    public func startEditing(_ word: QuickSearchWord) {
        draft = word
        editor = .editWord(word.id)
    }

    /// Legacy saved words with empty content, which then searched for nothing.
    public var canSaveDraft: Bool {
        !draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Saves the form and closes it. Does nothing while the content is empty.
    public func saveDraft() async {
        guard canSaveDraft, let editor else { return }
        let word = QuickSearchWord(
            id: draft.id,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            content: draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        switch editor {
        case .newWord:
            words.append(word)
            try? await database.insertQuickSearchWord(word)
        case .editWord:
            if let index = words.firstIndex(where: { $0.id == word.id }) {
                words[index] = word
            }
            try? await database.updateQuickSearchWord(word)
        }
        self.editor = nil
    }

    // MARK: Deleting and moving

    public func requestDeletion(of word: QuickSearchWord) {
        pendingDeletion = word
    }

    public func confirmDeletion() async {
        guard let word = pendingDeletion else { return }
        pendingDeletion = nil
        await delete(ids: [word.id])
    }

    /// Deletion from the list's edit mode, which legacy did not confirm.
    public func delete(atOffsets offsets: IndexSet) async {
        await delete(ids: offsets.compactMap { words.indices.contains($0) ? words[$0].id : nil })
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) async {
        words = Self.moving(words, fromOffsets: source, toOffset: destination)
        try? await database.reorderQuickSearchWords(words.map(\.id))
    }

    /// `List.onMove` semantics (SwiftUI's `move(fromOffsets:toOffset:)`, unavailable here):
    /// `destination` is an offset in the list before the move.
    nonisolated static func moving<Element>(
        _ elements: [Element], fromOffsets source: IndexSet, toOffset destination: Int
    ) -> [Element] {
        let moved = source.filter(elements.indices.contains).map { elements[$0] }
        var result = elements.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertion = destination - source.count(in: 0..<min(destination, elements.count))
        result.insert(contentsOf: moved, at: max(0, min(insertion, result.count)))
        return result
    }

    private func delete(ids: [UUID]) async {
        // The list updates at once; the observation then confirms it.
        words.removeAll { ids.contains($0.id) }
        // The system delete affordance removes one row at a time, so this is a single write.
        for id in ids {
            try? await database.deleteQuickSearchWord(id: id)
        }
    }
}

/// The word form inside the Quick Search sheet.
nonisolated public enum QuickSearchEditor: Hashable, Identifiable, Sendable {
    case newWord
    case editWord(UUID)

    public var id: Self { self }
}
