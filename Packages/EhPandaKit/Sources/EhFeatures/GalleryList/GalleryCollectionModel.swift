import Dependencies
import EhCore
import EhDatabase
import EhModels
import Observation

/// What the galleries of a list do besides opening their detail page: the long-press peek's
/// Read opens the reader straight over the list.
///
/// One per list on screen, owned by the view that draws the galleries. The reader is a
/// full-screen cover driven by `readingGallery`.
@Observable
public final class GalleryCollectionModel {
    /// The gallery being read, as a binding target for `fullScreenCover(item:)`.
    public var readingGallery: Gallery?

    /// The last history write, kept so tests can wait for it.
    @ObservationIgnored private(set) var recording: Task<Void, Never>?

    @ObservationIgnored @Dependency(\.database) private var database

    public init() {}

    /// Opens the reader at the stored reading progress. The gallery is recorded as opened, as
    /// its detail page records it, so History lists what was read from a list too.
    public func read(_ gallery: Gallery) {
        readingGallery = gallery
        // Not tied to the list: the write is short and should land even if the list goes away.
        recording = Task { [database] in
            try? await database.recordOpened(gallery)
        }
    }
}

extension ListDisplayMode {
    /// The other mode: what the list toolbar's display-mode button switches to.
    public var toggled: ListDisplayMode {
        switch self {
        case .detail: .thumbnail
        case .thumbnail: .detail
        }
    }
}
