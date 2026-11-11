import EhFeatures
import Kingfisher
import Synchronization
import UIKit

nonisolated enum ImagePipelineError: Error {
    /// The data could not be turned into an image.
    case undecodable
}

/// Loads gallery images for display.
///
/// Kingfisher does what it is good at: downloading (with request coalescing), the disk cache
/// and the memory cache. The decode is done here instead of through a Kingfisher processor,
/// for two reasons. Kingfisher's own downsampling fits the *longest* side into the box, which
/// ruins long strips. And its decodes cannot be cancelled and run one after the other, so a
/// fling through cached pages would leave the pages it ends on waiting behind all the ones
/// that are already off screen again.
///
/// What ends up where:
/// - Disk: the original bytes, untouched, under the URL as key (Kingfisher's default key). The
///   host reads them back with `originalData(for:)` to copy, save or share the full image.
/// - Memory: bitmaps decoded for a particular `ImageDecodeTarget`, in Kingfisher's memory
///   cache, so the cost limit and the memory warning handling are shared with everything else.
nonisolated enum ImagePipeline {
    /// Kingfisher's default downloader, the one list covers use as well. The launch sequence
    /// gives it the shared cookie jar, which the site's image servers need, and switches domain
    /// fronting on it (`ImageDownloaderConfiguration`), so reader pages follow both settings.
    static var downloader: ImageDownloader { .default }

    /// The default cache, the one list covers use as well. The launch sequence gives it its
    /// memory budget and disk limit (`ImageCacheConfiguration`), whether or not the reader is
    /// ever opened.
    static var cache: ImageCache { .default }

    /// Decoding is CPU and memory heavy, so only a few run at once.
    private static let decodeLimiter = ConcurrencyLimiter(limit: 3)

    /// Disk writes that are on their way, by cache key. A download hands its bytes to whoever
    /// asked for them at once and is written to disk meanwhile; anyone who looks for the file
    /// in that moment waits for the write instead of downloading the image again.
    private static let pendingStores = Mutex(PendingStores())

    private struct PendingStores {
        var lastID = 0
        var byKey: [String: (id: Int, task: Task<Void, Never>)] = [:]
    }

    /// Priority for downloads nobody is waiting for yet.
    static let prefetchPriority = URLSessionTask.lowPriority

    // MARK: Display

    /// The image for `url` decoded for `target`, if it is in memory. Does no I/O.
    static func cachedImage(for url: URL, target: ImageDecodeTarget) -> UIImage? {
        cache.memoryStorage.value(forKey: memoryKey(for: url, target: target))
    }

    /// Loads, downsamples and decodes an image off the calling actor.
    ///
    /// Cancelling the calling task cancels the download and skips the decode.
    /// - Parameters:
    ///   - keepsInMemory: Whether to keep the result in the memory cache. Pass `false` for
    ///     one-off decodes such as a zoomed-in page.
    ///   - progress: Download progress from 0 to 1. Not called when the data is already on disk.
    @concurrent
    static func image(
        for url: URL, target: ImageDecodeTarget, displayScale: CGFloat, keepsInMemory: Bool = true,
        progress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws -> UIImage {
        let isRemote = !url.isFileURL
        var downloaded: Data?
        if isRemote, await !isOnDisk(url.cacheKey) {
            // Decoded straight from the downloaded bytes; the disk write does not hold it up.
            downloaded = try await download(url, priority: URLSessionTask.defaultPriority, progress: progress)
        }
        var image = try await decode(downloaded, from: url, target: target, displayScale: displayScale)
        if image == nil, isRemote, downloaded == nil {
            // The cached file was unreadable or has gone since the check. Leaving it would make
            // every retry fail the same way, so drop it and fetch the image again.
            try? cache.diskStorage.remove(forKey: url.cacheKey)
            let fresh = try await download(url, priority: URLSessionTask.defaultPriority, progress: progress)
            image = try await decode(fresh, from: url, target: target, displayScale: displayScale)
        }
        guard let image else {
            if isRemote {
                try? cache.diskStorage.remove(forKey: url.cacheKey)
            }
            throw ImagePipelineError.undecodable
        }
        if keepsInMemory {
            cache.memoryStorage.store(value: image, forKey: memoryKey(for: url, target: target))
        }
        return image
    }

    // MARK: Prefetch and originals

    /// Makes sure the original data for `url` is on disk, without decoding it, and returns the
    /// image's pixel size if it can be read from the header.
    @concurrent
    static func prefetch(_ url: URL) async throws -> CGSize? {
        guard !url.isFileURL else { return ImageDecoder.pixelSize(ofFileAt: url) }
        let key = url.cacheKey
        if await isOnDisk(key) {
            return ImageDecoder.pixelSize(ofFileAt: cache.diskStorage.cacheFileURL(forKey: key))
        }
        let data = try await download(url, priority: prefetchPriority, progress: nil)
        // Being on disk is what prefetching is for, and nobody is waiting to look at it.
        await pendingStore(of: key)?.value
        return ImageDecoder.pixelSize(of: data)
    }

    /// The untouched bytes of an image, for copying, saving and sharing. From disk when the
    /// image was shown or prefetched. Anything else (a full-size original, mostly) is
    /// downloaded with the downloader every image uses, which sends the site's cookies and
    /// follows the domain-fronting setting, and is kept on disk.
    @concurrent
    static func originalData(for url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        if let data = await storedOriginalData(for: url) {
            return data
        }
        return try await download(url, priority: URLSessionTask.defaultPriority, progress: nil)
    }

    /// The untouched bytes of an image that has been loaded or prefetched; `nil` if it has not.
    @concurrent
    static func storedOriginalData(for url: URL) async -> Data? {
        if !url.isFileURL {
            await pendingStore(of: url.cacheKey)?.value
        }
        return storedData(for: url)
    }

    // MARK: Private

    private static func memoryKey(for url: URL, target: ImageDecodeTarget) -> String {
        "\(url.cacheKey)@\(target.identifier)"
    }

    /// Reads (unless `data` is given) and decodes inside a decode slot, so that a burst of
    /// requests neither reads every file at once nor decodes them all in parallel.
    @concurrent
    private static func decode(
        _ data: Data?, from url: URL, target: ImageDecodeTarget, displayScale: CGFloat
    ) async throws -> UIImage? {
        try await decodeLimiter.acquire()
        var image: UIImage?
        if !Task.isCancelled, let data = data ?? storedData(for: url) {
            image = ImageDecoder.decode(data, target: target, displayScale: displayScale)
        }
        await decodeLimiter.release()
        try Task.checkCancellation()
        return image
    }

    private static func storedData(for url: URL) -> Data? {
        if url.isFileURL {
            return try? Data(contentsOf: url, options: .mappedIfSafe)
        }
        return try? cache.diskStorage.value(forKey: url.cacheKey)
    }

    /// Whether the original is in the disk cache, counting a write that is still on its way.
    private static func isOnDisk(_ key: String) async -> Bool {
        await pendingStore(of: key)?.value
        return cache.diskStorage.isCached(forKey: key)
    }

    private static func pendingStore(of key: String) -> Task<Void, Never>? {
        pendingStores.withLock { $0.byKey[key]?.task }
    }

    /// Writes downloaded bytes to the disk cache without making the caller wait for it.
    private static func store(_ data: Data, forKey key: String) {
        pendingStores.withLock { stores in
            stores.lastID += 1
            let id = stores.lastID
            // Started under the lock, so its own clean-up below cannot run before it is registered.
            let task = Task.detached(priority: .utility) {
                try? await cache.storeToDisk(data, forKey: key)
                pendingStores.withLock { stores in
                    if stores.byKey[key]?.id == id {
                        stores.byKey[key] = nil
                    }
                }
            }
            stores.byKey[key] = (id, task)
        }
    }

    /// Downloads the original and starts writing it to the disk cache. Requests for a URL that
    /// is already downloading share that download.
    @concurrent
    private static func download(
        _ url: URL, priority: Float, progress: (@MainActor @Sendable (Double) -> Void)?
    ) async throws -> Data {
        var progressBlock: DownloadProgressBlock?
        if let progress {
            // Kingfisher reports progress on the main queue.
            progressBlock = { received, total in
                guard total > 0 else { return }
                let fraction = min(max(Double(received) / Double(total), 0), 1)
                if Thread.isMainThread {
                    MainActor.assumeIsolated { progress(fraction) }
                } else {
                    Task { @MainActor in progress(fraction) }
                }
            }
        }
        let result = try await downloader.downloadImage(
            with: url, options: [.downloadPriority(priority)], progressBlock: progressBlock
        )
        store(result.originalData, forKey: url.cacheKey)
        return result.originalData
    }
}
