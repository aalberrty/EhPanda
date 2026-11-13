import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Maps a `SettingsRoute` to its screen. Every settings screen is tinted with the app's tint
/// (the accent colour), as in legacy.
struct SettingsDestination: View {
    let route: SettingsRoute

    @Environment(SettingsStore.self) private var settings

    var body: some View {
        screen.tint(settings.accentColor.appTint)
    }

    @ViewBuilder private var screen: some View {
        switch route {
        case .account: AccountSettingScreen()
        case .login: LoginScreen()
        case .ehSetting: EhSettingScreen()
        case .general: GeneralSettingsScreen()
        case .appearance: AppearanceSettingsScreen()
        case .appIcon: AppIconScreen()
        case .reading: ReadingSettingsScreen()
        case .laboratory: LaboratorySettingsScreen()
        case .logs: LogsScreen()
        case .log(let file): LogDetailScreen(file: file)
        case .about: AboutScreen()
        }
    }
}
