import Dependencies
import EhCore
import SwiftUI

@main
struct EhPandaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Both run before anything reads a dependency or loads an image; neither touches disk.
        // The image cache, whose creation does, gets its limits in the launch sequence.
        ImageDownloaderConfiguration.configure()
        prepareDependencies { $0.domainFronting = .appWide }
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
        }
    }
}
