@testable import EhDatabase
import EhModels
import EhTestSupport
import Foundation
import Testing

/// Generous bounds (debug build, tests running in parallel) that still catch quadratic work
/// or per-row statement compilation, which take minutes at these sizes. Measured on the
/// development Mac, debug build, run alone: 60,000 translations ≈ 2.5 s, 2,000 pages ≈ 0.15 s.
@Suite struct PerformanceTests {
    @Test func replacing60000TagTranslationsIsFast() async throws {
        let database = try await TestDatabase.inMemory()
        let namespaces = TagNamespace.allCases
        let translations = (0..<60_000).map { index in
            let namespace = namespaces[index % namespaces.count]
            return StoredTagTranslation(
                key: namespace.rawValue + "tag \(index)",
                translation: TagTranslation(
                    namespace: namespace, key: "tag \(index)", value: "![](https://x.org/\(index).png)值\(index)",
                    description: "description \(index)", linksString: "[link](https://x.org/\(index))"
                ),
                displayValue: "值\(index)",
                valueImageURL: URL(string: "https://x.org/\(index).png")
            )
        }

        // The first replace fills the table so the timed one also deletes 60,000 rows.
        try await database.replaceTagTranslations(translations)
        let clock = ContinuousClock()
        var start = clock.now
        try await database.replaceTagTranslations(translations)
        let elapsed = clock.now - start
        #expect(elapsed < .seconds(120), "\(elapsed)")
        #expect(try await database.tagTranslationCount() == 60_000)

        start = clock.now
        let lookup = try await database.tagTranslationLookup()
        let lookupTime = clock.now - start
        #expect(lookup.count == 60_000)
        #expect(lookupTime < .seconds(60), "\(lookupTime)")
    }

    @Test func upserting2000PagesIsFast() async throws {
        let database = try await TestDatabase.inMemory()
        let pages = (1...2_000).map { index in
            GalleryPage(gid: "1", index: index, pageURL: URL(string: "https://e-hentai.org/s/\(index)"),
                        previewURL: URL(string: "https://ehgt.org/p/\(index).jpg"))
        }
        let images = (1...2_000).map { index in
            GalleryPage(gid: "1", index: index, imageURL: URL(string: "https://x.org/\(index).jpg"),
                        imageWidth: 1280, imageHeight: 1800)
        }

        let clock = ContinuousClock()
        let start = clock.now
        try await database.upsertPages(pages)
        try await database.upsertPages(images)
        let elapsed = clock.now - start
        #expect(elapsed < .seconds(60), "\(elapsed)")
        let stored = try await database.pages(gid: "1")
        #expect(stored.count == 2_000)
        #expect(stored.allSatisfy { $0.pageURL != nil && $0.imageURL != nil && $0.imageWidth == 1280 })
    }
}
