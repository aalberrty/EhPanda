import EhModels
import Foundation

/// A screen the detail screen shows on top of itself. Only one is shown at a time.
public enum DetailDestination: Hashable, Sendable {
    /// Pushed. `scrollTo` is a comment to scroll to and highlight once the list appears.
    case comments(scrollTo: String?)
    /// Pushed: every page's preview.
    case previews
    /// Pushed.
    case galleryInfos
    /// Sheet.
    case archives(archiveURL: URL)
    /// Sheet.
    case torrents
    /// Sheet.
    case postComment
    /// Sheet.
    case tagDetail(TagDetail)
    /// Full screen. `page` is 1-based; `nil` opens at the stored reading progress.
    case reader(page: Int?)

    public enum Presentation: Sendable {
        case push
        case sheet
        case fullScreen
    }

    public var presentation: Presentation {
        switch self {
        case .comments, .previews, .galleryInfos: .push
        case .archives, .torrents, .postComment, .tagDetail: .sheet
        case .reader: .fullScreen
        }
    }
}

extension DetailDestination: Identifiable {
    public var id: Self { self }
}

/// Something a detail screen should do as soon as it has opened, asked for by whoever opened
/// it: a comment link to a page opens the reader there, a link to a comment opens the comments
/// at that comment. `Route.detail` carries only the gallery, so the request is left here, keyed
/// by gallery id, and the detail screen of that gallery takes it when it loads.
public enum DetailIntent: Hashable, Sendable {
    case read(page: Int)
    case comments(scrollTo: String)
}

/// Pending `DetailIntent`s. Set one right before pushing or presenting the gallery's detail.
public final class DetailIntents {
    public static let shared = DetailIntents()

    private var pending: [String: DetailIntent] = [:]

    public init() {}

    public func set(_ intent: DetailIntent, for gid: String) {
        pending[gid] = intent
    }

    /// Removes and returns the intent for `gid`.
    public func take(for gid: String) -> DetailIntent? {
        pending.removeValue(forKey: gid)
    }
}

/// The keywords the detail screen searches for, exactly as legacy built them.
public nonisolated enum DetailSearchKeyword {
    /// An exact tag match, e.g. `f:"big breasts$"`; `temp` tags have no namespace.
    public static func tag(_ content: GalleryTag.Content, in tag: GalleryTag) -> String {
        content.searchKeyword(tag: tag)
    }

    public static func uploader(_ uploader: String) -> String {
        "uploader:" + "\"\(uploader)\""
    }

    /// "Similar gallery": the title up to the first `|`, without bracketed groups.
    public static func similar(to detail: GalleryDetail) -> String {
        detail.trimmedTitle
    }
}
