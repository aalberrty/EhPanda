import Dependencies
import EhCore
import Observation

/// The Reading screen (also embedded in the reader's settings sheet).
@Observable
public final class ReadingSettingsModel {
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.applicationClient) private var application

    public init() {}

    /// Turning landscape off on iPhone rotates the interface back to portrait at once
    /// (legacy `SettingReducer` `onChange(of: \.setting.enablesLandscape)`).
    public func setEnablesLandscape(_ isOn: Bool) {
        settings.enablesLandscape = isOn
        if !isOn && !application.isPad() {
            application.setOrientationLock(.portrait)
        }
    }
}
