import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Settings › General (legacy `GeneralSettingView`).
struct GeneralSettingsScreen: View {
    @State private var model = GeneralSettingsModel()
    @State private var isConfirmingClearCache = false
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                languageRow
                NavigationLink(value: Route.settings(.logs)) {
                    Text(L10n.Localizable.GeneralSettingView.Button.logs)
                }
            }
            TagTranslationSection()
            Section(L10n.Localizable.GeneralSettingView.Section.Title.navigation) {
                Toggle(
                    L10n.Localizable.GeneralSettingView.Title.redirectsLinksToTheSelectedHost,
                    isOn: $settings.redirectsLinksToSelectedHost
                )
                Toggle(
                    L10n.Localizable.GeneralSettingView.Title.detectsLinksFromClipboard,
                    isOn: $settings.detectsLinksFromClipboard
                )
            }
            SecuritySection(isPasscodeSet: model.isPasscodeSet)
            Section(L10n.Localizable.GeneralSettingView.Section.Title.caches) {
                clearCacheRow
            }
        }
        .navigationTitle(L10n.Localizable.GeneralSettingView.Title.general)
        .task { await model.onAppear() }
    }

    private var languageRow: some View {
        Button {
            Task { await model.openSystemSettings() }
        } label: {
            LabeledContent {
                Text(Self.languageName).foregroundStyle(.tint)
            } label: {
                Text(L10n.Localizable.GeneralSettingView.Title.language).foregroundStyle(Color.primary)
            }
        }
    }

    private var clearCacheRow: some View {
        Button {
            isConfirmingClearCache = true
        } label: {
            LabeledContent {
                if model.isClearingImageCache {
                    ProgressView()
                } else if let size = model.imageCacheSize {
                    Text(Int64(size), format: .byteCount(style: .file)).foregroundStyle(.tint)
                }
            } label: {
                Text(L10n.Localizable.GeneralSettingView.Button.clearImageCaches).foregroundStyle(Color.primary)
            }
        }
        .disabled(model.isClearingImageCache)
        .confirmationDialog(
            L10n.Localizable.ConfirmationDialog.Title.clear,
            isPresented: $isConfirmingClearCache,
            titleVisibility: .visible
        ) {
            Button(L10n.Localizable.ConfirmationDialog.Button.clear, role: .destructive) {
                Task { await model.clearImageCache() }
            }
        }
    }

    /// The app's current language in its own words (legacy `GeneralSettingView.language`).
    private static var languageName: String {
        Locale.current.language.languageCode
            .map(\.identifier)
            .flatMap(Locale.current.localizedString(forLanguageCode:))
            ?? L10n.Localizable.GeneralSettingView.Value.defaultLanguageDescription
    }
}

/// Auto-Lock and the background blur. `SettingsStore` keeps the two consistent.
private struct SecuritySection: View {
    let isPasscodeSet: Bool
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Section(L10n.Localizable.GeneralSettingView.Section.Title.security) {
            Picker(selection: $settings.autoLockPolicy) {
                ForEach(AutoLockPolicy.allCases, id: \.self) { policy in
                    Text(policy.localizedName).tag(policy)
                }
            } label: {
                // Auto-Lock needs a device passcode to unlock the app again.
                HStack {
                    Text(L10n.Localizable.GeneralSettingView.Title.autoLock)
                    if !isPasscodeSet && settings.autoLockPolicy != .never {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .pickerStyle(.menu)
            VStack(alignment: .leading) {
                Text(L10n.Localizable.GeneralSettingView.Title.backgroundBlurRadius)
                Slider(value: $settings.backgroundBlurRadius, in: 0...100, step: 10) {
                    Text(L10n.Localizable.GeneralSettingView.Title.backgroundBlurRadius)
                } minimumValueLabel: {
                    Image(systemName: "eye")
                } maximumValueLabel: {
                    Image(systemName: "eye.slash")
                }
                .accessibilityValue(Text(settings.backgroundBlurRadius, format: .number))
            }
        }
    }
}

#Preview {
    SettingsPreview { GeneralSettingsScreen() }
}
