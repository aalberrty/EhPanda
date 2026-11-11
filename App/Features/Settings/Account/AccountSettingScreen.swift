import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Settings › Account: host, login / logout, account configuration and the login cookies.
struct AccountSettingScreen: View {
    @State private var model = AccountSettingModel()
    @State private var hud: HUDConfiguration?
    @Environment(StackRouter.self) private var stack
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Section {
                HostPicker(selection: $model.galleryHost)
                if model.isLoggedIn {
                    LoggedInRows(model: model, stack: stack)
                } else {
                    Button(L10n.Localizable.AccountSettingView.Button.login) {
                        stack.push(.settings(.login))
                    }
                    .disclosureIndicator()
                }
            }
            CookieSection(model: model, host: .ehentai, cookies: $model.ehCookies)
            CookieSection(model: model, host: .exhentai, cookies: $model.exCookies)
        }
        .navigationTitle(L10n.Localizable.AccountSettingView.Title.account)
        .sheet(item: $model.destination) { destination in
            switch destination {
            case .webView(let url):
                AccountWebView(url: url)
            }
        }
        .hud($hud)
        .sensoryFeedback(.success, trigger: model.copyCount)
        .onChange(of: model.copyCount) { hud = .copiedToClipboard }
        // Loads on appear, and again when a login, logout or igneous fetch changed the cookies.
        .onChange(of: model.cookieRevision, initial: true) { model.syncCookies() }
        // Back, a tab switch or backgrounding with a field still focused may not end its editing.
        .onDisappear { model.commitPendingEdits() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.commitPendingEdits() }
        }
    }
}

private struct HostPicker: View {
    @Binding var selection: GalleryHost

    var body: some View {
        Picker(selection: $selection) {
            ForEach(GalleryHost.allCases) { host in
                Text(verbatim: host.rawValue).tag(host)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
    }
}

private struct LoggedInRows: View {
    @Bindable var model: AccountSettingModel
    let stack: StackRouter
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Button(L10n.Localizable.ConfirmationDialog.Button.logout, role: .destructive) {
            model.isConfirmingLogout = true
        }
        .confirmationDialog(
            L10n.Localizable.ConfirmationDialog.Title.logout,
            isPresented: $model.isConfirmingLogout,
            titleVisibility: .visible
        ) {
            Button(L10n.Localizable.ConfirmationDialog.Button.logout, role: .destructive) {
                Task { await model.logout() }
            }
        }
        Group {
            Button(L10n.Localizable.AccountSettingView.Button.accountConfiguration) {
                stack.push(.settings(.ehSetting))
            }
            .disclosureIndicator()
            if model.isTagsManagementAvailable {
                Button(L10n.Localizable.AccountSettingView.Button.tagsManagement) {
                    model.presentTagsManagement()
                }
                .disclosureIndicator()
            }
            Toggle(
                L10n.Localizable.AccountSettingView.Title.showsNewDawnGreeting,
                isOn: $settings.showsNewDawnGreeting
            )
        }
        .foregroundStyle(.primary)
    }
}
