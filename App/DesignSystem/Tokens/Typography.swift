import SwiftUI

// Screen and section titles use the serif system design (New York) on iOS 26 and the default
// design on iOS 18. Gallery titles never do: they stay in the default design so mixed-script
// titles hold up. Navigation bar titles follow through `NavigationBarTitles`.
nonisolated extension Font {
    /// A bold title in `style`'s size: serif on iOS 26, the default design on iOS 18.
    static func heading(_ style: Font.TextStyle) -> Font {
        .system(style, design: AppLook.isRedesigned ? .serif : .default, weight: .bold)
    }

    /// A screen title drawn in the content, such as Home's or Search's large title (34 pt).
    static var screenTitle: Font { heading(.largeTitle) }

    /// A section title, such as "Frontpage", "Previews" or "Comments" (20 pt).
    static var sectionTitle: Font { heading(.title3) }
}
