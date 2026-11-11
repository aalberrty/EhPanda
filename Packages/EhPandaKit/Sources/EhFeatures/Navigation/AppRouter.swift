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

    /// The daily "New Dawn" greeting to announce, shown as a sheet over everything else.
    /// Any feature that receives a greeting worth showing sets it; the shell presents it.
    public var presentedGreeting: Greeting?

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

    /// Presents `gallery` in the gallery sheet. `target` is what the link pointed at inside the
    /// gallery; the detail screen takes it once with `takePresentedGalleryTarget(for:)`.
    public func present(_ gallery: Gallery, target: GalleryLinkTarget? = nil) {
        presented.popToRoot()
        presentedGalleryTarget = target
        presentedGallery = gallery
    }

    public func dismissPresentedGallery() {
        presentedGallery = nil
        presentedGalleryTarget = nil
        presented.popToRoot()
    }

    /// What the link that opened the presented gallery pointed at, if anything.
    ///
    /// Not observed: the sheet takes it while building its root screen, and taking it must not
    /// invalidate the view being built.
    @ObservationIgnored public private(set) var presentedGalleryTarget: GalleryLinkTarget?

    /// Returns the presented gallery's link target and forgets it, so it is honoured once.
    /// `nil` when `gid` is not the presented gallery or there is no target.
    public func takePresentedGalleryTarget(for gid: String) -> GalleryLinkTarget? {
        guard presentedGallery?.gid == gid, let target = presentedGalleryTarget else { return nil }
        presentedGalleryTarget = nil
        return target
    }
}

/// The part of a gallery a link points at, beyond the gallery itself.
nonisolated public enum GalleryLinkTarget: Hashable, Sendable {
    /// An image page (`/s/<key>/<gid>-<page>`): open the reader at this 1-based page. The page
    /// is already stored as the gallery's reading progress when the gallery is presented.
    case page(Int)
    /// A comment anchor (`/g/<gid>/<token>/#c<id>`): open the comments scrolled to this comment.
    case comment(String)
}
