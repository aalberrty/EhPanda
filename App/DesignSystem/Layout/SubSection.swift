import SwiftUI

/// A titled block on a scrolling screen, such as Home's carousels and Detail's previews and
/// comments (legacy `SubSection`).
///
/// Tapping the title reloads when `reload` is given; a spinner beside it shows `isLoading`.
/// "Show all" sits on the trailing edge and is hidden (but keeps its space) when `showsAll` is false.
struct SubSection<Content: View>: View {
    private let title: String
    private let showsAll: Bool
    private let tint: Color?
    private let isLoading: Bool
    private let reload: (() -> Void)?
    private let showAll: () -> Void
    private let content: Content

    @State private var reloadCount = 0

    init(
        title: String, showsAll: Bool = true, tint: Color? = nil, isLoading: Bool = false,
        reload: (() -> Void)? = nil, showAll: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsAll = showsAll
        self.tint = tint
        self.isLoading = isLoading
        self.reload = reload
        self.showAll = showAll
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Button {
                    reload?()
                    reloadCount += 1
                } label: {
                    HStack(spacing: Tokens.Spacing.small) {
                        Text(title).font(.title3.bold())
                        ProgressView()
                            .opacity(isLoading ? 1 : 0)
                            .animation(.default, value: isLoading)
                    }
                }
                .buttonStyle(.plain)
                .allowsHitTesting(reload != nil)
                .accessibilityAddTraits(.isHeader)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: reloadCount)

                Spacer()

                Button(L10n.Localizable.SubSection.Button.showAll, action: showAll)
                    .font(.subheadline)
                    .tint(tint)
                    .opacity(showsAll ? 1 : 0)
                    .disabled(!showsAll)
                    .accessibilityHidden(!showsAll)
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
