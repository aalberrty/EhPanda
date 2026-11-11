import EhFeatures
import SwiftUI

/// Writes a new comment or edits one. Confirm sends the text and closes the sheet at once; the
/// result shows as a haptic and a refreshed list, as in legacy.
struct PostCommentSheet: View {
    let composer: CommentComposer
    let onPost: (String) -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(composer: CommentComposer, onPost: @escaping (String) -> Void) {
        self.composer = composer
        self.onPost = onPost
        _text = State(initialValue: composer.initialText)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        SheetConfirmButton {
                            onPost(text)
                            dismiss()
                        }
                        .disabled(text.isEmpty)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        // Legacy focused the editor once the sheet had finished appearing.
        .task {
            try? await Task.sleep(for: .milliseconds(750))
            isFocused = true
        }
    }

    private var title: String {
        composer.isEditing
            ? L10n.Localizable.PostCommentView.Title.editComment
            : L10n.Localizable.PostCommentView.Title.postComment
    }
}
