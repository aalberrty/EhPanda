#if DEBUG
import Dependencies
import EhCore
import EhDatabase
import EhFeatures
import EhModels
import EhNetworking
import SwiftUI

/// DEBUG ONLY. Opens a real gallery's detail screen before the gallery lists exist: loads the
/// frontpage and pushes its first gallery. Also opens and installs the on-disk database, which
/// the launch sequence will do once it exists. Not referenced by any release code.
struct DetailDebugLauncher: View {
    @Environment(StackRouter.self) private var stack: StackRouter?
    @State private var status: String?

    var body: some View {
        Section("Debug: gallery detail") {
            Button("Open the first frontpage gallery") {
                Task { await open() }
            }
            if let status {
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func open() async {
        status = "Loading…"
        do {
            try await Self.installDatabaseOnce()
            @Dependency(\.ehClient) var client
            let page = try await client.frontpage(filter: Filter())
            guard let gallery = page.galleries.first else {
                status = "The frontpage had no galleries."
                return
            }
            status = nil
            stack?.push(.detail(gallery))
        } catch {
            status = "Failed: \(error)"
        }
    }

    private static var isDatabaseInstalled = false

    private static func installDatabaseOnce() async throws {
        guard !isDatabaseInstalled else { return }
        LiveDatabase.install(try await AppDatabase.open(at: LiveDatabase.defaultURL))
        isDatabaseInstalled = true
    }
}
#endif
