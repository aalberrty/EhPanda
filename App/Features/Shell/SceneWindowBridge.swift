import EhFeatures
import EhModels
import SwiftUI
import UIKit

/// The shell's handle on UIKit. It applies the colour scheme and the tint to every window of the
/// scene, and shows the privacy blur and the lock in a window of its own above them.
///
/// Why a window: UIKit presents sheets and full-screen covers above the root view, so no SwiftUI
/// overlay on the root can cover them; legacy had every sheet apply the blur itself. A window at
/// a higher level covers the whole scene (tabs, every sheet and cover, alerts, the reader)
/// without any feature doing anything. It shows a snapshot of the main window, blurred with
/// `autoBlur(radius:)`, and swallows every touch while it is up.
struct SceneWindowBridge: UIViewRepresentable {
    let colorScheme: PreferredColorScheme
    let accentColor: RGBColor
    let lock: AppLockModel
    let isPrivacyOverlayVisible: Bool
    let unlock: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(lock: lock, unlock: unlock)
    }

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        let coordinator = context.coordinator
        view.onMoveToWindow = { [weak coordinator] window in coordinator?.attach(to: window) }
        return view
    }

    func updateUIView(_ view: AnchorView, context: Context) {
        context.coordinator.update(
            style: colorScheme.userInterfaceStyle,
            tint: UIColor(accentColor.color),
            showsPrivacyOverlay: isPrivacyOverlayVisible
        )
    }

    /// An empty view that reports the window it lands in.
    final class AnchorView: UIView {
        var onMoveToWindow: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onMoveToWindow?(window)
        }
    }

    final class Coordinator {
        /// Above the app's own windows and alerts. System windows such as the keyboard stay above.
        private static let overlayLevel = UIWindow.Level.alert + 1
        /// Long enough for `autoBlur` to animate the blur out before the window goes.
        private static let hideDelay: Duration = .milliseconds(150)

        private let lock: AppLockModel
        private let unlock: () -> Void
        private let snapshot = PrivacySnapshot()
        private weak var hostWindow: UIWindow?
        private var overlayWindow: UIWindow?
        private var pendingHide: Task<Void, Never>?

        private var style: UIUserInterfaceStyle = .unspecified
        private var tint: UIColor?
        private var showsOverlay = false
        private var wasLocked = false

        init(lock: AppLockModel, unlock: @escaping () -> Void) {
            self.lock = lock
            self.unlock = unlock
        }

        func attach(to window: UIWindow?) {
            guard let window, window !== hostWindow else { return }
            hostWindow = window
            apply()
        }

        func update(style: UIUserInterfaceStyle, tint: UIColor, showsPrivacyOverlay: Bool) {
            self.style = style
            self.tint = tint
            showsOverlay = showsPrivacyOverlay
            apply()
        }

        private func apply() {
            guard let hostWindow, let scene = hostWindow.windowScene else { return }
            // Legacy set the style on the window; sheets and covers live in it and follow.
            for window in [hostWindow, overlayWindow].compactMap(\.self) {
                if window.overrideUserInterfaceStyle != style { window.overrideUserInterfaceStyle = style }
                if window.tintColor != tint { window.tintColor = tint }
            }
            if showsOverlay {
                showOverlay(in: scene, over: hostWindow)
            } else {
                hideOverlay()
            }
            if lock.isLocked && !wasLocked {
                // Nothing may be typed into the app behind the lock.
                hostWindow.endEditing(true)
            }
            wasLocked = lock.isLocked
        }

        private func showOverlay(in scene: UIWindowScene, over host: UIWindow) {
            pendingHide?.cancel()
            pendingHide = nil
            let window = overlayWindow ?? makeOverlayWindow(in: scene)
            guard window.isHidden else { return }
            snapshot.capture(host)
            window.isHidden = false
            host.accessibilityElementsHidden = true
        }

        private func hideOverlay() {
            guard let window = overlayWindow, !window.isHidden, pendingHide == nil else { return }
            pendingHide = Task { [weak self] in
                guard (try? await Task.sleep(for: Self.hideDelay)) != nil, let self else { return }
                window.isHidden = true
                hostWindow?.accessibilityElementsHidden = false
                snapshot.clear()
                pendingHide = nil
            }
        }

        private func makeOverlayWindow(in scene: UIWindowScene) -> UIWindow {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = Self.overlayLevel
            window.overrideUserInterfaceStyle = style
            window.tintColor = tint
            let root = PrivacyOverlayController(
                rootView: PrivacyOverlayView(lock: lock, snapshot: snapshot, unlock: unlock),
                snapshot: snapshot
            )
            root.view.backgroundColor = .clear
            window.rootViewController = root
            window.isHidden = true
            overlayWindow = window
            return window
        }
    }
}

/// The main window as it looked when the overlay appeared.
@Observable
final class PrivacySnapshot {
    private(set) var view: UIView?

    func capture(_ window: UIWindow) {
        // A render-server copy: no drawing on the CPU, so it is cheap enough for every resign.
        view = window.snapshotView(afterScreenUpdates: false)
    }

    func clear() {
        view = nil
    }
}

/// Drops the snapshot when the window is resized (rotation, Stage Manager): it no longer
/// matches, and the overlay falls back to a material that blurs the live windows below.
private final class PrivacyOverlayController: UIHostingController<PrivacyOverlayView> {
    private let snapshot: PrivacySnapshot

    init(rootView: PrivacyOverlayView, snapshot: PrivacySnapshot) {
        self.snapshot = snapshot
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        snapshot.clear()
    }
}
