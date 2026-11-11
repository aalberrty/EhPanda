import UIKit
import UniformTypeIdentifiers

/// Forwards a shared web link to the main app by rewriting its scheme to `ehpanda://`.
final class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await forwardSharedLink() }
    }

    private func forwardSharedLink() async {
        let appURL = await sharedLink().flatMap(Self.appURL(for:))
        extensionContext?.completeRequest(returningItems: nil) { [weak self] _ in
            guard let appURL else { return }
            Task { @MainActor in self?.openInMainApp(appURL) }
        }
    }

    private func sharedLink() async -> URL? {
        let typeIdentifier = UTType.url.identifier
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first(where: { $0.hasItemConformingToTypeIdentifier(typeIdentifier) })
        else { return nil }

        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private static func appURL(for link: URL) -> URL? {
        guard var components = URLComponents(url: link, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = "ehpanda"
        return components.url
    }

    /// Extensions have no `UIApplication.shared`, so the application is found through the responder chain.
    private func openInMainApp(_ url: URL) {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url)
                return
            }
            responder = current.next
        }
    }
}
