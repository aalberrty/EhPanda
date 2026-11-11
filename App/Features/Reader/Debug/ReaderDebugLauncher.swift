#if DEBUG
import Dependencies
import EhCore
import EhDatabase
import EhFeatures
import EhModels
import EhNetworking
import Observation
import SwiftUI

// DEBUG ONLY. A way into the reader with a real gallery until the gallery detail screen
// exists: it loads the frontpage and opens one of its galleries. Delete it together with
// `FeaturePlaceholder`.
//
// Launching the app with `-ReaderDebugGallery <n>` opens the n-th frontpage gallery (1-based)
// straight away, and `-ReaderDebugPage <p>` opens it on page p.

/// The debug launcher's state. It outlives the placeholder screens, so the measurements of
/// earlier opens stay visible.
@Observable
final class ReaderDebugSession {
    static let shared = ReaderDebugSession()

    struct Opening: Identifiable {
        let gallery: Gallery
        let initialPage: Int?
        let database: AppDatabase
        var id: String { gallery.gid }
    }

    private(set) var status = ""
    /// One line per open: the gallery, what was stored for it, and the time to its first page.
    private(set) var measurements: [String] = []
    var opening: Opening?

    @ObservationIgnored private var galleries: [Gallery] = []
    @ObservationIgnored private var database: AppDatabase?
    @ObservationIgnored private var pendingLine: [String: String] = [:]
    @ObservationIgnored private var hasOpenedAtLaunch = false
    @ObservationIgnored @Dependency(\.ehClient) private var client

    /// Opens the gallery at `index` of the frontpage (0-based).
    func open(index: Int, initialPage: Int? = nil) async {
        do {
            status = "Loading the frontpage…"
            if galleries.isEmpty {
                galleries = try await client.frontpage(filter: Filter()).galleries
            }
            guard galleries.indices.contains(index) else {
                status = "The frontpage has only \(galleries.count) galleries"
                return
            }
            let gallery = galleries[index]
            let database = try await debugDatabase()
            // The detail screen does this in the real app; pages of galleries without a row
            // are treated as expired.
            try await database.recordOpened(gallery)
            let stored = try await database.pages(gid: gallery.gid).count { $0.imageURL != nil }
            pendingLine[gallery.gid] = "gid \(gallery.gid), \(gallery.pageCount) pages, \(stored) stored"
            status = "Opened gallery \(index + 1)"
            opening = Opening(gallery: gallery, initialPage: initialPage, database: database)
        } catch {
            status = "Failed: \(error)"
        }
    }

    func record(firstPage: Duration, gid: String) {
        let milliseconds = Int(firstPage / .milliseconds(1))
        measurements.append("\(pendingLine[gid] ?? "gid \(gid)"): first page after \(milliseconds) ms")
    }

    func openAtLaunchIfAsked() async {
        guard !hasOpenedAtLaunch else { return }
        hasOpenedAtLaunch = true
        let number = UserDefaults.standard.integer(forKey: "ReaderDebugGallery")
        guard number > 0 else { return }
        let page = UserDefaults.standard.integer(forKey: "ReaderDebugPage")
        await open(index: number - 1, initialPage: page > 0 ? page : nil)
    }

    /// The app does not open its database at launch yet, so the launcher brings its own, in a
    /// file of its own so that reopening a gallery after a relaunch can be tried too.
    private func debugDatabase() async throws -> AppDatabase {
        if let database { return database }
        let url = URL.applicationSupportDirectory.appending(path: "EhPanda/ReaderDebug.sqlite")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let opened = try await AppDatabase.open(at: url)
        database = opened
        return opened
    }
}

/// DEBUG ONLY. Rows for the placeholder screen that open a real gallery in the reader.
struct ReaderDebugLauncher: View {
    @Bindable private var session = ReaderDebugSession.shared

    var body: some View {
        ForEach(0..<3, id: \.self) { index in
            Button("Debug: open frontpage gallery \(index + 1) in the reader") {
                Task { await session.open(index: index) }
            }
        }
        if !session.status.isEmpty {
            Text(verbatim: session.status).font(.caption)
        }
        ForEach(Array(session.measurements.enumerated()), id: \.offset) { _, line in
            Text(verbatim: line).font(.caption.monospacedDigit())
        }
        Color.clear
            .frame(height: 0)
            .listRowInsets(EdgeInsets())
            .task { await session.openAtLaunchIfAsked() }
            .fullScreenCover(item: $session.opening) { opening in
                withDependencies {
                    $0.database = opening.database
                } operation: {
                    ReaderScreen(gallery: opening.gallery, initialPage: opening.initialPage)
                }
            }
    }
}
#endif
