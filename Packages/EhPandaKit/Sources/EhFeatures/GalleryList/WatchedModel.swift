import EhModels
import Observation

/// The Watched list: the watched-tags list searched on the server by keyword.
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

    /// Re-selecting the Library tab at its root reloads the list, as it does Favorites (only when
    /// logged in, which the list checks when it loads).
    public func reloadForTabReselection() {
        guard !list.needsLogin else { return }
        list.reload()
    }
}
