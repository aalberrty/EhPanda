import SwiftUI

/// A segmented control, such as Library's Favorites / Watched / History.
///
/// iOS 26, as drawn in E-Library: a glass capsule whose selected segment is a `selectedFill`
/// capsule that slides between the segments. iOS 18 keeps the native segmented picker.
///
/// It takes the selection and an action rather than a binding, so a model method can make the
/// change (passing one to `Binding(set:)` directly crashes the Swift 6.2 compiler).
struct SegmentedControl<Value: Hashable>: View {
    private let title: String
    private let options: [Value]
    private let selection: Value
    private let optionTitle: (Value) -> String
    private let onSelect: (Value) -> Void

    init(
        _ title: String, options: [Value], selection: Value,
        optionTitle: @escaping (Value) -> String, onSelect: @escaping (Value) -> Void
    ) {
        self.title = title
        self.options = options
        self.selection = selection
        self.optionTitle = optionTitle
        self.onSelect = onSelect
    }

    var body: some View {
        if AppLook.isRedesigned {
            GlassSegments(
                title: title, options: options, selection: selection,
                optionTitle: optionTitle, onSelect: onSelect
            )
        } else {
            Picker(title, selection: Binding(get: { selection }, set: { onSelect($0) })) {
                ForEach(options, id: \.self) { option in
                    Text(optionTitle(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
        }
    }
}

private struct GlassSegments<Value: Hashable>: View {
    let title: String
    let options: [Value]
    let selection: Value
    let optionTitle: (Value) -> String
    let onSelect: (Value) -> Void

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                segment(option, isSelected: option == selection)
            }
        }
        .padding(3)
        .glassSurface(in: .capsule, tone: .bar)
        .animation(.snappy(duration: 0.25), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func segment(_ option: Value, isSelected: Bool) -> some View {
        Button {
            onSelect(option)
        } label: {
            Text(optionTitle(option))
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Color.onSelectedFill : Color.textSecondary)
                .padding(.horizontal, Tokens.Spacing.small)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.selectedFill)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("SegmentedControl") {
    @Previewable @State var selection = 0
    SegmentedControl(
        "Library", options: [0, 1, 2], selection: selection,
        optionTitle: { ["Favorites", "Watched", "History"][$0] }, onSelect: { selection = $0 }
    )
    .padding()
}
