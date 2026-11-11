import CoreGraphics

/// What a single tap on the reader does.
nonisolated public enum ReaderTapAction: Sendable, Equatable {
    case previousPage
    case nextPage
    case togglePanel
}

nonisolated public enum ReaderTapZone {
    /// Share of the width, on each side, that turns the page in the paged directions.
    public static let edgeFraction: CGFloat = 0.2

    /// Classifies a tap at horizontal position `x` in a view `width` points wide.
    ///
    /// In the paged directions the outer fifths turn the page (which one depends on the reading
    /// direction) and the middle toggles the control panel. A vertical reader has no page
    /// turning zones.
    public static func action(atX x: CGFloat, width: CGFloat, direction: ReaderDirection) -> ReaderTapAction {
        guard direction.isPaged, width > 0 else { return .togglePanel }
        let rightToLeft = direction == .rightToLeft
        if x < width * edgeFraction {
            return rightToLeft ? .nextPage : .previousPage
        }
        if x > width * (1 - edgeFraction) {
            return rightToLeft ? .previousPage : .nextPage
        }
        return .togglePanel
    }
}
