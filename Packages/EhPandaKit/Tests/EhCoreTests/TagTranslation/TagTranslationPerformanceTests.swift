import EhDatabase
import EhModels
import EhTestSupport
import Foundation
import Testing
@testable import EhCore

/// Times the work behind a download of a database the size of the real one. The bounds are
/// loose so slow CI machines pass; the printed durations are the numbers to watch.
@Suite struct TagTranslationPerformanceTests {
    /// 60,000 entries with roughly the real mix: mostly plain text, about 1% images (some
    /// hidden in titles) and some escapes, plus descriptions and links that are stored as is.
    static func syntheticDatabase(count: Int = 60_000) -> [String: TagTranslation] {
        let icons = "https://raw.githubusercontent.com/wiki/EhTagTranslation/Database/database-icon/"
        let namespaces = TagNamespace.allCases
        var translations = [String: TagTranslation](minimumCapacity: count)
        for index in 0..<count {
            let value: String = switch index % 200 {
            case 0: "![图标](\(icons)\(index).webp)名\(index)"
            case 1: "![图](# \"https://ehgt.org/\(index).jpg\")标签\(index)"
            case 2: #"Name\_\#(index)"#
            default: "标签名称\(index)"
            }
            let translation = TagTranslation(
                namespace: namespaces[index % namespaces.count], key: "tag \(index)", value: value,
                description: "说明`tag \(index)`。![图](https://ehgt.org/\(index).jpg)",
                linksString: "[维基百科](https://zh.wikipedia.org/wiki/\(index))"
            )
            translations[translation.namespace.rawValue + translation.key] = translation
        }
        return translations
    }

    @Test func preparing60000Entries() async throws {
        let translations = Self.syntheticDatabase()
        let clock = ContinuousClock()

        var prepared: TagTranslationService.Prepared?
        let prepareDuration = await clock.measure {
            prepared = await TagTranslationService.prepare(translations, traditionalChineseFor: nil)
        }
        let rows = try #require(prepared).rows
        #expect(rows.count == 60_000)

        var converted = [StoredTagTranslation]()
        let conversionDuration = await clock.measure {
            converted = await TagTranslationPreparation.prepare(translations, traditionalChineseFor: ["zh-Hant-TW"])
        }
        #expect(converted.count == 60_000)
        #expect(converted.contains { $0.displayValue == "標籤名稱42" })

        let database = try await TestDatabase.inMemory()
        let writeDuration = try await clock.measure { try await database.replaceTagTranslations(rows) }
        let lookupDuration = try await clock.measure { _ = try await database.tagTranslationLookup() }
        let searchDuration = try await clock.measure {
            _ = try await database.searchTagTranslations(matching: "a", limit: TagSuggestionEngine.candidateLimit)
        }

        print("""
            [TagTranslation] 60,000 entries: prepare \(prepareDuration), \
            prepare with OpenCC (TW) \(conversionDuration), write \(writeDuration), \
            lookup table \(lookupDuration), suggestion search \(searchDuration)
            """)
        #expect(prepareDuration < .seconds(5))
        #expect(conversionDuration < .seconds(30))
    }
}
