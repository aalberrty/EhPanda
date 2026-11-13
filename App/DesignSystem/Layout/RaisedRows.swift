import SwiftUI

extension View {
    /// Rows of a grouped list or form as the redesign draws them: on `raisedGrouped`, with
    /// `hairline` separators. On iOS 18 both tokens are the system defaults, so the rows look
    /// as before.
    ///
    /// Apply it to the list's content (a `Group` of its sections, or a `ForEach`) and put
    /// `screenGround(.grouped)` on the list itself. It sets no text colour: a foreground style
    /// on a row also recolours the buttons in it, which take the tint or their role's colour.
    func raisedRows() -> some View {
        listRowBackground(Color.raisedGrouped)
            .listRowSeparatorTint(.hairline)
    }
}
