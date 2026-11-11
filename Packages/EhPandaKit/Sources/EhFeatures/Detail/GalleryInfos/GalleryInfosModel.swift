import Dependencies
import EhCore
import EhModels
import EhNetworking
import Foundation
import Observation

/// Gallery Infos: every field of the gallery and its detail, each copyable.
@Observable
public final class GalleryInfosModel {
    public let gallery: Gallery
    public let detail: GalleryDetail

    /// Counts copies, for the HUD and haptic.
    public private(set) var copyCount = 0

    @ObservationIgnored @Dependency(\.clipboardClient) private var clipboard
    @ObservationIgnored @Dependency(\.settings) private var settings

    public init(gallery: Gallery, detail: GalleryDetail) {
        self.gallery = gallery
        self.detail = detail
    }

    /// The gallery's torrent page on the selected site, as legacy showed it.
    public var torrentURL: URL {
        EhRequestBuilder(host: settings.galleryHost).galleryTorrentsURL(gid: gallery.gid, token: gallery.token)
    }

    public func copy(_ text: String) {
        clipboard.copyText(text)
        copyCount += 1
    }
}
