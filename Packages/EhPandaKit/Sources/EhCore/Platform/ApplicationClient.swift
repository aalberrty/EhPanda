import Dependencies
import Foundation

/// Which interface orientations the app currently allows.
public enum OrientationLock: Sendable, Equatable {
    /// Portrait and upside-down portrait; the interface is rotated back to portrait if needed.
    case portrait
    /// Every orientation the device supports.
    case unlocked
}

/// App-level system services: external URLs, Settings, the app icon, orientation and idiom.
public struct ApplicationClient: Sendable {
    /// `true` when running on an iPad. The value does not change while the app runs.
    public var isPad: @MainActor @Sendable () -> Bool
    /// Opens a URL outside the app (Safari, another app). Returns whether it was opened.
    public var openURL: @MainActor @Sendable (URL) async -> Bool
    /// Opens the app's page in the Settings app.
    public var openSettings: @MainActor @Sendable () async -> Void
    /// The current alternate icon name, `nil` for the primary icon.
    public var alternateIconName: @MainActor @Sendable () -> String?
    /// Switches the app icon (`nil` restores the primary icon). Returns whether it succeeded.
    public var setAlternateIconName: @MainActor @Sendable (String?) async -> Bool
    /// Changes the allowed interface orientations. Deciding when (reader, iPhone only,
    /// landscape setting) is up to the models.
    public var setOrientationLock: @MainActor @Sendable (OrientationLock) -> Void

    public init(
        isPad: @escaping @MainActor @Sendable () -> Bool,
        openURL: @escaping @MainActor @Sendable (URL) async -> Bool,
        openSettings: @escaping @MainActor @Sendable () async -> Void,
        alternateIconName: @escaping @MainActor @Sendable () -> String?,
        setAlternateIconName: @escaping @MainActor @Sendable (String?) async -> Bool,
        setOrientationLock: @escaping @MainActor @Sendable (OrientationLock) -> Void
    ) {
        self.isPad = isPad
        self.openURL = openURL
        self.openSettings = openSettings
        self.alternateIconName = alternateIconName
        self.setAlternateIconName = setAlternateIconName
        self.setOrientationLock = setOrientationLock
    }
}

extension ApplicationClient: TestDependencyKey {
    public static let testValue = ApplicationClient(
        isPad: unimplemented("ApplicationClient.isPad", placeholder: false),
        openURL: unimplemented("ApplicationClient.openURL", placeholder: false),
        openSettings: unimplemented("ApplicationClient.openSettings"),
        alternateIconName: unimplemented("ApplicationClient.alternateIconName", placeholder: nil),
        setAlternateIconName: unimplemented("ApplicationClient.setAlternateIconName", placeholder: false),
        setOrientationLock: unimplemented("ApplicationClient.setOrientationLock")
    )

    public static let previewValue = ApplicationClient(
        isPad: { false },
        openURL: { _ in true },
        openSettings: {},
        alternateIconName: { nil },
        setAlternateIconName: { _ in true },
        setOrientationLock: { _ in }
    )
}

extension DependencyValues {
    public var applicationClient: ApplicationClient {
        get { self[ApplicationClient.self] }
        set { self[ApplicationClient.self] = newValue }
    }
}
