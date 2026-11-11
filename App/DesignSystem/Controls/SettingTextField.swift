import SwiftUI

/// A compact text field for settings and filter rows (legacy `SettingTextField`).
///
/// Defaults suit numeric bounds such as page ranges: 50 pt wide, centred, filled background, no
/// autocorrection. Pass `width: nil, alignment: .leading, showsBackground: false` for a name
/// field that fills the row.
struct SettingTextField: View {
    @Binding private var text: String
    private let prompt: String?
    private let width: CGFloat?
    private let alignment: TextAlignment
    private let showsBackground: Bool

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    init(
        text: Binding<String>, prompt: String? = nil, width: CGFloat? = 50,
        alignment: TextAlignment = .center, showsBackground: Bool = true
    ) {
        _text = text
        self.prompt = prompt
        self.width = width
        self.alignment = alignment
        self.showsBackground = showsBackground
    }

    var body: some View {
        TextField(text: $text, prompt: prompt.map(Text.init)) {
            Text(prompt ?? "")
        }
        .keyboardType(.numbersAndPunctuation)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .multilineTextAlignment(alignment)
        .padding(.horizontal, showsBackground ? Tokens.Spacing.xSmall : 0)
        .padding(.vertical, showsBackground ? Tokens.Spacing.xxSmall : 0)
        .background(
            .fill.tertiary.opacity(showsBackground ? 1 : 0),
            in: .rect(cornerRadius: Tokens.Radius.field, style: .continuous)
        )
        // Grow the fixed width with Dynamic Type so digits are not clipped.
        .frame(width: width.map { $0 * scale })
    }
}

extension View {
    /// Adds a trailing chevron, like a navigation row (legacy `withArrow`). Prefer a
    /// `NavigationLink` in a `List`, which draws its own; use this for buttons that push.
    func disclosureIndicator(isVisible: Bool = true) -> some View {
        HStack {
            self
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .opacity(isVisible ? 1 : 0)
                .accessibilityHidden(true)
        }
    }
}

private struct SettingTextFieldPreview: View {
    @State private var lower = "10"
    @State private var upper = ""
    @State private var name = "Default profile"

    var body: some View {
        Form {
            LabeledContent {
                HStack {
                    SettingTextField(text: $lower)
                    Text(verbatim: "-")
                    SettingTextField(text: $upper, prompt: "99")
                }
            } label: {
                Text(verbatim: "Pages")
            }
            SettingTextField(text: $name, width: nil, alignment: .leading, showsBackground: false)
            Button {} label: { Text(verbatim: "Quick search").disclosureIndicator() }
        }
        .frame(height: 260)
    }
}

#Preview {
    SchemePreview { SettingTextFieldPreview() }
}
