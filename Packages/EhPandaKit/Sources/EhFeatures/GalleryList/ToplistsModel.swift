import Dependencies
import EhModels
import Observation

/// The Toplists screen. Each period keeps its own list, page and loading state, so switching
/// back shows what was already loaded.
@Observable
public final class ToplistsModel {
    public private(set) var type: ToplistsType = .yesterday
    public private(set) var list: GalleryListModel
    /// The local title filter, shared by every period.
    public var titleFilter = "" {
        didSet { list.titleFilter = titleFilter }
    }
    public var isJumpPagePresented = false
    public var jumpPageText = ""

    /// Unused directly: `withDependencies(from: self)` reads the dependencies it captured, so
    /// lists made after `init` use the same client and stores as the first one.
    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored private var lists: [ToplistsType: GalleryListModel]

    public init() {
        let list = GalleryListModel(source: .toplists(.yesterday))
        self.list = list
        lists = [.yesterday: list]
    }

    public func select(_ type: ToplistsType) {
        guard type != self.type else { return }
        self.type = type
        // Lists made later still use this model's dependencies.
        let list = lists[type] ?? withDependencies(from: self) { GalleryListModel(source: .toplists(type)) }
        lists[type] = list
        list.titleFilter = titleFilter
        self.list = list
    }

    public func presentJumpPage() {
        jumpPageText = ""
        isJumpPagePresented = true
    }

    /// Jumps to the typed page. Returns `false` for anything but a page of the current list.
    @discardableResult
    public func confirmJumpPage() -> Bool {
        guard list.jumpToPage(jumpPageText) else { return false }
        isJumpPagePresented = false
        return true
    }
}
