import EhModels
import Observation

/// The Watched screen: the watched-tags list searched on the server by keyword.
@Observable
public final class WatchedModel {
    /// The search field's text. Only submitting it reloads the list.
    public var keyword = ""
    public let list = GalleryListModel(source: .watched(keyword: ""))

    public init() {}

    /// Loads the list for the field's text (legacy `.onSubmit(of: .search)`).
    public func submitKeyword() {
        list.reset(to: .watched(keyword: keyword))
    }

    /// A word picked in Quick Search replaces the field's text and is searched.
    public func quickSearch(_ word: String) {
        keyword = word
        submitKeyword()
    }
}
