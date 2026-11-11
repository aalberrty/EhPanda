import EhCore
import EhFeatures
import SwiftUI

/// The Tags section of Settings › General.
struct TagTranslationSection: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Section(L10n.Localizable.GeneralSettingView.Section.Title.tags) {
            Toggle(L10n.Localizable.GeneralSettingView.Title.enablesTagsExtension, isOn: $settings.enablesTagsExtension)
            if settings.enablesTagsExtension {
                Toggle(L10n.Localizable.GeneralSettingView.Title.translatesTags, isOn: $settings.translatesTags)
                Toggle(
                    L10n.Localizable.GeneralSettingView.Title.showsTagsSearchSuggestion,
                    isOn: $settings.showsTagsSearchSuggestion
                )
                Toggle(L10n.Localizable.GeneralSettingView.Title.showsImagesInTags, isOn: $settings.showsImagesInTags)
            }
        }
    }
}
