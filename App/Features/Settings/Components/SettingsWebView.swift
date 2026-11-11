import SwiftUI
import WebKit

/// A web page inside a settings screen (legacy `WebView`), used for pages of the site such as
/// tag subscriptions and the site's own settings. Login has its own web view, which copies
/// the session cookies into the app.
///
/// Callers hide their entry points while "Bypasses SNI filtering" is on: the web view cannot
/// use the app's domain-fronted transport.
struct SettingsWebView: View {
    let url: URL

    var body: some View {
        WebPageView(url: url)
            .ignoresSafeArea(edges: .bottom)
    }
}

private struct WebPageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        webView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(loadedURL: url)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
    }

    final class Coordinator {
        var loadedURL: URL

        init(loadedURL: URL) {
            self.loadedURL = loadedURL
        }
    }
}

#Preview {
    if let url = URL(string: "https://ehpanda.app") {
        SettingsWebView(url: url)
    }
}
