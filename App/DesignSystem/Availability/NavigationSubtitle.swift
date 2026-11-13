import SwiftUI

extension View {
    /// A screen title with a subtitle, such as Toplists and its period.
    ///
    /// iOS 26: the title, large, with the subtitle under it (`navigationSubtitle`), which leaves
    /// the bar to the toolbar's glass buttons. iOS 18, which has no subtitle: both joined in an
    /// inline title ("Toplists - Yesterday").
    func navigationTitle(_ title: String, subtitle: String) -> some View {
        modifier(NavigationSubtitle(title: title, subtitle: subtitle))
    }
}

private struct NavigationSubtitle: ViewModifier {
    let title: String
    let subtitle: String

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .navigationTitle(title)
                .navigationSubtitle(subtitle)
        } else {
            content
                .navigationTitle([title, subtitle].joined(separator: " - "))
                .toolbarTitleDisplayMode(.inline)
        }
    }
}
