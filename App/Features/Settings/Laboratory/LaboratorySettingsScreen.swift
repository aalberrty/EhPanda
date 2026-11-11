import EhCore
import EhFeatures
import SwiftUI

/// Settings › Laboratory (legacy `LaboratorySettingView`).
struct LaboratorySettingsScreen: View {
    @State private var model = LaboratorySettingsModel()
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        Form {
            Section {
                Toggle(isOn: bypassesSNIFiltering) {
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
        }
        .navigationTitle(L10n.Localizable.LaboratorySettingView.Title.laboratory)
        .animation(.default, value: settings.bypassesSNIFiltering)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: settings.bypassesSNIFiltering)
    }

    private var bypassesSNIFiltering: Binding<Bool> {
        Binding(get: { settings.bypassesSNIFiltering }, set: { model.setBypassesSNIFiltering($0) })
    }
}

#Preview {
    SettingsPreview { LaboratorySettingsScreen() }
}
