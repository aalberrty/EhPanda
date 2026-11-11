import EhModels
import Foundation

/// Reads the selected gallery host from any thread.
///
/// `SettingsStore` writes `galleryHost` synchronously to the shared `"galleryHost"` key, so a
/// request built right after the user switches hosts already sees the new one. Hand this to
/// code that builds URLs off the main actor instead of the main-actor `SettingsStore`.
public struct GalleryHostProvider: Sendable {
    private let storage: PreferenceStorage

    public init(defaults: UserDefaults) {
        self.init(storage: PreferenceStorage(defaults))
    }

    init(storage: PreferenceStorage) {
        self.storage = storage
    }

    public var current: GalleryHost {
        storage.value(.galleryHost, fallback: Setting().galleryHost)
    }

    /// The provider as a closure, for layers that cannot import `EhCore` (such as
    /// `EhNetworking`, which sits below it).
    public var currentHost: @Sendable () -> GalleryHost {
        { [self] in current }
    }
}
