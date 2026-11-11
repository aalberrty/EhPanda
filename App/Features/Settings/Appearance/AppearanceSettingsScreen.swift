import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Settings › Appearance (legacy `AppearanceSettingView`). The shell applies the colour scheme
/// and accent colour app-wide; this screen only edits them.
struct AppearanceSettingsScreen: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(StackRouter.self) private var stack

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker(L10n.Localizable.AppearanceSettingView.Title.theme, selection: $settings.preferredColorScheme) {
                    ForEach(PreferredColorScheme.allCases) { scheme in
                        Text(scheme.localizedName).tag(scheme)
                    }
                }
                .pickerStyle(.menu)
                ColorPicker(
                    L10n.Localizable.AppearanceSettingView.Title.tintColor,
                    selection: accentColor,
                    supportsOpacity: false
                )
                Button {
                    stack.push(.settings(.appIcon))
                } label: {
                    LabeledContent {
                        Text(settings.appIconType.localizedName)
                    } label: {
                        Text(L10n.Localizable.AppearanceSettingView.Button.appIcon).foregroundStyle(Color.primary)
                    }
                    .disclosureIndicator()
                }
            }
            ListSection()
            Section(L10n.Localizable.AppearanceSettingView.Section.Title.gallery) {
                Toggle(
                    L10n.Localizable.AppearanceSettingView.Title.displaysJapaneseTitle,
                    isOn: $settings.displaysJapaneseTitle
                )
            }
        }
        .navigationTitle(L10n.Localizable.AppearanceSettingView.Title.appearance)
    }

    /// The colour picker works on `Color`; the setting stores sRGB components.
    private var accentColor: Binding<Color> {
        Binding(
            get: { settings.accentColor.color },
            set: { color in
                if let rgb = RGBColor(color) { settings.accentColor = rgb }
            }
        )
    }
}

/// Display mode and tags in list cells.
private struct ListSection: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Section(L10n.Localizable.AppearanceSettingView.Section.Title.list) {
            Picker(L10n.Localizable.AppearanceSettingView.Title.displayMode, selection: $settings.listDisplayMode) {
                ForEach(ListDisplayMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .pickerStyle(.menu)
            Toggle(L10n.Localizable.AppearanceSettingView.Title.showsTagsInList, isOn: $settings.showsTagsInList)
            Picker(
                L10n.Localizable.AppearanceSettingView.Title.maximumNumberOfTags,
                selection: $settings.listTagsNumberMaximum
            ) {
                // 0 means no limit.
                Text(L10n.Localizable.AppearanceSettingView.Menu.Title.infite).tag(0)
                ForEach(Array(stride(from: 5, through: 20, by: 5)), id: \.self) { number in
                    Text(number, format: .number).tag(number)
                }
            }
            .pickerStyle(.menu)
            .disabled(!settings.showsTagsInList)
        }
    }
}

#Preview {
    SettingsPreview { AppearanceSettingsScreen() }
}
