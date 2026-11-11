import EhFeatures
import SwiftUI

/// The privacy blur over the whole app and, when the auto-lock expired, the lock control
/// (legacy: the blurred tab view with an 80 pt `lock.fill` button).
struct PrivacyOverlayView: View {
    let lock: AppLockModel
    let snapshot: PrivacySnapshot
    let unlock: () -> Void

    var body: some View {
        ZStack {
            if let view = snapshot.view {
                // The background shows at the blurred edges instead of the sharp window below.
                Color(.systemBackground)
                SnapshotView(view: view)
                    .autoBlur(radius: lock.blurRadius)
            } else {
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .opacity(lock.blurRadius > 0 || lock.isLocked ? 1 : 0)
                    .animation(.linear(duration: 0.1), value: lock.blurRadius)
            }
            if lock.isLocked {
                LockControl(action: unlock)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .ignoresSafeArea()
        .animation(.default, value: lock.isLocked)
    }
}

private struct SnapshotView: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView {
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct LockControl: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 96, height: 96)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        // There is no "Unlock" string; the prompt's reason says why the app is locked.
        .accessibilityLabel(L10n.Localizable.LocalAuthorization.reason)
    }
}
