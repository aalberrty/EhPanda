import SwiftUI

/// "Show all ›" as every section header draws it (E-Home, E-Search, E-Detail): the text in
/// `textSecondary` and a small semibold forward chevron. The label of a header's button; the
/// header adds the tap target it needs.
struct ShowAllLabel: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xxSmall) {
            Text(L10n.Localizable.SubSection.Button.showAll)
            Image(systemName: "chevron.forward")
                .imageScale(.small)
                .fontWeight(.semibold)
                .accessibilityHidden(true)
        }
        .font(.subheadline)
        .foregroundStyle(.textSecondary)
    }
}

#Preview {
    SchemePreview {
        ShowAllLabel()
            .padding()
            .background(.ground)
    }
}
