import SwiftUI

/// A titled block on a scrolling screen, such as Home's carousels and Detail's previews and
/// comments (legacy `SubSection`).
///
/// Tapping the title reloads when `reload` is given; a spinner beside it shows `isLoading`.
/// "Show all ›" (`ShowAllLabel`) sits on the trailing edge, on the title's baseline; it is
/// hidden (but keeps its space) when `showsAll` is false.
struct SubSection<Content: View>: View {
    private let title: String
    private let showsAll: Bool
    private let isLoading: Bool
    private let reload: (() -> Void)?
    private let showAll: () -> Void
    private let content: Content

    @State private var reloadCount = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        title: String, showsAll: Bool = true, isLoading: Bool = false,
        reload: (() -> Void)? = nil, showAll: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsAll = showsAll
        self.isLoading = isLoading
        self.reload = reload
        self.showAll = showAll
        self.content = content()
    }

    var body: some View {
        // At accessibility sizes the title and "Show all" broke mid-word side by side, so
        // "Show all" goes under the title.
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let header = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            header {
                Button {
                    reload?()
                    reloadCount += 1
                } label: {
                    HStack(spacing: Tokens.Spacing.small) {
                        Text(title).font(.sectionTitle)
                        // A spinner reports a text baseline near its top, and a stack takes the
                        // topmost one, which lifted "Show all" above the title. Its bottom
                        // stays below the title's baseline, so the title's baseline leads.
                        ProgressView()
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                            .alignmentGuide(.lastTextBaseline) { $0[.bottom] }
                            .opacity(isLoading ? 1 : 0)
                            .animation(.default, value: isLoading)
                            .accessibilityHidden(!isLoading)
                    }
                }
                .buttonStyle(.plain)
                .allowsHitTesting(reload != nil)
                .accessibilityAddTraits(.isHeader)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: reloadCount)

                if !isStacked {
                    Spacer()
                }

                // Under the title, a hidden "Show all" would only leave an empty line.
                if showsAll || !isStacked {
                    Button(action: showAll) {
                        ShowAllLabel()
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .opacity(showsAll ? 1 : 0)
                    .disabled(!showsAll)
                    .accessibilityHidden(!showsAll)
                }
            }
            .padding(.horizontal)
            content
        }
    }
}

private struct SubSectionPreview: View {
    var body: some View {
        VStack(spacing: Tokens.Spacing.xLarge) {
            SubSection(title: "Popular", isLoading: true, reload: {}) {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(0..<6) { _ in ImagePlaceholder(style: .plain).frame(width: 100) }
                    }
                    .padding(.horizontal)
                }
            }
            SubSection(title: "Other", showsAll: false) {
                Text(verbatim: "Content").padding(.horizontal)
            }
        }
    }
}

#Preview {
    SchemePreview { SubSectionPreview() }
}
