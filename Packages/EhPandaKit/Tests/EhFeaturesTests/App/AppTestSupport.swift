import ConcurrencyExtras
import Dependencies
@testable import EhCore
import EhDatabase
@testable import EhFeatures
import EhModels
import EhNetworking
import EhTestSupport
import Foundation
import Testing

/// Ordered log of what the stubs saw.
nonisolated final class EventLog: Sendable {
    private let events = LockIsolated<[String]>([])

    func record(_ event: String) {
        events.withValue { $0.append(event) }
    }

    var all: [String] { events.value }

    func index(of event: String) -> Int? {
        all.firstIndex(of: event)
    }
}

/// Lets a stub wait until the test opens it.
nonisolated final class Gate: Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private let waiting = LockIsolated(false)

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    var isWaiting: Bool { waiting.value }

    func wait() async {
        waiting.setValue(true)
        for await _ in stream { break }
        waiting.setValue(false)
    }

    func open() {
        continuation.yield()
    }
}

/// A mutable "now" for `\.date`.
nonisolated final class TestClock: Sendable {
    private let now: LockIsolated<Date>

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        now = LockIsolated(start)
    }

    var date: Date { now.value }

    func advance(by interval: TimeInterval) {
        now.withValue { $0 += interval }
    }

    func set(_ date: Date) {
        now.setValue(date)
    }

    var generator: DateGenerator { DateGenerator { self.now.value } }
}

nonisolated enum AppFixture {
    static let galleryURL = URL(string: "https://e-hentai.org/g/3103480/0000000000/")!
    static let detailPage = "Parser/Gallery/GalleryDetail.html"
    static let detailWithGreeting = "Parser/Other/GalleryDetailWithGreeting.html"
    static let imagePage = "Parser/Gallery/GalleryNormalImageURL.html"

    static func gallery(gid: String = "3103480", url: URL? = galleryURL) -> Gallery {
        Gallery(
            gid: gid, token: "0000000000", title: "Stored", rating: 4, tags: [], category: .manga,
            pageCount: 10, postedDate: Date(timeIntervalSince1970: 0), coverURL: nil, galleryURL: url
        )
    }

    static func client(_ transport: StubTransport, cookies: CookieStore = loggedOutCookies()) -> EhClient {
        EhClient(transport: transport, cookies: cookies, host: { .ehentai })
    }

    static func loggedOutCookies() -> CookieStore {
        CookieStore(storage: InMemoryCookieStorage())
    }

    static func loggedInCookies() -> CookieStore {
        let cookies = CookieStore(storage: InMemoryCookieStorage())
        cookies.setOrEditCookie(for: GalleryHost.ehentai.url, name: CookieName.ipbMemberId, value: "42")
        cookies.setOrEditCookie(for: GalleryHost.ehentai.url, name: CookieName.ipbPassHash, value: "hash")
        return cookies
    }

    static func biometrics(available: Bool = true, succeeds: Bool = true) -> BiometricsClient {
        BiometricsClient(isAvailable: { available }, authenticate: { _ in succeeds })
    }

    static func clipboard(changeCount: Int = 0, url: URL? = nil) -> ClipboardClient {
        ClipboardClient(changeCount: { changeCount }, url: { url }, copyText: { _ in }, copyImage: { _ in })
    }

    static func application(
        isPad: Bool = false, alternateIconName: String? = nil, events: EventLog = EventLog()
    ) -> ApplicationClient {
        ApplicationClient(
            isPad: { isPad }, openURL: { _ in true }, openSettings: {},
            alternateIconName: { alternateIconName }, setAlternateIconName: { _ in true },
            setOrientationLock: { events.record("orientation \($0)") }
        )
    }

    static func domainFronting(events: EventLog) -> DomainFrontingClient {
        let enabled = LockIsolated(false)
        return DomainFrontingClient(
            isEnabled: { enabled.value },
            setEnabled: { value in
                enabled.setValue(value)
                events.record("domainFronting \(value)")
            }
        )
    }
}

/// Polls `condition` on the main actor until it holds, failing after `timeout`.
@MainActor
func waitUntil(
    timeout: Duration = .seconds(2), sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        guard clock.now < deadline else {
            Issue.record("Condition not met in time", sourceLocation: sourceLocation)
            return
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
}

/// A clock whose sleeps return at once (unless cancelled). `ImmediateClock` yields through
/// background-priority tasks, which a busy machine can starve for seconds.
nonisolated struct InstantClock: Clock {
    struct Instant: InstantProtocol {
        var offset: Duration = .zero

        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    var now: Instant { Instant() }
    var minimumResolution: Duration { .zero }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()
    }
}
