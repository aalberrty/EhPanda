import Dependencies
import EhCore
import Observation

/// The Laboratory screen.
@Observable
public final class LaboratorySettingsModel {
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.domainFronting) private var domainFronting

    public init() {}

    /// Stores the setting and switches domain fronting on the app's transport at once.
    /// The image downloader follows the setting in the app target.
    public func setBypassesSNIFiltering(_ isOn: Bool) {
        settings.bypassesSNIFiltering = isOn
        domainFronting.setEnabled(isOn)
    }
}
