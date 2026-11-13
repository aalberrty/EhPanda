import SwiftUI

/// What a screen's ground is drawn for.
enum ScreenGroundStyle {
    /// A scroll view or plain list.
    case plain
    /// A grouped `List` or `Form` (Settings and the like).
    case grouped
}

extension View {
    /// Draws the warm ground behind the whole screen on iOS 26, under the bars too, and stops a
    /// `List` or `Form` from drawing its own background over it. A no-op on iOS 18, where the
    /// system backgrounds are the v3 look.
    ///
    /// Apply it once to a screen's root view. Rows of a grouped list keep their system
    /// background unless they set `.listRowBackground(Color.raisedGrouped)`.
    func screenGround(_ style: ScreenGroundStyle = .plain) -> some View {
        modifier(ScreenGround(style: style))
    }
}

private struct ScreenGround: ViewModifier {
    let style: ScreenGroundStyle

    func body(content: Content) -> some View {
        if AppLook.isRedesigned {
            content
                .scrollContentBackground(.hidden)
                .background {
                    (style == .grouped ? Color.groundGrouped : Color.ground).ignoresSafeArea()
                }
        } else {
            content
        }
    }
}
