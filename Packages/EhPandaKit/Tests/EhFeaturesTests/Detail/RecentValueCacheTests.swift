import ConcurrencyExtras
import EhFeatures
import Testing

@Suite struct RecentValueCacheTests {
    /// What stands in for decoding a sprite sheet: counts how often it ran.
    private func decoder(_ runs: LockIsolated<[String]>) -> @Sendable (String) -> [UInt8]? {
        { sheet in
            runs.withValue { $0.append(sheet) }
            return Array(sheet.utf8)
        }
    }

    @Test func theTwentyTilesOfASheetDecodeItOnce() {
        let cache = RecentValueCache<String, [UInt8]>(capacity: 4)
        let runs = LockIsolated<[String]>([])
        let decode = decoder(runs)

        let tiles = (0..<20).map { _ in cache.value(for: "sheet-0") { decode("sheet-0") } }

        #expect(runs.value == ["sheet-0"])
        #expect(tiles.allSatisfy { $0 == Array("sheet-0".utf8) })
    }

    @Test func tilesProcessedAtTheSameTimeStillShareOneDecode() async {
        let cache = RecentValueCache<String, [UInt8]>(capacity: 4)
        let runs = LockIsolated<[String]>([])
        let decode = decoder(runs)

        await withTaskGroup(of: [UInt8]?.self) { group in
            for index in 0..<200 {
                let sheet = "sheet-\(index % 2)"
                group.addTask { cache.value(for: sheet) { decode(sheet) } }
            }
            for await value in group {
                #expect(value != nil)
            }
        }

        #expect(runs.value.sorted() == ["sheet-0", "sheet-1"])
    }

    @Test func theSheetUsedLongestAgoMakesRoom() {
        let cache = RecentValueCache<String, [UInt8]>(capacity: 2)
        let runs = LockIsolated<[String]>([])
        let decode = decoder(runs)
        for sheet in ["a", "b", "a", "c"] {
            _ = cache.value(for: sheet) { decode(sheet) }
        }
        #expect(runs.value == ["a", "b", "c"])

        // "b" was used longest ago and went when "c" came; "a" and "c" are still held.
        for sheet in ["a", "c", "b"] {
            _ = cache.value(for: sheet) { decode(sheet) }
        }
        #expect(runs.value == ["a", "b", "c", "b"])
    }

    @Test func aSheetThatDoesNotDecodeIsNotKept() {
        let cache = RecentValueCache<String, [UInt8]>(capacity: 2)
        let runs = LockIsolated(0)
        let failing: () -> [UInt8]? = {
            runs.withValue { $0 += 1 }
            return nil
        }

        #expect(cache.value(for: "broken", make: failing) == nil)
        #expect(cache.value(for: "broken", make: failing) == nil)
        #expect(runs.value == 2)
        #expect(cache.value(for: "broken") { [1] } == [1])
    }

    @Test func removeAllForgetsEverything() {
        let cache = RecentValueCache<String, [UInt8]>(capacity: 2)
        let runs = LockIsolated<[String]>([])
        let decode = decoder(runs)
        _ = cache.value(for: "a") { decode("a") }
        cache.removeAll()
        _ = cache.value(for: "a") { decode("a") }
        #expect(runs.value == ["a", "a"])
    }
}
