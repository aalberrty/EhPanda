import Dependencies
import EhCore
import Foundation
import Kingfisher

extension ImageCacheClient: @retroactive DependencyKey {
    nonisolated public static let liveValue = ImageCacheClient(
        configure: { limits in await ImageCacheConfiguration.apply(limits) },
        diskCacheSize: { Int(try await KingfisherManager.shared.cache.diskStorageSize) },
        clearDiskCache: { await KingfisherManager.shared.cache.clearDiskCache() },
        imageData: { url in try await originalData(for: url) }
    )

    /// The original bytes are on disk under the plain URL key when the image was cached without
    /// a processor (or with `.cacheOriginalImage`); otherwise download them again.
    @concurrent
    nonisolated private static func originalData(for url: URL) async throws -> Data {
        let manager = KingfisherManager.shared
        if let data = try? manager.cache.diskStorage.value(forKey: url.cacheKey) {
            return data
        }
        return try await manager.downloader.downloadImage(with: url).originalData
    }
}
