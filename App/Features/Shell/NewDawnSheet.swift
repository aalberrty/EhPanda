import EhFeatures
import EhModels
import SwiftUI

/// The daily "New Dawn" reward (legacy `NewDawnView`): a sky gradient, the sun (with rays in
/// light mode) in the top-trailing corner, two title lines and the rewards.
struct NewDawnSheet: View {
    let greeting: Greeting

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var width: CGFloat = 0

    private var gradientColors: [Color] {
        colorScheme == .light
            ? [Color(.systemTeal), Color(.systemIndigo)]
            : [Color(.systemGray5), Color(.systemGray2)]
    }

    /// Legacy sized the sun from the window width; this uses the sheet's own width.
    private var sunWidth: CGFloat {
        width * (horizontalSizeClass == .regular ? 0.5 : 0.6)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom)
            Sun(width: sunWidth, showsRays: colorScheme == .light)
                .offset(x: width * 0.2, y: -width * 0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .accessibilityHidden(true)
            VStack(spacing: 50) {
                VStack(spacing: 10) {
                    line(L10n.Localizable.NewDawnView.Title.first, font: .heading(.largeTitle))
                    line(L10n.Localizable.NewDawnView.Title.second, font: .heading(.title2))
                }
                line(greeting.gainContent ?? "", font: .title3.bold())
            }
            .padding()
        }
        .drawingGroup()
        .ignoresSafeArea()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    /// The two title lines are headings (serif on iOS 26); the rewards stay in the default
    /// design, like other content.
    private func line(_ text: String, font: Font) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Sun: View {
    let width: CGFloat
    let showsRays: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.yellow)
                .frame(width: width, height: width)
            if showsRays {
                ForEach(0..<8, id: \.self) { index in
                    ray(at: Double(index) * 45)
                }
            }
        }
    }

    /// One of eight rays around the sun, `degrees` clockwise from the top.
    private func ray(at degrees: Double) -> some View {
        let beam = width / 10
        let distance = width / 1.2
        let radians = degrees * .pi / 180
        return RoundedRectangle(cornerRadius: beam / 3)
            .fill(.yellow)
            .frame(width: beam, height: beam * 5)
            .rotationEffect(.degrees(degrees))
            .offset(x: distance * sin(radians), y: -distance * cos(radians))
    }
}

// MARK: Presentation

extension View {
    /// Presents `router.presentedGreeting` as the New Dawn sheet with a light haptic.
    ///
    /// Only one view can present a sheet at a time, so the shell attaches this to the tabs and
    /// to the gallery sheet and marks the one on top with `isTopmost`.
    func newDawnSheet(router: AppRouter, isTopmost: Bool) -> some View {
        modifier(NewDawnPresenter(router: router, isTopmost: isTopmost))
    }
}

private struct NewDawnPresenter: ViewModifier {
    let router: AppRouter
    let isTopmost: Bool

    func body(content: Content) -> some View {
        content
            .sheet(item: greeting) { greeting in
                NewDawnSheet(greeting: greeting)
                    .presentationDragIndicator(.visible)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isTopmost ? router.presentedGreeting : nil) { _, new in
                new != nil
            }
    }

    private var greeting: Binding<Greeting?> {
        Binding(
            get: { isTopmost ? router.presentedGreeting : nil },
            set: { if $0 == nil, isTopmost { router.presentedGreeting = nil } }
        )
    }
}

#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            NewDawnSheet(greeting: .mock)
        }
}
