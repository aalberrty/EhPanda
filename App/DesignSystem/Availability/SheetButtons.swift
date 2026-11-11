import SwiftUI

/// Closes a sheet: the system close button on iOS 26, an "xmark" on iOS 18. The symbol carries
/// the system's localized "Close" label for VoiceOver.
struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(role: .close, action: action)
        } else {
            Button(action: action) {
                Image(systemName: "xmark")
            }
        }
    }
}

/// Confirms a sheet: the system confirm button on iOS 26, a "checkmark" on iOS 18.
struct SheetConfirmButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(role: .confirm, action: action)
        } else {
            Button(action: action) {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
            }
        }
    }
}

/// An alert's cancel button: the system's own title on iOS 26, `title` on iOS 18, where a
/// cancel button needs one.
struct AlertCancelButton: View {
    let title: String

    var body: some View {
        if #available(iOS 26, *) {
            Button(role: .cancel) {}
        } else {
            Button(title, role: .cancel) {}
        }
    }
}
