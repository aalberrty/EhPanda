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
        await withKnownIssue { _ = try await client.diskCacheSize() }
        await withKnownIssue { await client.clearDiskCache() }
        await withKnownIssue { _ = try await client.imageData(url) }
    }

    @Test func previewValuesDoNotReportIssues() async throws {
        #expect(ClipboardClient.previewValue.url() == nil)
        #expect(await PhotoLibraryClient.previewValue.saveImage(Data()))
        #expect(await BiometricsClient.previewValue.authenticate("reason"))
        #expect(await ApplicationClient.previewValue.openURL(url))
        #expect(try await ImageCacheClient.previewValue.diskCacheSize() == 0)
    }
}
