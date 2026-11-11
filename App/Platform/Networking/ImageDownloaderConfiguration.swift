import EhCore
import EhNetworking
import Foundation
import Kingfisher

/// The image downloader's network settings (legacy `LibraryClient.initializeWebImage` and the
/// image half of `DFClient`).
///
/// Uses `ImageDownloader.default`, the downloader `KingfisherManager.shared` is built with,
/// without touching `KingfisherManager.shared` itself: that would create the disk cache, and its
/// directories, on the main thread at launch.
enum ImageDownloaderConfiguration {
    /// Image requests carry the site's cookies (ExHentai images need the login) from the jar the
    /// app's requests and web views share. Kingfisher's default configuration is ephemeral, with
    /// a jar of its own.
    static func configure() {
        update { $0.httpCookieStorage = .shared }
    }

    /// Routes image downloads through domain fronting, or back.
    static func setDomainFronting(_ enabled: Bool) {
        guard ImageDownloader.default.sessionConfiguration.isDomainFrontingEnabled != enabled else { return }
        update { $0.setDomainFronting(enabled) }
    }

    /// Kingfisher rebuilds its session, cancelling downloads in flight, whenever the
    /// configuration is assigned, so callers change it only when needed.
    private static func update(_ change: (URLSessionConfiguration) -> Void) {
        let downloader = ImageDownloader.default
        guard let configuration = downloader.sessionConfiguration.copy() as? URLSessionConfiguration else { return }
        change(configuration)
        downloader.sessionConfiguration = configuration
    }
}

extension DomainFrontingClient {
    /// The app's transport and the image downloader, switched together. The app installs it as
    /// `\.domainFronting` at startup, so the launch sequence and the Laboratory setting reach both.
    nonisolated static let appWide: DomainFrontingClient = {
        let transport = DomainFrontingClient.liveValue
        return DomainFrontingClient(
            isEnabled: { transport.isEnabled() },
            setEnabled: { enabled in
                transport.setEnabled(enabled)
                // Kingfisher's downloader is not thread-safe; it is only configured on the main thread.
                if Thread.isMainThread {
                    MainActor.assumeIsolated { ImageDownloaderConfiguration.setDomainFronting(enabled) }
                } else {
                    Task { @MainActor in ImageDownloaderConfiguration.setDomainFronting(enabled) }
                }
            }
        )
    }()
}
