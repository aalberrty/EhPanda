import EhCore
import EhFeatures
import SwiftUI

/// Settings › Laboratory (legacy `LaboratorySettingView`).
struct LaboratorySettingsScreen: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        // `AppModel` applies the setting to the transport whenever it changes.
        @Bindable var settings = settings
        Form {
            Group {
                Section {
                    Toggle(isOn: $settings.bypassesSNIFiltering) {
                        Label {
                            Text(L10n.Localizable.LaboratorySettingView.Title.bypassesSNIFiltering)
                        } icon: {
                            SettingsIcon(
                                systemImage: "theatermasks.fill",
                                color: settings.bypassesSNIFiltering ? .purple : .gray
                            )
                        }
                    }
                    .tint(.purple)
                }
                #if DEBUG
                // Development aid: drives the reader engine with synthetic pages.
                Section("Debug") {
                    ReaderHarnessLauncher()
                }
                #endif
            }
            .raisedRows()
        }
        .screenGround(.grouped)
        .navigationTitle(L10n.Localizable.LaboratorySettingView.Title.laboratory)
        .animation(.default, value: settings.bypassesSNIFiltering)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: settings.bypassesSNIFiltering)
    }
}

#Preview {
    SettingsPreview { LaboratorySettingsScreen() }
}
