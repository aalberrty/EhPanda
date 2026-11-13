/// The one switch between the redesigned look and v3's system look.
///
/// iOS 26 draws the overhaul as designed (warm ground, bone and ink, serif titles, Liquid
/// Glass, the cover glow). iOS 18 keeps the new layout with the baseline v3 look: system
/// colours, the default font design, materials and no glow. Tokens and the `Availability`
/// helpers read this; screens use those and never check the OS version themselves.
nonisolated enum AppLook {
    static let isRedesigned: Bool = {
        if #available(iOS 26, *) { true } else { false }
    }()
}
