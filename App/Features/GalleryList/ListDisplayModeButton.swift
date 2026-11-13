import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The list toolbar's switch between rows (Detail) and large covers (Thumbnail). It flips the
/// app-wide `SettingsStore.listDisplayMode`, which Settings › Appearance edits as well, and its
/// symbol shows the mode in use.
struct ListDisplayModeButton: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        let mode = settings.listDisplayMode
        Button(L10n.Localizable.AppearanceSettingView.Title.displayMode, systemImage: mode.symbolName) {
            settings.listDisplayMode = mode.toggled
        }
        .accessibilityValue(mode.localizedName)
        .sensoryFeedback(.selection, trigger: mode)
    }
}

private extension ListDisplayMode {
    var symbolName: String {
        switch self {
        case .detail: "list.bullet"
        case .thumbnail: "square.grid.2x2"
        }
    }
}
