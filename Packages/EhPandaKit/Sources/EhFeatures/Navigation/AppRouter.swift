import EhModels
import Observation

/// App-level navigation state: the selected tab, one stack per tab, and the gallery sheet
/// used for galleries opened from outside the tab hierarchy.
@Observable
public final class AppRouter {
    public private(set) var selectedTab: AppTab = .home

    public let home = StackRouter()
    public let favorites = StackRouter()
    public let search = StackRouter()
    public let settings = StackRouter()

    /// A gallery opened from a deep link, a clipboard link or the share extension.
    /// It is shown as a sheet with its own stack (`presented`) on top of the tabs.
    public private(set) var presentedGallery: Gallery?
    public let presented = StackRouter()

    /// How many times each tab was re-selected while already showing its root screen.
    /// Tab roots observe their counter and reload when it changes.
    public private(set) var rootReselections: [AppTab: Int] = [:]

    public init() {}

    public func stack(for tab: AppTab) -> StackRouter {
        switch tab {
        case .home: home
        case .favorites: favorites
        case .search: search
        case .settings: settings
        }
    }

    /// Selects a tab. Selecting the current tab pops its stack to the root, or, when it is
    /// already at the root, bumps its reselection counter so the root screen can reload.
    public func select(_ tab: AppTab) {
        guard tab == selectedTab else {
            selectedTab = tab
            return
        }
        let stack = stack(for: tab)
        if stack.isAtRoot {
            rootReselections[tab, default: 0] += 1
        } else {
            stack.popToRoot()
        }
    }

    public func rootReselectionCount(for tab: AppTab) -> Int {
        rootReselections[tab, default: 0]
    }

    public func present(_ gallery: Gallery) {
        presented.popToRoot()
        presentedGallery = gallery
    }

    public func dismissPresentedGallery() {
        presentedGallery = nil
        presented.popToRoot()
    }
}
