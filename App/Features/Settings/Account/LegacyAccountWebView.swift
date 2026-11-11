import EhFeatures
import EhNetworking
import SwiftUI
import WebKit

/// `AccountWebView` on iOS 18, which has no SwiftUI `WebView`: a `WKWebView` whose loading
/// state, title and URL are mirrored into `LegacyWebSession`, so login completion is detected
/// the same way as on iOS 26 (a load ends on the forum's post-login page).
struct LegacyAccountWebView: View {
    let url: URL
    let onLoginFinished: (([WebCookie]) -> Void)?

    @State private var session = LegacyWebSession()
    @State private var didFinishLogin = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WKWebViewContainer(url: url, session: session)
                .ignoresSafeArea(edges: .bottom)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton { dismiss() }
                    }
                    ToolbarItem(placement: .principal) {
                        if session.isLoading {
                            ProgressView()
                        }
                    }
                }
                .navigationTitle(session.title)
                .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: session.isLoading) { _, isLoading in
            guard !isLoading, let url = session.url else { return }
            Task { await finishLoginIfNeeded(at: url) }
        }
    }

    private func finishLoginIfNeeded(at url: URL) async {
        guard let onLoginFinished, !didFinishLogin, EhURL.isLoginCompletionURL(url) else { return }
        didFinishLogin = true
        let cookies = await session.dataStore.httpCookieStore.allCookies()
        onLoginFinished(cookies.map { WebCookie(name: $0.name, value: $0.value, domain: $0.domain) })
    }
}

/// What the view shows of the web view, over a data store of its own that is never written to
/// disk. The web view itself is created with the representable, not here, so this stays cheap.
@Observable
@MainActor
private final class LegacyWebSession {
    var isLoading = false
    var title = ""
    var url: URL?

    @ObservationIgnored let dataStore = WKWebsiteDataStore.nonPersistent()
}

private struct WKWebViewContainer: UIViewRepresentable {
    let url: URL
    let session: LegacyWebSession

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = session.dataStore
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.start(webView: webView, url: url, session: session)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stop()
        webView.stopLoading()
    }

    @MainActor
    final class Coordinator {
        private var observations: [NSKeyValueObservation] = []
        private var loadTask: Task<Void, Never>?

        func start(webView: WKWebView, url: URL, session: LegacyWebSession) {
            // WebKit posts these on the main thread.
            observations = [
                webView.observe(\.isLoading, options: [.initial, .new]) { webView, _ in
                    MainActor.assumeIsolated { session.isLoading = webView.isLoading }
                },
                webView.observe(\.title, options: [.initial, .new]) { webView, _ in
                    MainActor.assumeIsolated { session.title = webView.title ?? "" }
                },
                webView.observe(\.url, options: [.initial, .new]) { webView, _ in
                    MainActor.assumeIsolated { session.url = webView.url }
                }
            ]
            loadTask = Task { [weak webView] in
                // Seeds the app's cookies for the host before the first request, as on iOS 26.
                let cookieStore = session.dataStore.httpCookieStore
                for cookie in HTTPCookieStorage.shared.cookies(for: url) ?? [] {
                    await cookieStore.setCookie(cookie)
                }
                guard !Task.isCancelled else { return }
                webView?.load(URLRequest(url: url))
            }
        }

        func stop() {
            loadTask?.cancel()
            observations.forEach { $0.invalidate() }
            observations = []
        }
    }
}
