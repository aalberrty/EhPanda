import Dependencies
import Foundation
import LocalAuthentication

/// Device owner authentication (Face ID / Touch ID with passcode fallback) for the app lock.
public struct BiometricsClient: Sendable {
    /// Whether the device can authenticate its owner. `false` when no passcode is set.
    public var isAvailable: @Sendable () -> Bool
    /// Prompts for authentication with a caller-supplied localized reason.
    /// Returns `false` when unavailable, cancelled or failed.
    public var authenticate: @Sendable (_ localizedReason: String) async -> Bool

    public init(
        isAvailable: @escaping @Sendable () -> Bool,
        authenticate: @escaping @Sendable (_ localizedReason: String) async -> Bool
    ) {
        self.isAvailable = isAvailable
        self.authenticate = authenticate
    }
}

extension BiometricsClient: DependencyKey {
    // `.deviceOwnerAuthentication` falls back to the passcode, matching the legacy app lock.
    public static let liveValue = BiometricsClient(
        isAvailable: {
            var error: NSError?
            return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        },
        authenticate: { reason in
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                return false
            }
            do {
                return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            } catch {
                return false
            }
        }
    )

    public static let testValue = BiometricsClient(
        isAvailable: unimplemented("BiometricsClient.isAvailable", placeholder: false),
        authenticate: unimplemented("BiometricsClient.authenticate", placeholder: false)
    )

    public static let previewValue = BiometricsClient(
        isAvailable: { true },
        authenticate: { _ in true }
    )
}

extension DependencyValues {
    public var biometricsClient: BiometricsClient {
        get { self[BiometricsClient.self] }
        set { self[BiometricsClient.self] = newValue }
    }
}
