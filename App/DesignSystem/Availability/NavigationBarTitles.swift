import UIKit

/// Serif navigation bar titles on iOS 26; the system titles on iOS 18.
///
/// SwiftUI has no modifier for the navigation bar's title font, so this sets it on the
/// `UINavigationBar` appearance proxy, which SwiftUI's bars read. Only the fonts are set: a
/// `UINavigationBarAppearance` would replace the iOS 26 bar's own background and scroll edge.
enum NavigationBarTitles {
    /// Call once at launch, before the first bar appears.
    static func configure() {
        guard AppLook.isRedesigned else { return }
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: serifFont(size: 34, weight: .bold)]
        bar.titleTextAttributes = [.font: serifFont(size: 17, weight: .semibold)]
    }

    private static func serifFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = font.fontDescriptor.withDesign(.serif) else { return font }
        return UIFont(descriptor: descriptor, size: size)
    }
}
