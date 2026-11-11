import EhModels
import SwiftUI

// Image Load Settings and Image Size Settings.

struct ImageLoadSection: View, Equatable {
    let editor: EhSettingEditor
    let value: EhSetting.LoadThroughHathSetting
    let options: [EhSetting.LoadThroughHathSetting]
    let country: EhSetting.BrowsingCountry
    let detectedCountry: String

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.imageLoadSettings,
            description: value.localizedDescription
        ) {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.loadImagesThroughTheHathNetwork,
                selection: editor.binding(\.loadThroughHathSetting, value), options: options, name: \.localizedName
            )
        }
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.browsingCountry, selection: editor.binding(\.browsingCountry, country)) {
                ForEach(EhSetting.BrowsingCountry.allCases) { country in
                    Text(country.localizedName).tag(country)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text(LocalizedStringKey(L10n.Localizable.EhSettingView.Description.browsingCountry(detectedCountry)))
        }
    }
}

struct ImageSizeSection: View, Equatable {
    let editor: EhSettingEditor
    let resolution: EhSetting.ImageResolution
    let resolutions: [EhSetting.ImageResolution]
    let useOriginalImages: Bool?
    let width: Float
    let height: Float

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.imageSizeSettings,
            description: L10n.Localizable.EhSettingView.Description.imageResolution
        ) {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.imageResolution,
                selection: editor.binding(\.imageResolution, resolution), options: resolutions, name: \.localizedName
            )
        }
        if let binding = editor.binding(\.useOriginalImages, useOriginalImages) {
            Section {
                Toggle(L10n.Localizable.EhSettingView.Title.useOriginalImages, isOn: binding)
            } footer: {
                Text(L10n.Localizable.EhSettingView.Section.Title.originalImages)
            }
        }
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Title.imageSize,
            description: L10n.Localizable.EhSettingView.Description.imageSize
        ) {
            ValueSlider(
                title: L10n.Localizable.EhSettingView.Title.horizontal,
                value: editor.binding(\.imageSizeWidth, width), range: 0...65535, unit: "px"
            )
            ValueSlider(
                title: L10n.Localizable.EhSettingView.Title.vertical,
                value: editor.binding(\.imageSizeHeight, height), range: 0...65535, unit: "px"
            )
        }
    }
}
