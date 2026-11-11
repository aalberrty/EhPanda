@testable import EhCore
import EhDatabase
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

@Suite struct LaunchClientTests {
    private static let ehentai = GalleryHost.ehentai.url
    private static let exhentai = GalleryHost.exhentai.url
    private static let imageHost = URL(string: "https://s.exhentai.org/")!

    @Test func cookieHousekeepingFixesEveryCookieInOneLaunch() async {
        let cookies = CookieStore(storage: InMemoryCookieStorage())
        cookies.setOrEditCookie(for: Self.ehentai, name: CookieName.ipbMemberId, value: "42")
        cookies.setOrEditCookie(for: Self.ehentai, name: CookieName.ipbPassHash, value: "hash")
        cookies.setOrEditCookie(for: Self.exhentai, name: CookieName.yay, value: "louder")

        await CookieHousekeeping.run(cookies)

        #expect(cookies.cookie(named: CookieName.yay, for: Self.exhentai) == .empty)
        #expect(cookies.memberID(for: .exhentai) == "42")
        #expect(cookies.passHash(for: .exhentai) == "hash")
        // Filled before the image host is synced, so it is logged in from this launch on.
        #expect(cookies.cookie(named: CookieName.ipbMemberId, for: Self.imageHost).rawValue == "42")
        #expect(cookies.cookie(named: CookieName.ignoreOffensive, for: Self.ehentai).rawValue == "1")
        #expect(cookies.cookie(named: CookieName.ignoreOffensive, for: Self.exhentai).rawValue == "1")
    }

    @Test func droppingTheDatabaseDeletesItsFiles() async throws {
        let directory = try TestDatabase.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("EhPanda.sqlite")
        for suffix in ["", "-wal", "-shm"] {
            try Data("x".utf8).write(to: URL(fileURLWithPath: url.path + suffix))
        }

        try await DatabaseFiles.delete(at: url)
        // Files already gone are fine.
        try await DatabaseFiles.delete(at: url)

        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test func droppedDatabaseOpensEmpty() async throws {
        let (database, directory) = try await TestDatabase.onDisk()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("EhPanda.sqlite")
        try await database.recordSearchKeyword("kept?")

        try await DatabaseFiles.delete(at: url)
        let reopened = try await AppDatabase.open(at: url)

        #expect(try await first(reopened.observeSearchHistory()).isEmpty)
    }

    @Test func clipboardChangeCountStoreKeepsTheLastCount() {
        let store = ClipboardChangeCountStore.inMemory()
        #expect(store.load() == nil)
        store.save(7)
        #expect(store.load() == 7)
        #expect(ClipboardChangeCountStore.key == "clipboardChangeCount")
    }
}
