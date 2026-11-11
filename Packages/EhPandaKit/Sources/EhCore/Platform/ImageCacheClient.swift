import Dependencies
import Foundation

/// The app's web image cache.
public struct ImageCacheClient: Sendable {
    /// Total size of the on-disk image cache in bytes.
    public var diskCacheSize: @Sendable () async throws -> Int
    public var clearDiskCache: @Sendable () async -> Void
    /// The original encoded bytes of an image: from the disk cache when present, otherwise
    /// downloaded. Used by the reader's copy, save and share actions.
    public var imageData: @Sendable (URL) async throws -> Data

    public init(
        diskCacheSize: @escaping @Sendable () async throws -> Int,
        clearDiskCache: @escaping @Sendable () async -> Void,
        imageData: @escaping @Sendable (URL) async throws -> Data
    ) {
        self.diskCacheSize = diskCacheSize
        self.clearDiskCache = clearDiskCache
        self.imageData = imageData
    }
}

extension ImageCacheClient: TestDependencyKey {
    public static let testValue = ImageCacheClient(
        diskCacheSize: unimplemented("ImageCacheClient.diskCacheSize"),
        clearDiskCache: unimplemented("ImageCacheClient.clearDiskCache"),
        imageData: unimplemented("ImageCacheClient.imageData")
    )

    public static let previewValue = ImageCacheClient(
        diskCacheSize: { 0 },
        clearDiskCache: {},
        imageData: { _ in Data() }
    )
}

extension DependencyValues {
    public var imageCacheClient: ImageCacheClient {
        get { self[ImageCacheClient.self] }
        set { self[ImageCacheClient.self] = newValue }
    }
}
