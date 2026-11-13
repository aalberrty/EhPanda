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

    /// A thumbnail of the preview strip; larger on an iPad-sized window.
    static func thumbnailSize(isLarge: Bool) -> CGSize {
        let width: CGFloat = isLarge ? 70 : 50
        return CGSize(width: width, height: (width / Tokens.Aspect.preview).rounded())
    }
}
