import Dependencies
import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The root of the app: the launch screens until the database is ready, then the tabs.
///
/// It also owns everything around the features: the shared services in the environment, the
/// tint, ground and colour scheme, links opened from outside, the scene lifecycle and the
/// privacy blur and lock, which live in a window above this one (see `SceneWindowBridge`).
struct AppShellView: View {
    @State private var model: AppModel = {
        let model = AppModel()
        model.lock.localizedReason = L10n.Localizable.LocalAuthorization.reason
        return model
    }()

    /// Cover palettes, shared so a screen reuses the palette another one already made.
    @State private var coverPalettes = CoverPaletteStore()

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // The settings decide the first frame's colours. The other shared services are injected
    // by `MainTabView`: the launch creates them off the main actor before the tabs appear.
    @Dependency(\.settings) private var settings

    var body: some View {
        ZStack {
            if model.launchState == .ready {
                MainTabView(model: model)
                    .transition(.opacity)
            } else {
                LaunchStatusView(model: model)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.launchState == .ready)
        .background(.ground)
        .tint(settings.accentColor.appTint)
        .environment(model.router)
        .environment(settings)
        .environment(coverPalettes)
        .background {
            SceneWindowBridge(
                colorScheme: settings.preferredColorScheme,
                accentColor: settings.accentColor,
                lock: model.lock,
                isPrivacyOverlayVisible: model.lock.blurRadius > 0 || model.lock.isLocked,
                unlock: model.unlock
            )
        }
        .onOpenURL { model.links.open($0) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            model.scenePhaseChanged(to: AppModel.ScenePhase(phase))
        }
        .task(id: model.launchAttempt) {
            await model.launch(isRegularWidth: horizontalSizeClass == .regular)
        }
        .task { await model.followDomainFrontingSetting() }
    }
}

private extension AppModel.ScenePhase {
    init(_ phase: SwiftUI.ScenePhase) {
        switch phase {
        case .active: self = .active
        case .background: self = .background
        default: self = .inactive
        }
    }
}

#Preview {
    AppShellView()
}
