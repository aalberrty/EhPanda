import Dependencies
import EhCore
import UIKit

extension ApplicationClient: @retroactive DependencyKey {
    nonisolated public static let liveValue = ApplicationClient(
        isPad: { UIDevice.current.userInterfaceIdiom == .pad },
        openURL: { url in await UIApplication.shared.open(url) },
        openSettings: {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            await UIApplication.shared.open(url)
        },
        alternateIconName: { UIApplication.shared.alternateIconName },
        setAlternateIconName: { name in
            do {
                try await UIApplication.shared.setAlternateIconName(name)
                return true
            } catch {
                return false
            }
        },
        setOrientationLock: { lock in AppDelegate.setOrientationLock(lock) }
    )
}
