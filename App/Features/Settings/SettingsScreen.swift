import EhFeatures
import EhModels
import SwiftUI

/// The Settings tab root: one row per settings screen, each pushed as a `Route.settings`.
struct SettingsScreen: View {
    var body: some View {
        List {
            Section {
                SettingsRow(route: .account)
            }
            Section {
                SettingsRow(route: .general)
                SettingsRow(route: .appearance)
                SettingsRow(route: .reading)
                SettingsRow(route: .laboratory)
            }
            Section {
                SettingsRow(route: .about)
            }
        }
        .navigationTitle(L10n.Localizable.SettingView.Title.setting)
    }
}

/// A row that pushes `route` onto the tab's stack (the stack's path is the `StackRouter`'s).
private struct SettingsRow: View {
    let route: SettingsRoute

    var body: some View {
        NavigationLink(value: Route.settings(route)) {
            Label {
                Text(route.rootTitle)
            } icon: {
                SettingsIcon(systemImage: route.rootSymbol, color: route.rootColor)
            }
        }
    }
}

/// A white symbol on a coloured rounded square, as in the system Settings app.
struct SettingsIcon: View {
    let systemImage: String
    let color: Color

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 29

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.55, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .rect(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityHidden(true)
    }
}

private extension SettingsRoute {
    var rootTitle: String {
        switch self {
        case .account: L10n.Localizable.Enum.SettingStateRoute.Value.account
        case .general: L10n.Localizable.Enum.SettingStateRoute.Value.general
        case .appearance: L10n.Localizable.Enum.SettingStateRoute.Value.appearance
        case .reading: L10n.Localizable.Enum.SettingStateRoute.Value.reading
        case .laboratory: L10n.Localizable.Enum.SettingStateRoute.Value.laboratory
        case .about: L10n.Localizable.Enum.SettingStateRoute.Value.about
        case .login, .ehSetting, .logs: ""
        }
    }

    // Legacy symbols (`SettingView.swift`).
    var rootSymbol: String {
        switch self {
        case .account: "person.fill"
        case .general: "switch.2"
        case .appearance: "circle.righthalf.filled"
        case .reading: "newspaper.fill"
        case .laboratory: "testtube.2"
        case .about: "p.circle.fill"
        case .login, .ehSetting, .logs: "gearshape"
        }
    }

    var rootColor: Color {
        switch self {
        case .account: .blue
        case .general: .gray
        case .appearance: .indigo
        case .reading: .orange
        case .laboratory: .purple
        case .about: .teal
        case .login, .ehSetting, .logs: .gray
        }
    }
}

#Preview {
    SettingsPreview { SettingsScreen() }
}
