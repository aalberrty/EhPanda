import EhFeatures
import EhNetworking
import SwiftUI
import WebKit

/// A site page in a web view (legacy `WebView`): web login, tags management and the settings
/// page.
///
/// The page loads with the app's cookies for its host, so pages that need an account see the
/// session the app is using. With `onLoginFinished`, reaching the forum's post-login page
/// hands the web view's site cookies back.
///
/// Each web view has its own non-persistent data store, seeded from the app's cookies when it
/// opens. The app's cookie store stays the only record of the session, so after a logout no web
/// view can show the old account.
struct AccountWebView: View {
    let url: URL
    var onLoginFinished: (([WebCookie]) -> Void)?

    var body: some View {
        if #available(iOS 26, *) {
            WebPageAccountView(url: url, onLoginFinished: onLoginFinished)
        } else {
            LegacyAccountWebView(url: url, onLoginFinished: onLoginFinished)
        }
    }
}

/// `AccountWebView` on iOS 26, over the SwiftUI `WebView`.
@available(iOS 26, *)
private struct WebPageAccountView: View {
    let url: URL
    let onLoginFinished: (([WebCookie]) -> Void)?

    @State private var session = WebSession()
    @State private var didFinishLogin = false
    @Environment(\.dismiss) private var dismiss

    private var page: WebPage { session.page }
    private var cookieStore: WKHTTPCookieStore { session.dataStore.httpCookieStore }

    var body: some View {
        NavigationStack {
            WebView(page)
                .ignoresSafeArea(edges: .bottom)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton { dismiss() }
                    }
                    ToolbarItem(placement: .principal) {
                        if page.isLoading {
                            ProgressView()
                        }
                    }
                }
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
        }
        .task { await load() }
        .onChange(of: page.isLoading) { _, isLoading in
            guard !isLoading, let url = page.url else { return }
            Task { await finishLoginIfNeeded(at: url) }
        }
    }

    private func load() async {
        for cookie in HTTPCookieStorage.shared.cookies(for: url) ?? [] {
            await cookieStore.setCookie(cookie)
        }
        page.load(URLRequest(url: url))
    }

    private func finishLoginIfNeeded(at url: URL) async {
        guard let onLoginFinished, !didFinishLogin, EhURL.isLoginCompletionURL(url) else { return }
        didFinishLogin = true
        let cookies = await cookieStore.allCookies()
        onLoginFinished(cookies.map { WebCookie(name: $0.name, value: $0.value, domain: $0.domain) })
    }
}

/// A page over a data store of its own that is never written to disk.
@available(iOS 26, *)
@MainActor
private final class WebSession {
    let dataStore = WKWebsiteDataStore.nonPersistent()
    let page: WebPage

    init() {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = dataStore
        page = WebPage(configuration: configuration)
    }
}
