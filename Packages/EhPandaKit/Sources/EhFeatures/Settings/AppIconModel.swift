import Dependencies
import EhCore
import EhModels
import Observation

/// The app icon picker. The selected icon is `SettingsStore.appIconType`, kept in step with
/// the icon the system actually shows.
@Observable
public final class AppIconModel {
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.applicationClient) private var application

    public init() {}

    /// Asks the system to switch icons (it shows its own alert), then records what it reports,
    /// so a refused change does not leave the wrong icon checked.
    public func select(_ icon: AppIconType) async {
        settings.appIconType = icon
        // Legacy also set the default icon as an alternate (`AppIcon_Default` is declared in
        // `CFBundleAlternateIcons`), so every choice goes through the same path.
        _ = await application.setAlternateIconName(icon.filename)
        syncWithSystem()
    }

    /// Sets `appIconType` to the icon the system reports; the primary icon is `.default`.
    public func syncWithSystem() {
        settings.appIconType = Self.iconType(forAlternateIconName: application.alternateIconName())
    }

    nonisolated static func iconType(forAlternateIconName name: String?) -> AppIconType {
        guard let name else { return .default }
        return AppIconType.allCases.first { $0.filename == name } ?? .default
    }
}
