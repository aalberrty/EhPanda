import SwiftUI

/// Fixed spacing, radii and image metrics shared by every screen.
///
/// Nothing here is derived from the window or screen size. Values that legacy computed from
/// `DeviceUtil.windowW` or `isPadWidth` are either expressed per size class or left to the layout
/// (`containerRelativeFrame`, the proposed size). `nonisolated` so image processors can read them
/// off the main actor.
nonisolated enum Tokens {
    enum Spacing {
        static let xxSmall: CGFloat = 2
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let xxLarge: CGFloat = 30
    }

    enum Radius {
        /// Covers, previews and their placeholders.
        static let image: CGFloat = 8
        /// Tag chips and small filled controls.
        static let chip: CGFloat = 8
        /// Text fields embedded in rows.
        static let field: CGFloat = 8
        /// Floating cards such as the HUD.
        static let card: CGFloat = 28
        /// Glass panels over the cover glow (`glassPanel()`).
        static let panel: CGFloat = 24
    }

    /// Width / height ratios.
    enum Aspect {
        /// Gallery covers in rows, headers and grids (legacy `rowAspect`, `headerAspect`).
        static let cover: CGFloat = 8 / 11
        /// Page previews (legacy `previewAspect`).
        static let preview: CGFloat = 8 / 11
        /// Reader pages before their real size is known (legacy `contentAspect`).
        static let content: CGFloat = 7 / 10
    }

    enum ImageSize {
        /// Cover in a list row (legacy `rowW` × `rowH`).
        static let row = CGSize(width: 120 * Aspect.cover, height: 120)
        /// Cover in the detail header and card cells (legacy `headerW` × `headerH`).
        static let header = CGSize(width: 150 * Aspect.cover, height: 150)
        /// Height of a card cell: the header cover plus its vertical padding (legacy `cardCellHeight`).
        static let cardHeight: CGFloat = header.height + 20 * 2

        /// Preview column widths; legacy switched on `isPadWidth`, this switches on the size class.
        static func previewWidths(for sizeClass: UserInterfaceSizeClass?) -> ClosedRange<CGFloat> {
            sizeClass == .regular ? 180...220 : 100...120
        }
        /// Archive grid column width; legacy also special-cased the iPhone SE width, which the
        /// adaptive grid now absorbs on its own.
        static func archiveGridWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
            sizeClass == .regular ? 175 : 150
        }
    }

    /// Covers taller than `minAspect` (webtoons) are cropped from the top to `idealAspect`.
    enum Webtoon {
        static let minAspect: CGFloat = 1 / 4
        static let idealAspect: CGFloat = 2 / 3
    }

    enum Duration {
        static let imageFade: TimeInterval = 0.25
        /// Legacy auto-hid every HUD after one second.
        static let hudAutoDismiss: Swift.Duration = .seconds(1)
    }
}
