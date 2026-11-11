import Dependencies
import EhCore
import EhDatabase
import EhModels
import Foundation
import Observation

/// The General screen: device passcode state, the image cache and the system language.
/// Tag translation lives in `TagTranslationSettingsModel`; plain settings bind to
/// `SettingsStore` directly.
@Observable
public final class GeneralSettingsModel {
    /// Size of the on-disk image cache in bytes, `nil` until measured.
    public private(set) var imageCacheSize: Int?
    public private(set) var isClearingImageCache = false
    /// Whether the device has a passcode; auto-lock cannot work without one. Assumed until checked.
    public private(set) var isPasscodeSet = true

    @ObservationIgnored @Dependency(\.imageCacheClient) private var imageCache
    @ObservationIgnored @Dependency(\.database) private var database
    @ObservationIgnored @Dependency(\.biometricsClient) private var biometrics
    @ObservationIgnored @Dependency(\.applicationClient) private var application
    @ObservationIgnored @Dependency(\.appLogger) private var logger

    public init() {}

    /// Checks the passcode and measures the cache; called each time the screen appears.
    public func onAppear() async {
        isPasscodeSet = await Self.checkPasscode(biometrics)
        await refreshImageCacheSize()
    }

    public func refreshImageCacheSize() async {
        do {
            imageCacheSize = try await imageCache.diskCacheSize()
        } catch is CancellationError {
        } catch {
            logger.warning("Failed to measure the image cache: \(error)", category: "Settings")
        }
    }

    /// Clears the image disk cache and forgets every stored image URL, so pages are resolved
    /// again instead of pointing at images that are no longer cached (legacy `removeImageURLs`).
    public func clearImageCache() async {
        guard !isClearingImageCache else { return }
        isClearingImageCache = true
        defer { isClearingImageCache = false }
        await imageCache.clearDiskCache()
        do {
            // A cutoff in the far future treats every gallery as not opened recently,
            // which deletes every stored page.
            try await database.deleteExpiredPages(notOpenedWithin: 0, now: .distantFuture)
        } catch {
            logger.error("Failed to remove stored image URLs: \(error)", category: "Settings")
        }
        await refreshImageCacheSize()
    }

    /// The app language is chosen per app in the Settings app.
    public func openSystemSettings() async {
        await application.openSettings()
    }

    // `LAContext` may block briefly; keep it off the main actor.
    @concurrent
    nonisolated private static func checkPasscode(_ biometrics: BiometricsClient) async -> Bool {
        biometrics.isAvailable()
    }
}
