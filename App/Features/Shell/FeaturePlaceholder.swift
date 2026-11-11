import EhFeatures
import SwiftUI

/// Stand-in for a feature screen that has not been built yet. Delete once nothing uses it.
///
/// In debug builds it lists every route, so a screen can be reached and checked before the
/// screens that normally lead to it exist.
struct FeaturePlaceholder: View {
    let name: String

    @Environment(StackRouter.self) private var stack: StackRouter?

    var body: some View {
        List {
            Section {
                ContentUnavailableView(name, systemImage: "hammer", description: Text(verbatim: "Not built yet"))
            }
            #if DEBUG
            Section("Debug: reader engine") {
                ReaderHarnessLauncher()
            }
            if let stack {
                Section("Debug: push a route") {
                    ForEach(Self.debugRoutes, id: \.self) { route in
                        Button(String(describing: route)) { stack.push(route) }
                    }
                }
            }
            #endif
        }
        .navigationTitle(name)
    }

    #if DEBUG
    private static let debugRoutes: [Route] = [
        .galleryList(.frontpage), .galleryList(.popular), .galleryList(.watched),
        .galleryList(.toplists), .galleryList(.history),
        .search(keyword: "language:english"),
        .settings(.account), .settings(.login), .settings(.ehSetting), .settings(.general),
        .settings(.appearance), .settings(.reading), .settings(.laboratory), .settings(.logs),
        .settings(.about)
    ]
    #endif
}
