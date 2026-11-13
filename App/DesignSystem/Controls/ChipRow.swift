import SwiftUI

/// One-tap chips that pick one option, in a row that scrolls sideways when they do not fit:
/// Library's favourite folders, the Toplists periods. The selected chip is inverted and
/// scrolls into view. Put it in a `floatingBar` under the title.
///
/// It takes the selection and an action rather than a binding, as `SegmentedControl` does, so a
/// model method makes the change.
struct ChipRow<Option: Identifiable>: View {
    private let title: String
    private let options: [Option]
    private let selection: Option.ID
    private let optionTitle: (Option) -> String
    private let onSelect: (Option) -> Void

    /// `title` names the row for VoiceOver.
    init(
        _ title: String, options: [Option], selection: Option.ID,
        optionTitle: @escaping (Option) -> String, onSelect: @escaping (Option) -> Void
    ) {
        self.title = title
        self.options = options
        self.selection = selection
        self.optionTitle = optionTitle
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Tokens.Spacing.small) {
                    ForEach(options) { option in
                        Chip(title: optionTitle(option), isSelected: option.id == selection) {
                            onSelect(option)
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.large)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selection, initial: true) { old, selection in
                guard selection != old else {
                    // Appearing (after logging in, say): no animation.
                    proxy.scrollTo(selection, anchor: .center)
                    return
                }
                withAnimation { proxy.scrollTo(selection, anchor: .center) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// A chip: a filled capsule in a full-height touch target, inverted when selected.
///
/// The fills are colours rather than hierarchical styles: on the iOS 18 bar material
/// `.primary` and `.fill` turn into vibrant greys, and the selected chip would lose its contrast.
private struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.onSelectedFill : Color.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .background(isSelected ? Color.selectedFill : Color.chipFill, in: .capsule)
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ChipRowPreview: View {
    @State private var selection = 0

    var body: some View {
        ChipRow(
            "Periods", options: PreviewOption.all, selection: selection,
            optionTitle: \.title, onSelect: { selection = $0.id }
        )
        .padding(.vertical)
        .background(.ground)
    }

    private struct PreviewOption: Identifiable {
        static let all = ["Yesterday", "Past month", "Past year", "All time"].enumerated()
            .map { PreviewOption(id: $0.offset, title: $0.element) }

        let id: Int
        let title: String
    }
}

#Preview {
    SchemePreview {
        ChipRowPreview()
    }
}
