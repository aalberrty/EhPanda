import SwiftUI
import UIKit

/// The reader controls' colours and sizes, in one place so they can move to the design tokens.
///
/// The colours are the hierarchical styles rather than fixed ones: glass and the iOS 18 material
/// tint them for whatever page is behind, so they stay legible over black and white pages and in
/// both appearances.
nonisolated enum ReaderPanelStyle {
    // MARK: Colours

    static var primary: HierarchicalShapeStyle { .primary }
    static var secondary: HierarchicalShapeStyle { .secondary }
    /// The bottom panel's handle.
    static var handle: HierarchicalShapeStyle { .tertiary }
    /// Behind a labelled button that is on (Live Text, Auto-Play).
    static var selectedFill: HierarchicalShapeStyle { .quaternary }
    /// The edge of a thumbnail in the preview strip.
    static var thumbnailEdge: HierarchicalShapeStyle { .quaternary }
    /// The slider's track up to the thumb, in place of the app's accent colour.
    static var sliderFill: UIColor { .label }

    // MARK: Sizes

    /// Close, More and the title capsule.
    static let controlHeight: CGFloat = 44
    static let panelCornerRadius: CGFloat = 30
    static let buttonCornerRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 52
    /// The widest the bottom panel and the title capsule grow on a wide window.
    static let maximumPanelWidth: CGFloat = 600
    static let maximumTitleWidth: CGFloat = 560
    static let thumbnailCornerRadius: CGFloat = 6
    static let thumbnailSpacing: CGFloat = 12

    /// The share of the panel's content width the strip fills, as in the mockup: five 50 pt
    /// thumbnails with 12 pt gaps in a 346 pt wide panel.
    static let thumbnailStripFill: CGFloat = 298 / 346

    /// A thumbnail of the preview strip, sized so `count` thumbnails fill the panel the way the
    /// mockup does: a fixed 50 pt looked small on wider phones. Never below 50 pt (70 pt on an
    /// iPad-sized window) and never more than 30% above that.
    static func thumbnailSize(isLarge: Bool, count: Int, availableWidth: CGFloat) -> CGSize {
        let minimum: CGFloat = isLarge ? 70 : 50
        let gaps = thumbnailSpacing * CGFloat(max(count - 1, 0))
        let fitted = ((availableWidth * thumbnailStripFill - gaps) / CGFloat(max(count, 1))).rounded(.down)
        let width = min(max(fitted, minimum), (minimum * 1.3).rounded())
        return CGSize(width: width, height: (width / Tokens.Aspect.preview).rounded())
    }
}
