import Dependencies
import EhCore
import EhModels
import EhNetworking
import Foundation
import Observation

/// Fetches the daily "New Dawn" greeting on launch and on every unlock (legacy
/// `SettingReducer.fetchGreeting`) and hands one worth announcing to the shell.
@Observable
public final class GreetingModel {
    private let router: AppRouter

    @ObservationIgnored private var isFetching = false

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.cookieStore) private var cookies
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.userStore) private var userStore
    @ObservationIgnored @Dependency(\.date) private var date
    @ObservationIgnored @Dependency(\.appLogger) private var logger

    init(router: AppRouter) {
        self.router = router
    }

    /// Fetches the greeting when logged in, "Shows New Dawn greeting" is on and none was stored
    /// since today began (UTC, the site's day). A page without a greeting stores an empty one
    /// dated now, so the next unlock today does not ask again.
    func fetchIfNeeded() async {
        guard !isFetching, cookies.didLogin, settings.showsNewDawnGreeting,
              Self.isDue(lastUpdate: userStore.greeting, now: date.now)
        else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            let greeting = try await client.greeting()
            userStore.updateGreeting(greeting)
            if !greeting.gainedNothing {
                router.presentedGreeting = greeting
            }
        } catch AppError.parseFailed {
            userStore.updateGreeting(Greeting(updateTime: date.now))
        } catch is CancellationError {
            return
        } catch {
            logger.warning("Greeting fetch failed: \(error)", category: Self.logCategory)
        }
    }

    /// Whether a new greeting may exist: there is no stored one, it has no date, or it is from
    /// before the start of the current UTC day (legacy compared dates formatted `dd MMMM yyyy`
    /// in UTC, which is the same day boundary).
    nonisolated static func isDue(lastUpdate greeting: Greeting?, now: Date) -> Bool {
        guard let updateTime = greeting?.updateTime else { return true }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let startOfDay = calendar.startOfDay(for: now)
        return now > startOfDay && updateTime < startOfDay
    }

    nonisolated static let logCategory = "Greeting"
}
