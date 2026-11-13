import SwiftUI

/// A Home section's header: the serif title and "Show all ›" (E-Home).
///
/// As before, tapping the title reloads the section and a spinner beside it shows a load in flight.
struct HomeSectionHeader: View {
    let title: String
    let isLoading: Bool
    let reload: () -> Void
    let showAll: () -> Void

    @State private var reloadCount = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the title and "Show all" broke mid-word side by side, so
        // "Show all" goes under the title.
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .center))
        layout {
            Button {
                reload()
                reloadCount += 1
            } label: {
                HStack(spacing: Tokens.Spacing.small) {
                    Text(title)
                        .font(.heading(.title2))
                        .foregroundStyle(.textPrimary)
                    ProgressView()
                        .opacity(isLoading ? 1 : 0)
                        .animation(.default, value: isLoading)
                        .accessibilityHidden(!isLoading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: reloadCount)

            if !isStacked {
                Spacer(minLength: Tokens.Spacing.large)
            }

            Button(action: showAll) {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    Text(L10n.Localizable.SubSection.Button.showAll)
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .fontWeight(.semibold)
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Spacing.large)
    }
}

#Preview {
    SchemePreview {
        VStack(spacing: Tokens.Spacing.xLarge) {
            HomeSectionHeader(title: "Frontpage", isLoading: false, reload: {}, showAll: {})
            HomeSectionHeader(title: "Toplists", isLoading: true, reload: {}, showAll: {})
        }
        .background(.ground)
    }
}
