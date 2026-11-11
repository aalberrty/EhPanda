import EhModels
import SwiftUI

// Ratings through Excluded Uploaders: what the site filters out or highlights.

struct RatingsSection: View, Equatable {
    let editor: EhSettingEditor
    let value: String

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.ratings,
            description: L10n.Localizable.EhSettingView.Description.ratingsColor
        ) {
            LabeledContent(L10n.Localizable.EhSettingView.Title.ratingsColor) {
                SettingTextField(
                    text: editor.binding(\.ratingsColor, value),
                    prompt: L10n.Localizable.EhSettingView.Promt.ratingsColor, width: 80
                )
            }
        }
    }
}

struct TagWatchingSection: View, Equatable {
    let editor: EhSettingEditor
    let value: Float

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.tagWatchingThreshold,
            description: L10n.Localizable.EhSettingView.Description.tagWatchingThreshold
        ) {
            ValueSlider(
                title: L10n.Localizable.EhSettingView.Title.tagWatchingThreshold,
                value: editor.binding(\.tagWatchingThreshold, value), range: 0...9999
            )
        }
    }
}

struct TagFilteringSection: View, Equatable {
    let editor: EhSettingEditor
    let value: Float

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.tagFilteringThreshold,
            description: L10n.Localizable.EhSettingView.Description.tagFilteringThreshold
        ) {
            ValueSlider(
                title: L10n.Localizable.EhSettingView.Title.tagFilteringThreshold,
                value: editor.binding(\.tagFilteringThreshold, value), range: -9999...0
            )
        }
    }
}

struct FilteredRemovalSection: View, Equatable {
    let editor: EhSettingEditor
    let isOn: Bool

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.filteredRemovalCount,
            description: L10n.Localizable.EhSettingView.Description.filteredRemovalCount
        ) {
            Toggle(
                L10n.Localizable.EhSettingView.Title.showFilteredRemovalCount,
                isOn: editor.binding(\.showFilteredRemovalCount, isOn)
            )
        }
    }
}

/// A grid of languages × original / translated / rewrite. The flags are stored per language in
/// that order, except that Japanese has no "original" flag, so language `n` starts at `3n - 1`.
struct ExcludedLanguagesSection: View, Equatable {
    let editor: EhSettingEditor
    let values: [Bool]

    @ScaledMetric(relativeTo: .subheadline) private var columnWidth: CGFloat = 72

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.editor == rhs.editor && lhs.values == rhs.values
    }

    var body: some View {
        let flags = editor.binding(\.excludedLanguages, values)
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.excludedLanguages,
            description: L10n.Localizable.EhSettingView.Description.excludedLanguages
        ) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ForEach(EhSetting.ExcludedLanguagesCategory.allCases) { category in
                    Text(category.localizedName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(width: columnWidth)
                }
            }
            .accessibilityHidden(true)
            ForEach(Array(Language.allExcludedCases.enumerated()), id: \.element) { row, language in
                HStack(spacing: 0) {
                    Text(language.localizedName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(EhSetting.ExcludedLanguagesCategory.allCases) { category in
                        let index = row * 3 + category.rawValue - 1
                        Group {
                            if flags.wrappedValue.indices.contains(index) {
                                ExcludeToggle(
                                    language: language.localizedName, category: category.localizedName,
                                    isOn: flags[index]
                                )
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: columnWidth)
                    }
                }
            }
        }
    }
}

private struct ExcludeToggle: View {
    let language: String
    let category: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation { isOn.toggle() }
        } label: {
            Image(systemName: isOn ? "nosign" : "circle")
                .font(.title2)
                .foregroundStyle(isOn ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isOn)
        .accessibilityLabel(Text(verbatim: "\(language), \(category)"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct ExcludedUploadersSection: View, Equatable {
    let editor: EhSettingEditor
    let text: String

    var body: some View {
        Section {
            TextEditor(text: editor.binding(\.excludedUploaders, text))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 120, maxHeight: 280)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.excludedUploaders)
        } footer: {
            VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                Text(L10n.Localizable.EhSettingView.Description.excludedUploaders)
                Text(LocalizedStringKey(
                    L10n.Localizable.EhSettingView.Description.excludedUploadersCount(lineCount, 1000)
                ))
            }
        }
    }

    /// Non-empty lines, one uploader each.
    private var lineCount: Int {
        var count = 0
        text.enumerateLines { line, _ in
            if !line.isEmpty { count += 1 }
        }
        return count
    }
}
