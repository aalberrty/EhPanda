import EhCore
import UIKit

/// Owns the interface orientation mask. Legacy behaviour: iPhone is portrait-only except in
/// the reader when landscape is enabled; iPad allows every orientation.
final class AppDelegate: NSObject, UIApplicationDelegate {
    private static var orientationMask: UIInterfaceOrientationMask =
        UIDevice.current.userInterfaceIdiom == .pad ? .all : [.portrait, .portraitUpsideDown]

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationMask
    }

    static func setOrientationLock(_ lock: OrientationLock) {
        orientationMask = switch lock {
        case .portrait: [.portrait, .portraitUpsideDown]
        case .unlocked: .all
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            if lock == .portrait {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
    }
}
