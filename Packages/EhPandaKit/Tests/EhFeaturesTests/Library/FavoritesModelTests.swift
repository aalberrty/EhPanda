@testable import EhFeatures
import EhModels
import EhTestSupport
import Testing

@Suite struct FavoritesModelTests {
    @Test func loadsAllFoldersFirstAndPagesWithIDAndTimestamp() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: try ListFixture.favoritesSorted(by: .lastUpdateTime))
        let model = env.make { FavoritesModel() }

        await model.list.loadIfNeeded()
        #expect(model.category == -1)
        #expect(env.query("favcat", ofRequest: 0) == "all")
        #expect(env.query("inline_set", ofRequest: 0) == nil)
        #expect(model.sortOrder == .lastUpdateTime)

        await model.list.loadMore()
        #expect(env.query("next", ofRequest: 1)
            == "\(ListFixture.favoritesLastID)-\(ListFixture.favoritesLastTimestamp)")
    }

    @Test func requiresLogin() async throws {
        let env = try ListTestEnvironment(loggedIn: false)
        let model = env.make { FavoritesModel() }
        await model.list.loadIfNeeded()
        #expect(model.list.phase == .notLoggedIn)
        #expect(env.transport.requests.isEmpty)

        model.reloadForTabReselection()
        #expect(env.transport.requests.isEmpty)
    }

    @Test func anExpiredLoginFailsWithLoginRequiredInsteadOfAnEmptyList() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture("Parser/Other/LoginRequired.html"))
        let model = env.make { FavoritesModel() }

        await model.list.loadIfNeeded()

        #expect(model.list.phase == .failed(.loginRequired))
    }

    @Test func eachFolderKeepsItsOwnList() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.favorites))
        let model = env.make { FavoritesModel() }
        var screen = ListScreenTask()
        await screen.render(model.list)
        let all = model.list

        // Selecting a folder that has not loaded loads it, through the view's task alone.
        model.select(category: 3)
        #expect(model.category == 3)
        await screen.render(model.list)
        #expect(env.query("favcat", ofRequest: 1) == "3")
        #expect(model.list.phase == .content)

        model.select(category: -1)
        #expect(model.list === all)
        await screen.render(model.list)
        #expect(env.transport.requests.count == 2)
        #expect(model.list.phase == .content)
    }

    @Test func sortOrderChangeReloadsWithInlineSetAndDropsOtherFolders() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: try ListFixture.favoritesSorted(by: .favoritedTime))
        let model = env.make { FavoritesModel() }
        model.select(category: 2)
        await model.list.loadIfNeeded()
        model.select(category: -1)
        await model.list.loadIfNeeded()
        let current = try #require(model.sortOrder)

        model.setSortOrder(current)
        #expect(!model.list.galleries.isEmpty)

        let other: FavoritesSortOrder = current == .favoritedTime ? .lastUpdateTime : .favoritedTime
        model.setSortOrder(other)
        #expect(model.list.galleries.isEmpty)
        await model.list.loadIfNeeded()
        #expect(env.query("inline_set", ofRequest: 2) != nil)

        let previousCount = env.transport.requests.count
        var screen = ListScreenTask()
        await screen.render(model.list)
        model.select(category: 2)
        #expect(model.list.galleries.isEmpty)
        await screen.render(model.list)
        #expect(env.transport.requests.count == previousCount + 1)
        #expect(env.query("inline_set", ofRequest: previousCount) == nil)
    }

    @Test func keywordSearchesTheCurrentFolder() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.favorites))
        let model = env.make { FavoritesModel() }
        await model.list.loadIfNeeded()

        model.keyword = "tag"
        model.submitKeyword()
        await model.list.loadIfNeeded()
        #expect(env.query("f_search", ofRequest: 1) == "tag")
        #expect(env.query("sn", ofRequest: 1) == "on")

        var screen = ListScreenTask()
        await screen.render(model.list)
        model.select(category: 4)
        await screen.render(model.list)
        #expect(env.query("f_search", ofRequest: 2) == "tag")

        model.quickSearch("other")
        #expect(model.keyword == "other")
        await model.list.loadIfNeeded()
        #expect(env.query("f_search", ofRequest: 3) == "other")
        #expect(env.query("favcat", ofRequest: 3) == "4")
    }

    @Test func tabReselectionReloadsTheCurrentFolder() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.favorites))
        let model = env.make { FavoritesModel() }
        await model.list.loadIfNeeded()
        let request = model.list.loadRequest

        model.reloadForTabReselection()
        #expect(model.list.loadRequest != request)
        #expect(model.list.phase == .loading)
        await model.list.loadIfNeeded()
        #expect(env.transport.requests.count == 2)
        #expect(model.list.phase == .content)
    }
}
