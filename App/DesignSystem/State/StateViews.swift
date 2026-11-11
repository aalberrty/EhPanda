import SwiftUI

/// Full-screen loading indicator (legacy `LoadingView`).
struct LoadingStateView: View {
    private let title: String

    init(title: String = L10n.Localizable.LoadingView.Title.loading) {
        self.title = title
    }

    var body: some View {
        ProgressView(title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Full-screen error with an optional retry button (legacy `ErrorView` / `AlertView`).
///
/// Legacy showed only a symbol and a message; `title` is optional so feature screens can map an
/// error to the same output. Pass `retry: nil` for errors that retrying cannot fix.
struct ErrorStateView: View {
    private let title: String?
    private let message: String
    private let systemImage: String
    private let retryTitle: String
    private let retry: (() -> Void)?

    init(
        title: String? = nil, message: String, systemImage: String = "questionmark.circle.fill",
        retryTitle: String = L10n.Localizable.ErrorView.Button.retry, retry: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.retryTitle = retryTitle
        self.retry = retry
    }

    var body: some View {
        StatusView(title: title, message: message, systemImage: systemImage) {
            if let retry {
                Button(retryTitle, action: retry)
            }
        }
    }
}

/// Nothing to show (legacy `ErrorView(error: .notFound)`).
struct EmptyStateView: View {
    private let message: String
    private let systemImage: String

    init(message: String = L10n.Localizable.ErrorView.Title.notFound, systemImage: String = "questionmark.circle.fill") {
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        StatusView(title: nil, message: message, systemImage: systemImage) { EmptyView() }
    }
}

/// Prompt shown by screens that need an account (legacy `NotLoginView`).
struct NotLoggedInView: View {
    private let login: () -> Void

    init(login: @escaping () -> Void) {
        self.login = login
    }

    var body: some View {
        StatusView(
            title: nil, message: L10n.Localizable.NotLoginView.Title.needLogin,
            systemImage: "person.crop.circle.badge.questionmark.fill"
        ) {
            Button(L10n.Localizable.NotLoginView.Button.login, action: login)
        }
    }
}

/// `ContentUnavailableView` laid out the way legacy `AlertView` read: a large symbol, the message
/// as the description, and a glass button.
private struct StatusView<Actions: View>: View {
    let title: String?
    let message: String
    let systemImage: String
    @ViewBuilder let actions: Actions

    var body: some View {
        ContentUnavailableView {
            Label {
                if let title {
                    Text(title)
                }
            } icon: {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
            }
        } description: {
            Text(message)
        } actions: {
            actions
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        }
    }
}

private struct StateViewsPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            LoadingStateView().frame(height: 120)
            ErrorStateView(
                message: L10n.Localizable.ErrorView.Title.network, systemImage: "wifi.exclamationmark", retry: {}
            )
            ErrorStateView(
                title: L10n.Localizable.Hud.Title.error,
                message: L10n.Localizable.ErrorView.Title.galleryUnavailable, systemImage: "trash.circle.fill"
            )
            EmptyStateView()
            NotLoggedInView {}
        }
    }
}

#Preview {
    SchemePreview { StateViewsPreview() }
}
