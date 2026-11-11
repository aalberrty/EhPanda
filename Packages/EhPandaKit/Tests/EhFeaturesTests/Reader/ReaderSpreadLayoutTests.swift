import CoreGraphics
import Testing
@testable import EhFeatures

/// The legacy functions, copied as they were, so the new mapping is checked against them
/// rather than against expectations written from memory.
private enum Legacy {
    struct Config: Equatable {
        var firstIndex: Int
        var secondIndex: Int
        var isFirstAvailable: Bool
        var isSecondAvailable: Bool
    }

    static func containerDataSource(pageCount: Int, isDualPage: Bool, exceptCover: Bool) -> [Int] {
        let defaultData = Array(1...pageCount)
        guard isDualPage else { return defaultData }
        return exceptCover
            ? [1] + Array(stride(from: 2, through: pageCount, by: 2))
            : Array(stride(from: 1, through: pageCount, by: 2))
    }

    static func imageContainerConfigs(
        index: Int, pageCount: Int, isDualPage: Bool, exceptCover: Bool, isReversed: Bool
    ) -> Config {
        let isFirstSingle = exceptCover
        let isFirstPageAndSingle = index == 1 && isFirstSingle
        let firstIndex = isDualPage && isReversed && !isFirstPageAndSingle ? index + 1 : index
        let secondIndex = firstIndex + (isReversed ? -1 : 1)
        let isValidFirstRange = firstIndex >= 1 && firstIndex <= pageCount
        let isValidSecondRange = isFirstSingle
            ? secondIndex >= 2 && secondIndex <= pageCount
            : secondIndex >= 1 && secondIndex <= pageCount
        return Config(
            firstIndex: firstIndex, secondIndex: secondIndex, isFirstAvailable: isValidFirstRange,
            isSecondAvailable: !isFirstPageAndSingle && isValidSecondRange && isDualPage
        )
    }

    static func mapFromPager(index: Int, pageCount: Int, isDualPage: Bool, exceptCover: Bool) -> Int {
        guard isDualPage else { return index + 1 }
        guard index > 0 else { return 1 }
        let result = exceptCover ? index * 2 : index * 2 + 1
        return result + 1 == pageCount ? pageCount : result
    }

    static func mapToPager(index: Int, isDualPage: Bool, exceptCover: Bool) -> Int {
        guard isDualPage else { return index - 1 }
        guard index > 1 else { return 0 }
        return exceptCover ? index / 2 : (index - 1) / 2
    }

    /// Pages drawn left to right by the legacy `HorizontalImageStack`.
    static func pagesOnScreen(_ config: Config) -> [Int] {
        var pages: [Int] = []
        if config.isFirstAvailable { pages.append(config.firstIndex) }
        if config.isSecondAvailable { pages.append(config.secondIndex) }
        return pages
    }
}

@Suite struct ReaderSpreadLayoutTests {
    private static let pageCounts = Array(1...13) + [40, 41]
    private static let flags = [false, true]

    @Test func spreadsMatchLegacyDataSource() {
        for pageCount in Self.pageCounts {
            for isDualPage in Self.flags {
                for exceptCover in Self.flags {
                    let layout = ReaderSpreadLayout(pageCount: pageCount, isDualPage: isDualPage, exceptCover: exceptCover)
                    let legacy = Legacy.containerDataSource(
                        pageCount: pageCount, isDualPage: isDualPage, exceptCover: exceptCover
                    )
                    #expect(layout.spreadCount == legacy.count)
                    #expect((0..<layout.spreadCount).map(layout.firstPage(ofSpread:)) == legacy)
                }
            }
        }
    }

    @Test func pagesOnScreenMatchLegacyStack() {
        for pageCount in Self.pageCounts {
            for isDualPage in Self.flags {
                for exceptCover in Self.flags {
                    for rightToLeft in Self.flags {
                        let layout = ReaderSpreadLayout(
                            pageCount: pageCount, isDualPage: isDualPage, exceptCover: exceptCover
                        )
                        for spread in 0..<layout.spreadCount {
                            let config = Legacy.imageContainerConfigs(
                                index: layout.firstPage(ofSpread: spread), pageCount: pageCount,
                                isDualPage: isDualPage, exceptCover: exceptCover, isReversed: rightToLeft
                            )
                            #expect(
                                layout.pagesOnScreen(inSpread: spread, rightToLeft: rightToLeft)
                                    == Legacy.pagesOnScreen(config),
                                "pages \(pageCount) dual \(isDualPage) cover \(exceptCover) rtl \(rightToLeft) spread \(spread)"
                            )
                        }
                    }
                }
            }
        }
    }

    @Test func pageToSpreadMatchesLegacyPager() {
        for pageCount in Self.pageCounts {
            for isDualPage in Self.flags {
                for exceptCover in Self.flags {
                    let layout = ReaderSpreadLayout(pageCount: pageCount, isDualPage: isDualPage, exceptCover: exceptCover)
                    for page in 1...pageCount {
                        #expect(
                            layout.spreadIndex(forPage: page)
                                == Legacy.mapToPager(index: page, isDualPage: isDualPage, exceptCover: exceptCover)
                        )
                    }
                }
            }
        }
    }

    @Test func reportedPageMatchesLegacyPager() {
        for pageCount in Self.pageCounts {
            for isDualPage in Self.flags {
                for exceptCover in Self.flags {
                    let layout = ReaderSpreadLayout(pageCount: pageCount, isDualPage: isDualPage, exceptCover: exceptCover)
                    for spread in 0..<layout.spreadCount {
                        #expect(
                            layout.reportedPage(forSpread: spread) == Legacy.mapFromPager(
                                index: spread, pageCount: pageCount, isDualPage: isDualPage, exceptCover: exceptCover
                            )
                        )
                    }
                }
            }
        }
    }

    @Test func everyPageBelongsToExactlyOneSpread() {
        for pageCount in Self.pageCounts {
            for isDualPage in Self.flags {
                for exceptCover in Self.flags {
                    let layout = ReaderSpreadLayout(pageCount: pageCount, isDualPage: isDualPage, exceptCover: exceptCover)
                    let pages = (0..<layout.spreadCount).flatMap { Array(layout.pages(inSpread: $0)) }
                    #expect(pages == Array(1...pageCount))
                    for page in 1...pageCount {
                        #expect(layout.pages(inSpread: layout.spreadIndex(forPage: page)).contains(page))
                    }
                }
            }
        }
    }

    @Test func dualPageExamples() {
        let plain = ReaderSpreadLayout(pageCount: 5, isDualPage: true, exceptCover: false)
        #expect(plain.spreadCount == 3)
        #expect(plain.pagesOnScreen(inSpread: 0, rightToLeft: false) == [1, 2])
        #expect(plain.pagesOnScreen(inSpread: 0, rightToLeft: true) == [2, 1])
        #expect(plain.pagesOnScreen(inSpread: 2, rightToLeft: true) == [5])

        let cover = ReaderSpreadLayout(pageCount: 5, isDualPage: true, exceptCover: true)
        #expect(cover.spreadCount == 3)
        #expect(cover.pagesOnScreen(inSpread: 0, rightToLeft: true) == [1])
        #expect(cover.pagesOnScreen(inSpread: 1, rightToLeft: false) == [2, 3])
        #expect(cover.pagesOnScreen(inSpread: 2, rightToLeft: true) == [5, 4])
        // The last spread ends on the last page, so it reports the last page.
        #expect(cover.reportedPage(forSpread: 2) == 5)
        #expect(cover.reportedPage(forSpread: 1) == 2)
    }

    @Test func exceptCoverIsIgnoredWithoutDualPages() {
        let layout = ReaderSpreadLayout(pageCount: 4, isDualPage: false, exceptCover: true)
        #expect(layout.exceptCover == false)
        #expect(layout.spreadCount == 4)
        #expect(layout.pages(inSpread: 2) == 3...3)
    }

    @Test func emptyAndOutOfRangeInputsAreClamped() {
        let empty = ReaderSpreadLayout(pageCount: 0, isDualPage: true, exceptCover: true)
        #expect(empty.spreadCount == 0)
        #expect(empty.spreadIndex(forPage: 3) == 0)
        #expect(empty.reportedPage(forSpread: 0) == 1)

        let layout = ReaderSpreadLayout(pageCount: 7, isDualPage: true, exceptCover: false)
        #expect(layout.spreadIndex(forPage: -4) == 0)
        #expect(layout.spreadIndex(forPage: 99) == layout.spreadCount - 1)
    }

    @Test func dualPageNeedsAPagedDirectionAndAWideView() {
        var configuration = ReaderConfiguration(direction: .leftToRight, allowsDualPage: true)
        #expect(configuration.usesDualPage(in: CGSize(width: 900, height: 600)))
        #expect(!configuration.usesDualPage(in: CGSize(width: 600, height: 900)))
        #expect(!configuration.usesDualPage(in: CGSize(width: 600, height: 600)))
        configuration.direction = .vertical
        #expect(!configuration.usesDualPage(in: CGSize(width: 900, height: 600)))
        configuration.direction = .rightToLeft
        configuration.allowsDualPage = false
        #expect(!configuration.usesDualPage(in: CGSize(width: 900, height: 600)))
    }
}
