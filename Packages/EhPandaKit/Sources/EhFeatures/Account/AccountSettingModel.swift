import Dependencies
import EhCore
import EhModels
import EhNetworking
import Foundation
import Observation

/// The account settings screen: host, login / logout, the login cookies of each host.
@Observable public final class AccountSettingModel {
    /// One editable login cookie.
    nonisolated public enum CookieField: Hashable, Sendable, CaseIterable {
        case igneous
        case memberID
        case passHash

        var keyPath: WritableKeyPath<CookiesState, CookieState> {
            switch self {
            case .igneous: \.igneous
            case .memberID: \.memberID
            case .passHash: \.passHash
            }
        }
    }

    nonisolated public enum Destination: Hashable, Sendable, Identifiable {
        /// A site page in a web view (tags management).
        case webView(URL)

        public var id: Self { self }
    }

    public var ehCookies: CookiesState = .empty(.ehentai)
    public var exCookies: CookiesState = .empty(.exhentai)
    public var destination: Destination?
    public var isConfirmingLogout = false
    /// Bumped each time cookies are copied, for the HUD and the success haptic.
    public private(set) var copyCount = 0

    /// The session's `cookieRevision` the fields last reflected.
    @ObservationIgnored private var loadedRevision: Int?

    @ObservationIgnored @Dependency(\.cookieStore) private var cookies
    @ObservationIgnored @Dependency(\.accountSession) private var session
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.clipboardClient) private var clipboard

    public init() {}

    public var isLoggedIn: Bool { session.isLoggedIn }

    /// Changes when the cookies may have changed; the screen then calls `syncCookies()`.
    public var cookieRevision: Int { session.cookieRevision }

    /// Changing it does not reload any list; legacy did not either.
    public var galleryHost: GalleryHost {
        get { settings.galleryHost }
        set { settings.galleryHost = newValue }
    }

    /// The web views open pages directly, which domain fronting cannot route.
    public var isTagsManagementAvailable: Bool {
        !settings.bypassesSNIFiltering
    }

    /// Re-reads both hosts' cookies into the fields, dropping uncommitted edits.
    public func loadCookies() {
        loadedRevision = session.cookieRevision
        ehCookies = cookies.loadCookiesState(host: .ehentai)
        exCookies = cookies.loadCookiesState(host: .exhentai)
    }

    /// Reloads the fields if the cookies changed since they were loaded, other than by this
    /// screen's own commits.
    public func syncCookies() {
        guard loadedRevision != session.cookieRevision else { return }
        loadCookies()
    }

    /// Writes one edited field (on submit or focus loss), trimmed of spaces, to every URL of
    /// its host. An unchanged value writes nothing.
    public func commit(_ field: CookieField, host: GalleryHost) {
        let state = cookiesState(for: host)[keyPath: field.keyPath]
        let value = state.editingText.trimmingCharacters(in: .whitespaces)
        guard value != state.value.rawValue else {
            // Restores the stored value after spaces-only or no-op edits.
            reloadField(field, host: host)
            return
        }
        for url in host.cookieURLs {
            cookies.setOrEditCookie(for: url, name: state.key, value: value)
        }
        let isCurrent = loadedRevision == session.cookieRevision
        session.cookiesDidChange()
        if isCurrent {
            loadedRevision = session.cookieRevision
        }
        reloadField(field, host: host)
    }

    /// Writes every field whose text differs from its stored value. The screen calls it when it
    /// goes away or the app leaves the foreground, where a focused field may never report losing
    /// focus, so a pasted cookie is not dropped.
    public func commitPendingEdits() {
        for host in GalleryHost.allCases {
            for field in CookieField.allCases {
                let state = cookiesState(for: host)[keyPath: field.keyPath]
                if state.editingText != state.value.rawValue {
                    commit(field, host: host)
                }
            }
        }
    }

    public func copyCookies(host: GalleryHost) {
        clipboard.copyText(cookies.cookiesDescription(host: host))
        copyCount += 1
    }

    public func presentTagsManagement() {
        guard isTagsManagementAvailable else { return }
        destination = .webView(EhRequestBuilder(host: galleryHost).myTagsURL)
    }

    public func logout() async {
        await session.logout()
        loadCookies()
    }

    public func cookiesKeyPath(for host: GalleryHost) -> ReferenceWritableKeyPath<AccountSettingModel, CookiesState> {
        host == .ehentai ? \.ehCookies : \.exCookies
    }

    private func cookiesState(for host: GalleryHost) -> CookiesState {
        self[keyPath: cookiesKeyPath(for: host)]
    }

    /// Reloads only `field`, so an edit in progress in another field survives.
    private func reloadField(_ field: CookieField, host: GalleryHost) {
        let fresh = cookies.loadCookiesState(host: host)[keyPath: field.keyPath]
        self[keyPath: cookiesKeyPath(for: host)][keyPath: field.keyPath] = fresh
    }
}
