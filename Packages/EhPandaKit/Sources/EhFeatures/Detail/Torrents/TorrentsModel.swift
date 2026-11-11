import Dependencies
import EhCore
import EhModels
import EhNetworking
import Foundation
import Observation

/// The torrents sheet: list, copy a magnet link, share a `.torrent` file.
@Observable
public final class TorrentsModel {
    public let gid: String
    public let token: String

    public private(set) var torrents: [GalleryTorrent] = []
    public private(set) var loadingState: LoadingState = .idle
    /// Counts copied magnet links, for the HUD and haptic.
    public private(set) var copyCount = 0
    /// A downloaded `.torrent` file to hand to the share sheet.
    public var sharedFile: SharedFile?

    public struct SharedFile: Identifiable, Hashable, Sendable {
        public let url: URL
        public var id: URL { url }
    }

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let tasks = ModelTasks()

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.clipboardClient) private var clipboard

    /// - Parameter directory: Where downloaded `.torrent` files go; legacy used Caches.
    public init(gid: String, token: String, directory: URL = .cachesDirectory) {
        self.gid = gid
        self.token = token
        self.directory = directory
    }

    /// Call from the sheet's `.task`. No torrents is shown as "not found".
    public func load() async {
        guard !loadingState.isLoading else { return }
        loadingState = .loading
        let client = client
        let gid = gid
        let token = token
        let outcome = await Outcome.of { try await client.torrents(gid: gid, token: token) }
        switch outcome {
        case .cancelled:
            loadingState = .idle
        case .failure(let error):
            loadingState = .failed(error)
        case .success(let torrents) where torrents.isEmpty:
            loadingState = .failed(.notFound)
        case .success(let torrents):
            self.torrents = torrents
            loadingState = .idle
        }
    }

    public func retry() {
        tasks.run("load") { [weak self] in await self?.load() }
    }

    public func copyMagnet(of torrent: GalleryTorrent) {
        clipboard.copyText(torrent.magnetURL)
        copyCount += 1
    }

    /// Downloads the `.torrent` file as `<hash>.torrent` and offers it to share. A failed or
    /// empty download does nothing, as in legacy.
    public func shareFile(of torrent: GalleryTorrent) {
        let client = client
        let directory = directory
        tasks.run("download") { [weak self] in
            let outcome = await Outcome.of { try await client.data(from: torrent.torrentURL) }
            guard case .success(let data) = outcome, !data.isEmpty,
                  let url = try? await Self.save(data, hash: torrent.hash, in: directory)
            else { return }
            self?.sharedFile = SharedFile(url: url)
        }
    }

    @concurrent
    private static func save(_ data: Data, hash: String, in directory: URL) async throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(hash).torrent")
        try data.write(to: url, options: .atomic)
        return url
    }
}
