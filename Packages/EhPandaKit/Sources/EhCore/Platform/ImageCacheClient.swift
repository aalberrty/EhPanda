import Dependencies
import Foundation

/// How much the image cache may hold.
public struct ImageCacheLimits: Sendable, Equatable {
    /// Decoded bitmaps kept in memory, in bytes.
    public var memoryBytes: Int
    /// Files kept on disk, in bytes.
    public var diskBytes: Int

    public init(memoryBytes: Int, diskBytes: Int) {
        self.memoryBytes = memoryBytes
        self.diskBytes = diskBytes
    }

    /// The app's limits on a device with `physicalMemory` bytes of RAM.
    ///
    /// - Memory: an eighth of the RAM and never more than 512 MB of bitmaps. The image
    ///   library's own default is a quarter of the RAM.
    /// - Disk: 2 GB. The disk cache holds every full-size page that was read, next to covers
    ///   and previews, and the library's default is no limit at all (files only expire a week
    ///   after they were stored). Past the limit the library removes the files used longest
    ///   ago until half of it is left, so the cache settles between 1 and 2 GB: a few thousand
    ///   pages, which is more than the week of page URLs the database keeps is likely to need.
    public static func standard(physicalMemory: UInt64) -> ImageCacheLimits {
        let megabyte: UInt64 = 1024 * 1024
        return ImageCacheLimits(
            memoryBytes: Int(min(physicalMemory / 8, 512 * megabyte)),
            diskBytes: Int(2048 * megabyte)
        )
    }
}

/// The app's web image cache.
public struct ImageCacheClient: Sendable {
    /// Applies the cache's limits. The launch sequence calls it once, before any image is
    /// shown; without it the cache keeps the image library's defaults. The live value creates
    /// the cache off the main actor, because that touches disk.
    public var configure: @Sendable (ImageCacheLimits) async -> Void
    /// Total size of the on-disk image cache in bytes.
    public var diskCacheSize: @Sendable () async throws -> Int
    public var clearDiskCache: @Sendable () async -> Void
    /// The original encoded bytes of an image: from the disk cache when present, otherwise
    /// downloaded. Used by the reader's copy, save and share actions.
    public var imageData: @Sendable (URL) async throws -> Data

    public init(
        configure: @escaping @Sendable (ImageCacheLimits) async -> Void = { _ in },
        diskCacheSize: @escaping @Sendable () async throws -> Int,
        clearDiskCache: @escaping @Sendable () async -> Void,
        imageData: @escaping @Sendable (URL) async throws -> Data
    ) {
        self.configure = configure
        self.diskCacheSize = diskCacheSize
        self.clearDiskCache = clearDiskCache
        self.imageData = imageData
    }
}

extension ImageCacheClient: TestDependencyKey {
    public static let testValue = ImageCacheClient(
        configure: unimplemented("ImageCacheClient.configure"),
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
