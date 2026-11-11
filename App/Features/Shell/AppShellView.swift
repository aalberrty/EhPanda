import Dependencies
import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// The root of the app: the launch screens until the database is ready, then the tabs.
///
/// It also owns everything around the features: the shared services in the environment, the
/// accent colour and colour scheme, links opened from outside, the scene lifecycle and the
/// privacy blur and lock, which live in a window above this one (see `SceneWindowBridge`).
struct AppShellView: View {
    @State private var model: AppModel = {
        let model = AppModel()
        model.lock.localizedReason = L10n.Localizable.LocalAuthorization.reason
        return model
    }()

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Shared services. They are injected into the environment so views read the individual
    // properties they render; models reach the same instances through `@Dependency`.
    @Dependency(\.settings) private var settings
    @Dependency(\.filterStore) private var filterStore
    @Dependency(\.userStore) private var userStore
    @Dependency(\.tagTranslationService) private var tagTranslationService
    @Dependency(\.accountSession) private var accountSession

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
        .tint(settings.accentColor.color)
        .environment(model.router)
        .environment(settings)
        .environment(filterStore)
        .environment(userStore)
        .environment(tagTranslationService)
        .environment(accountSession)
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
