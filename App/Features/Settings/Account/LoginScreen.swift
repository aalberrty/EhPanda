import EhFeatures
import SwiftUI

/// Settings › Account › Login: username / password over a wave background, plus the web login.
struct LoginScreen: View {
    @State private var model = LoginModel()
    @State private var loginTask: Task<Void, Never>?
    @FocusState private var focusedField: LoginModel.Field?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LoginBackground()
            VStack(spacing: Tokens.Spacing.large) {
                LoginField(
                    title: L10n.Localizable.LoginView.Title.username, text: $model.username,
                    field: .username, focusedField: $focusedField
                )
                LoginField(
                    title: L10n.Localizable.LoginView.Title.password, text: $model.password,
                    field: .password, focusedField: $focusedField
                )
                LoginButton(isLoading: model.loginState.isLoading, isDisabled: model.isLoginDisabled) {
                    run { await model.login() }
                }
                .padding(.top, Tokens.Spacing.xxLarge)
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, Tokens.Spacing.xxLarge * 2)
        }
        .onSubmit { run { await model.submit() } }
        // Two-way sync between the model's focus decisions and the keyboard.
        .onChange(of: model.focusedField) { _, newValue in focusedField = newValue }
        .onChange(of: focusedField) { _, newValue in model.focusedField = newValue }
        .onChange(of: model.didLogin) { _, didLogin in
            if didLogin { dismiss() }
        }
        .onDisappear { loginTask?.cancel() }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: model.attemptCount)
        .sensoryFeedback(.success, trigger: model.didLogin) { _, didLogin in didLogin }
        .sensoryFeedback(trigger: model.loginState) { _, state in
            state.failed == nil ? nil : .error
        }
        .animation(.default, value: model.loginState)
        .toolbar {
            if model.isWebLoginAvailable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.presentWebLogin()
                    } label: {
                        Label(L10n.Localizable.LoginView.Title.login, systemImage: "globe")
                    }
                }
            }
        }
        .sheet(isPresented: isPresentingWebLogin) {
            if let url = model.webLoginURL {
                AccountWebView(url: url) { cookies in
                    model.webLoginDidFinish(cookies: cookies)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.webLoginURL) { _, new in new != nil }
        .navigationTitle(L10n.Localizable.LoginView.Title.login)
    }

    private var isPresentingWebLogin: Binding<Bool> {
        Binding(get: { model.webLoginURL != nil }, set: { if !$0 { model.webLoginURL = nil } })
    }

    private func run(_ operation: @escaping () async -> Void) {
        loginTask?.cancel()
        loginTask = Task { await operation() }
    }
}

private struct LoginBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WaveForm(color: Color(.systemGray2).opacity(0.2), amplitude: 100, isReversed: true)
                WaveForm(color: Color(.systemGray).opacity(0.2), amplitude: 120)
            }
            .offset(y: proxy.size.height * 0.3)
            .drawingGroup()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct LoginField: View {
    let title: String
    @Binding var text: String
    let field: LoginModel.Field
    var focusedField: FocusState<LoginModel.Field?>.Binding

    private var isPassword: Bool { field == .password }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Group {
                if isPassword {
                    SecureField(title, text: $text, prompt: Text(verbatim: ""))
                } else {
                    TextField(title, text: $text, prompt: Text(verbatim: ""))
                }
            }
            .focused(focusedField, equals: field)
            .textContentType(isPassword ? .password : .username)
            .keyboardType(isPassword ? .asciiCapable : .default)
            .submitLabel(isPassword ? .done : .next)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(Tokens.Spacing.medium)
            .glassSurface(in: .rect(cornerRadius: Tokens.Radius.field), isInteractive: true)
        }
    }
}

private struct LoginButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.forward")
                .font(.title.weight(.semibold))
                .frame(width: 64, height: 64)
                .opacity(isLoading ? 0 : 1)
                .overlay {
                    if isLoading { ProgressView() }
                }
        }
        .glassButtonStyle()
        .buttonBorderShape(.circle)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(L10n.Localizable.LoginView.Title.login)
    }
}
