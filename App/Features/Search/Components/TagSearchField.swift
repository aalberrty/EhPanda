import EhFeatures
import EhModels
import SwiftUI

extension View {
    /// A server search field with tag suggestions (legacy `.searchable` + `TagSuggestionView`).
    ///
    /// Typed text is normalised (runs of spaces collapsed, `：` → `:`). Suggestions appear when the
    /// tags extension and "Shows tags search suggestion" are on and a dictionary is installed.
    /// Choosing one replaces the fragment it matched with the tag's keyword.
    func tagSearchable(text: Binding<String>, prompt: String, onSubmit: @escaping () -> Void) -> some View {
        modifier(TagSearchableModifier(text: text, prompt: prompt, onSubmit: onSubmit))
    }
}

private struct TagSearchableModifier: ViewModifier {
    @Binding var text: String
    let prompt: String
    let onSubmit: () -> Void

    @State private var model = TagSuggestionModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .searchable(text: $text, prompt: prompt)
            .searchSuggestions {
                if model.isEnabled, !model.suggestions.isEmpty {
                    // Legacy showed the count only on iPhone; iPad's completion menu has no header.
                    if horizontalSizeClass != .regular {
                        Text(L10n.Localizable.Searchable.Title.matchesCount(model.matchCount))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.suggestions) { item in
                        Button {
                            text = TagSuggestionModel.complete(text, with: item.suggestion)
                        } label: {
                            TagSuggestionRow(item: item)
                        }
                        .tint(.primary)
                    }
                }
            }
            .onSubmit(of: .search, onSubmit)
            .onChange(of: text) { _, newValue in
                let normalized = TagSuggestionModel.normalize(newValue)
                if normalized != newValue {
                    // Runs this handler again with the normalised text.
                    text = normalized
                } else {
                    model.textDidChange(normalized)
                }
            }
            .onDisappear { model.cancel() }
    }
}

private struct TagSuggestionRow: View {
    let item: SearchTagSuggestion

    var body: some View {
        HStack(spacing: Tokens.Spacing.xLarge) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    highlighted(item.displayValue, range: item.suggestion.valueRange, namespace: nil)
                    if let url = item.imageURL {
                        Image(systemName: "photo")
                            .hidden()
                            .overlay { RemoteImage(url: url, size: CGSize(width: 24, height: 24), cornerRadius: 0) }
                    }
                }
                .font(.callout)
                highlighted(item.suggestion.tag.key, range: item.suggestion.keyRange, namespace: namespace)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var namespace: Text {
        let text = Text(verbatim: item.suggestion.tag.namespace.rawValue + ":")
        return item.suggestion.matchesNamespace ? text.foregroundStyle(.tint) : text
    }

    /// The matched part in the tint colour, without parsing Markdown (legacy linked it).
    private func highlighted(_ string: String, range: Range<String.Index>?, namespace: Text?) -> Text {
        let parts = TagSuggestion.segments(of: string, around: range)
        let prefix = namespace ?? Text(verbatim: "")
        let match = Text(verbatim: parts.match).foregroundStyle(.tint)
        return Text("\(prefix)\(Text(verbatim: parts.before))\(match)\(Text(verbatim: parts.after))")
    }
}
