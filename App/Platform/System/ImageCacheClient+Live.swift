import Dependencies
import EhCore
import Foundation
import Kingfisher

extension ImageCacheClient: @retroactive DependencyKey {
    nonisolated public static let liveValue = ImageCacheClient(
        configure: { limits in await ImageCacheConfiguration.apply(limits) },
        diskCacheSize: { Int(try await KingfisherManager.shared.cache.diskStorageSize) },
        clearDiskCache: { await KingfisherManager.shared.cache.clearDiskCache() },
        // The one implementation of "the original bytes of a URL": the image pipeline's, which
        // reads the disk cache every image shares and downloads what is not there.
        imageData: { url in try await ImagePipeline.originalData(for: url) }
    )
}
