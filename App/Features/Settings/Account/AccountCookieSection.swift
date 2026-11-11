import EhFeatures
import EhModels
import EhNetworking
import SwiftUI

/// The login cookies of one host, editable, with a copy button (legacy `CookieSection`).
struct CookieSection: View {
    let model: AccountSettingModel
    let host: GalleryHost
    @Binding var cookies: CookiesState

    private var fields: [AccountSettingModel.CookieField] {
        // E-Hentai never uses igneous.
        host == .ehentai ? [.memberID, .passHash] : [.igneous, .memberID, .passHash]
    }

    var body: some View {
        Section {
            ForEach(fields, id: \.self) { field in
                CookieRow(cookie: $cookies[field: field]) {
                    model.commit(field, host: host)
                }
            }
            Button(L10n.Localizable.AccountSettingView.Button.copyCookies) {
                model.copyCookies(host: host)
            }
            .font(.subheadline)
        } header: {
            Text(verbatim: host.rawValue)
        }
    }
}

/// One cookie: its name, an editable value whose placeholder is the stored state, and a
/// validity mark. The value is written on return or when the field loses focus.
private struct CookieRow: View {
    @Binding var cookie: CookieState
    let commit: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        LabeledContent {
            HStack(spacing: Tokens.Spacing.small) {
                TextField(text: $cookie.editingText, prompt: Text(placeholder)) {
                    Text(verbatim: cookie.key)
                }
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit(commit)
                .onChange(of: isFocused) { _, isFocused in
                    if !isFocused { commit() }
                }
                StatusMark(status: cookie.value.status)
            }
        } label: {
            Text(verbatim: cookie.key)
        }
    }

    private var placeholder: String {
        switch cookie.value.status {
        case .valid: cookie.value.rawValue
        case .notFound: L10n.Localizable.Struct.CookieValue.LocalizedString.none
        case .expired: L10n.Localizable.Struct.CookieValue.LocalizedString.expired
        case .mystery: L10n.Localizable.Struct.CookieValue.LocalizedString.mystery
        }
    }
}

private struct StatusMark: View {
    let status: CookieValue.Status

    var body: some View {
        let isValid = status == .valid
        Image(systemName: isValid ? "checkmark.circle" : "xmark.circle")
            .foregroundStyle(isValid ? .green : .red)
            // The placeholder already says what is wrong; VoiceOver reads the field.
            .accessibilityHidden(true)
    }
}

private extension CookiesState {
    subscript(field field: AccountSettingModel.CookieField) -> CookieState {
        get {
            switch field {
            case .igneous: igneous
            case .memberID: memberID
            case .passHash: passHash
            }
        }
        set {
            switch field {
            case .igneous: igneous = newValue
            case .memberID: memberID = newValue
            case .passHash: passHash = newValue
            }
        }
    }
}
