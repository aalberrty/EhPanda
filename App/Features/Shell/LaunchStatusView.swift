import EhFeatures
import EhModels
import SwiftUI

/// What shows before the tabs (legacy `MigrationView`): nothing on a normal launch, "Preparing
/// the database…" when opening or importing takes a moment, and the error with "Drop the
/// database" when the database cannot be opened.
struct LaunchStatusView: View {
    @Bindable var model: AppModel

    /// A normal launch is over before this, so it shows no spinner at all.
    private static let progressDelay: Duration = .milliseconds(400)

    @State private var showsProgress = false

    var body: some View {
        ZStack {
            // Matches the empty launch screen, so the hand-over is invisible.
            Color(.systemBackground).ignoresSafeArea()
            switch model.launchState {
            case .launching:
                if showsProgress {
                    LoadingStateView(title: L10n.Localizable.LoadingView.Title.preparingDatabase)
                        .transition(.opacity)
                }
            case .failed(let error):
                failure(error)
                    .transition(.opacity)
            case .ready:
                EmptyView()
            }
        }
        .animation(.default, value: model.launchState)
        .animation(.default, value: showsProgress)
        .task(id: model.launchAttempt) {
            // After "Drop the database" the progress shows at once, as legacy did.
            showsProgress = model.launchAttempt > 0
            guard (try? await Task.sleep(for: Self.progressDelay)) != nil else { return }
            showsProgress = true
        }
    }

    private func failure(_ error: AppError) -> some View {
        ErrorStateView(error: error, retryTitle: L10n.Localizable.ErrorView.Button.dropDatabase) {
            model.isConfirmingDatabaseDrop = true
        }
        .confirmationDialog(
            Text(verbatim: ""), isPresented: $model.isConfirmingDatabaseDrop, titleVisibility: .hidden
        ) {
            Button(L10n.Localizable.ConfirmationDialog.Button.dropDatabase, role: .destructive) {
                model.dropDatabase()
            }
        } message: {
            Text(L10n.Localizable.ConfirmationDialog.Title.dropDatabase)
        }
    }
}
