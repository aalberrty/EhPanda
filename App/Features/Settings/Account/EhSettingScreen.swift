import EhFeatures
import EhModels
import SFSafeSymbols
import SwiftUI

/// Settings › Account › Account configuration: the site's own settings page (`uconfig.php`).
struct EhSettingScreen: View {
    @State private var model = EhSettingModel()
    @State private var hud: HUDConfiguration?
    @State private var task: Task<Void, Never>?

    var body: some View {
        content
            .screenGround(.grouped)
            .navigationTitle(L10n.Localizable.EhSettingView.Title.hostSettings(model.galleryHost.rawValue))
            .toolbar { toolbar }
            .sheet(item: $model.destination) { destination in
                switch destination {
                case .webView(let url):
                    AccountWebView(url: url)
                }
            }
            .hud($hud)
            .sensoryFeedback(.impact(weight: .light), trigger: model.destination) { _, new in new != nil }
            .onChange(of: model.submittingState) { _, state in
                hud = switch state {
                case .idle: nil
                case .loading: .communicating
                case .failed(let error): .error(caption: error.alertText)
                }
            }
            .sensoryFeedback(trigger: model.submittingState) { _, state in
                state.failed == nil ? nil : .error
            }
            .task { await model.loadIfNeeded() }
            .onDisappear {
                task?.cancel()
                model.restoreEhPandaProfile()
            }
    }

    @ViewBuilder
    private var content: some View {
        if model.setting != nil {
            EhSettingForm(model: model, perform: perform)
        } else if let error = model.loadingState.failed {
            ErrorStateView(error: error) {
                perform { await model.load() }
            }
        } else {
            LoadingStateView()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if model.isWebViewAvailable {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.presentWebView()
                } label: {
                    Label(L10n.Localizable.AccountSettingView.Button.accountConfiguration, systemImage: "globe")
                }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                perform { await model.submit() }
            } label: {
                Label(L10n.Localizable.ReadingView.ContextMenu.Button.save, systemImage: "icloud.and.arrow.up")
            }
            .disabled(model.isSubmitDisabled)
        }
        ToolbarItem(placement: .keyboard) {
            Button(L10n.Localizable.EhSettingView.ToolbarItem.Button.done) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// Runs a request that outlives the button that started it but not the screen.
    private func perform(_ operation: @escaping () async -> Void) {
        task?.cancel()
        task = Task { await operation() }
    }
}
