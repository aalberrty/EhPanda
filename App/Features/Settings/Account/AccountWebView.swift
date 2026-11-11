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
struct AccountWebView: View {
    let url: URL
    var onLoginFinished: (([WebCookie]) -> Void)?

    @State private var page = WebPage()
    @State private var didFinishLogin = false
    @Environment(\.dismiss) private var dismiss

    // `WebPage()` uses the default data store, which keeps the web login across launches.
    private var cookieStore: WKHTTPCookieStore { WKWebsiteDataStore.default().httpCookieStore }

    var body: some View {
        NavigationStack {
            WebView(page)
                .ignoresSafeArea(edges: .bottom)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
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
