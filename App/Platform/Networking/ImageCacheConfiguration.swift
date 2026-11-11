import EhCore
import Kingfisher

/// The image cache's limits, applied once by the launch sequence (`ImageCacheClient.configure`).
///
/// `ImageCache.default` is the cache of every image in the app: `KFImage` in lists, detail and
/// Home, and the reader's `ImagePipeline`. Left alone it keeps a quarter of the device's RAM in
/// bitmaps and any amount of files.
nonisolated enum ImageCacheConfiguration {
    static func apply(_ limits: ImageCacheLimits) async {
        let cache = await makeCache(diskBytes: limits.diskBytes)
        await setMemoryLimit(limits.memoryBytes, of: cache)
    }

    /// The first use of `ImageCache.default` creates it, and its directory on disk with it, so
    /// that happens here, off the main actor.
    @concurrent
    private static func makeCache(diskBytes: Int) async -> ImageCache {
        let cache = ImageCache.default
        // Checked when the app goes to the background: past the limit, the files used longest
        // ago are removed until half of it is left.
        cache.diskStorage.config.sizeLimit = UInt(max(diskBytes, 0))
        return cache
    }

    /// On the main actor: assigning the memory configuration makes Kingfisher schedule the
    /// timer that evicts expired bitmaps on the current thread's run loop, and only the main
    /// thread's runs. (Creating the cache above scheduled one on a thread where it never fires.)
    @MainActor
    private static func setMemoryLimit(_ bytes: Int, of cache: ImageCache) {
        cache.memoryStorage.config.totalCostLimit = bytes
    }
}
