/// What a pushed screen asks of the tab bar.
nonisolated public enum TabBarVisibility: Hashable, Sendable {
    /// Leaves the tab bar to the screen above it.
    case automatic
    case visible
    case hidden
}

extension Route {
    /// Whether the tab bar is hidden while this route is the top screen of its stack.
    ///
    /// E-Detail draws a gallery without the tab bar, and the screens pushed from it (comments,
    /// previews, gallery infos) hide it too, so it does not come and go between them. Every other
    /// screen shows it, including a search opened from a gallery's tag, uploader or similar
    /// galleries.
    public var hidesTabBar: Bool {
        switch self {
        case .detail, .detailChild: true
        case .galleryList, .search, .typedSearch, .settings: false
        }
    }
}

extension StackRouter {
    /// What the screen for `route` asks of the tab bar: the top screen shows or hides it, the
    /// screens below leave it to the top one. The tab bar so follows the top screen alone, at
    /// any depth: shown on a search pushed above a gallery, hidden again on a gallery pushed
    /// above that search.
    ///
    /// A route equal to the top one further down the stack asks the same as the top one, which
    /// changes nothing.
    public func tabBarVisibility(for route: Route) -> TabBarVisibility {
        guard path.last == route else { return .automatic }
        return route.hidesTabBar ? .hidden : .visible
    }
}
