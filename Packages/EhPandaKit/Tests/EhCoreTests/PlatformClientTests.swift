import Foundation
import Testing
@testable import EhCore

/// Un-overridden test dependencies must fail the test instead of silently succeeding.
@MainActor
@Suite struct PlatformClientTests {
    private let url = URL(string: "https://e-hentai.org")!

    @Test func clipboardTestValueReportsIssues() async {
        let client = ClipboardClient.testValue
        withKnownIssue { _ = client.changeCount() }
        withKnownIssue { _ = client.url() }
        withKnownIssue { client.copyText("text") }
        await withKnownIssue { await client.copyImage(Data()) }
    }

    @Test func photoLibraryTestValueReportsIssues() async {
        await withKnownIssue { _ = await PhotoLibraryClient.testValue.saveImage(Data()) }
    }

    @Test func biometricsTestValueReportsIssues() async {
        let client = BiometricsClient.testValue
        withKnownIssue { _ = client.isAvailable() }
        await withKnownIssue { _ = await client.authenticate("reason") }
    }

    @Test func applicationTestValueReportsIssues() async {
        let client = ApplicationClient.testValue
        withKnownIssue { _ = client.isPad() }
        await withKnownIssue { _ = await client.openURL(url) }
        await withKnownIssue { await client.openSettings() }
        withKnownIssue { _ = client.alternateIconName() }
        await withKnownIssue { _ = await client.setAlternateIconName("icon") }
        withKnownIssue { client.setOrientationLock(.portrait) }
    }

    @Test func imageCacheTestValueReportsIssues() async {
        let client = ImageCacheClient.testValue
        await withKnownIssue { await client.configure(.standard(physicalMemory: 0)) }
        await withKnownIssue { _ = try await client.diskCacheSize() }
        await withKnownIssue { await client.clearDiskCache() }
        await withKnownIssue { _ = try await client.imageData(url) }
    }

    @Test func imageCacheLimitsFollowTheDevicesMemoryUpToACap() {
        let megabyte: UInt64 = 1024 * 1024
        // An eighth of the RAM...
        #expect(ImageCacheLimits.standard(physicalMemory: 2048 * megabyte).memoryBytes == 256 * 1024 * 1024)
        #expect(ImageCacheLimits.standard(physicalMemory: 3072 * megabyte).memoryBytes == 384 * 1024 * 1024)
        // ...and never more than 512 MB, however much there is.
        #expect(ImageCacheLimits.standard(physicalMemory: 4096 * megabyte).memoryBytes == 512 * 1024 * 1024)
        #expect(ImageCacheLimits.standard(physicalMemory: 16384 * megabyte).memoryBytes == 512 * 1024 * 1024)
    }

    @Test func theDiskCacheHasALimit() {
        // Kingfisher reads 0 as "no limit", which is what the cache had.
        for memory: UInt64 in [0, 2 << 30, 8 << 30] {
            #expect(ImageCacheLimits.standard(physicalMemory: memory).diskBytes == 2 * 1024 * 1024 * 1024)
        }
    }

    @Test func previewValuesDoNotReportIssues() async throws {
        #expect(ClipboardClient.previewValue.url() == nil)
        #expect(await PhotoLibraryClient.previewValue.saveImage(Data()))
        #expect(await BiometricsClient.previewValue.authenticate("reason"))
        #expect(await ApplicationClient.previewValue.openURL(url))
        #expect(try await ImageCacheClient.previewValue.diskCacheSize() == 0)
    }
}
