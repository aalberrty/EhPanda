import SwiftUI

/// The last row of a paged list (legacy `FetchMoreFooter`).
///
/// The row keeps a constant height in every phase so the list does not jump when a page lands.
/// Trigger the next page from the model (e.g. the last cell's `onAppear`), not from this view.
struct PaginationFooter: View {
    enum Phase: Hashable, Sendable {
        /// Nothing happening; more pages may follow.
        case idle
        case loading
        /// The last page request failed; shows a retry button.
        case failed
        /// No more pages.
        case end
    }

    private let phase: Phase
    private let retry: () -> Void

    init(phase: Phase, retry: @escaping () -> Void) {
        self.phase = phase
        self.retry = retry
    }

    var body: some View {
        ZStack {
            switch phase {
            case .loading:
                ProgressView()
            case .failed:
                Button(action: retry) {
                    Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                        .imageScale(.large)
                        .foregroundStyle(.red)
                }
                .glassButtonStyle()
                .buttonBorderShape(.circle)
                .accessibilityLabel(L10n.Localizable.ErrorView.Button.retry)
            case .idle, .end:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .animation(.default, value: phase)
    }
}

private struct PaginationFooterPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach([PaginationFooter.Phase.idle, .loading, .failed, .end], id: \.self) { phase in
                PaginationFooter(phase: phase) {}
                    .overlay(alignment: .leading) {
                        Text(verbatim: "\(phase)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                Divider()
            }
        }
    }
}

#Preview {
    SchemePreview { PaginationFooterPreview() }
}
