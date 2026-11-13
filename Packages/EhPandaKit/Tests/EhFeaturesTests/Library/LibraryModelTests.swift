import Dependencies
import EhCore
@testable import EhFeatures
import EhModels
import EhTestSupport
import Foundation
import Testing

@Suite struct LibraryModelTests {
    private func makeModel(store: LibrarySegmentStore, env: ListTestEnvironment) -> LibraryModel {
        withDependencies {
            $0.librarySegmentStore = store
        } operation: {
            env.make { LibraryModel() }
        }
    }

    @Test func opensOnFavoritesTheFirstTimeAndThenOnTheSegmentUsedLast() throws {
        let env = try ListTestEnvironment()
        let store = LibrarySegmentStore.inMemory()
        let model = makeModel(store: store, env: env)
        #expect(model.segment == .favorites)
        #expect(model.openedSegments == [.favorites])
        #expect(store.load() == nil)

        model.select(.history)
        #expect(model.segment == .history)
        #expect(store.load() == .history)

        let next = makeModel(store: store, env: env)
        #expect(next.segment == .history)
        #expect(next.openedSegments == [.history])
    }

    @Test func openedSegmentsStayInControlOrderAndNeverShrink() throws {
        let env = try ListTestEnvironment()
        let model = makeModel(store: .inMemory(.history), env: env)

        model.select(.favorites)
        #expect(model.openedSegments == [.favorites, .history])
        model.select(.watched)
        #expect(model.openedSegments == [.favorites, .watched, .history])
        model.select(.history)
        #expect(model.openedSegments == [.favorites, .watched, .history])
    }

    @Test func switchingSegmentsKeepsEachListsLoadedPages() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.favorites))
        let model = makeModel(store: .inMemory(), env: env)
        let favorites = model.favorites.list
        var favoritesScreen = ListScreenTask()
        await favoritesScreen.render(favorites)
        await favorites.loadMore()
        let loaded = favorites.galleries.count

        model.select(.watched)
        var watchedScreen = ListScreenTask()
        await watchedScreen.render(model.watched.list)
        #expect(env.query("favcat", ofRequest: 2) == nil)
        #expect(model.watched.list.phase == .content)

        // Back on Favorites: the same list, with both pages, and no request.
        model.select(.favorites)
        await favoritesScreen.render(model.favorites.list)
        #expect(model.favorites.list === favorites)
        #expect(favorites.galleries.count == loaded)
        #expect(env.transport.requests.count == 3)
    }

    @Test func theSearchFieldBelongsToTheSegmentOnShow() throws {
        let env = try ListTestEnvironment()
        let model = makeModel(store: .inMemory(), env: env)
        #expect(model.searchesServer)

        model.searchText = "artist:a"
        #expect(model.favorites.keyword == "artist:a")
        model.submitSearch()
        #expect(model.favorites.list.source == .favorites(category: -1, keyword: "artist:a", sortOrder: nil))

        model.select(.watched)
        #expect(model.searchText.isEmpty)
        model.searchText = "language:english"
        model.submitSearch()
        #expect(model.watched.list.source == .watched(keyword: "language:english"))

        model.select(.history)
        #expect(!model.searchesServer)
        model.searchText = "title"
        #expect(model.history.titleFilter == "title")
        model.submitSearch()

        model.select(.favorites)
        #expect(model.searchText == "artist:a")
        #expect(model.watched.keyword == "language:english")
    }

    @Test func quickSearchClosesTheSheetAndSearchesTheSegmentOnShow() throws {
        let env = try ListTestEnvironment()
        let model = makeModel(store: .inMemory(.watched), env: env)

        model.destination = .quickSearch
        model.quickSearch("female:glasses")

        #expect(model.destination == nil)
        #expect(model.watched.list.source == .watched(keyword: "female:glasses"))
        #expect(model.favorites.keyword.isEmpty)
    }

    @Test func tabReselectionReloadsOnlyTheSegmentOnShow() async throws {
        let env = try ListTestEnvironment()
        env.transport.on(.any, reply: .fixture(ListFixture.favorites))
        let model = makeModel(store: .inMemory(.watched), env: env)
        await model.watched.list.loadIfNeeded()
        await model.favorites.list.loadIfNeeded()
        let favoritesRequest = model.favorites.list.loadRequest
        let watchedRequest = model.watched.list.loadRequest

        model.reloadForTabReselection()
        #expect(model.watched.list.loadRequest != watchedRequest)
        #expect(model.favorites.list.loadRequest == favoritesRequest)

        model.select(.history)
        let reloaded = model.watched.list.loadRequest
        model.reloadForTabReselection()
        #expect(model.watched.list.loadRequest == reloaded)
        #expect(model.favorites.list.loadRequest == favoritesRequest)
    }

    @Test func tabReselectionLoggedOutRequestsNothing() async throws {
        let env = try ListTestEnvironment(loggedIn: false)
        let model = makeModel(store: .inMemory(.watched), env: env)
        await model.watched.list.loadIfNeeded()
        #expect(model.watched.list.phase == .notLoggedIn)

        model.reloadForTabReselection()

        #expect(model.watched.list.phase == .notLoggedIn)
        #expect(env.transport.requests.isEmpty)
    }

    @Test func folderChipsAreAllThenEveryFolderWithTheUsersOwnNames() {
        let users = UserStore(defaults: UserDefaults(suiteName: "LibraryModelTests-\(UUID().uuidString)")!)
        let model = withDependencies { $0.userStore = users } operation: { FavoritesModel() }
        #expect(model.folders.map(\.index) == Array(-1...9))
        #expect(model.folders.allSatisfy { $0.customName == nil })
        #expect(model.folders.first?.isAll == true)

        users.updateFavoriteCategories([0: "Favorites 0", 1: "Doujinshi", 9: "Later"])

        let names = model.folders.map(\.customName)
        #expect(names[0] == nil)
        #expect(names[1] == nil)
        #expect(names[2] == "Doujinshi")
        #expect(names[10] == "Later")
    }
}
