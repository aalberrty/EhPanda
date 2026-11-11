import EhFeatures
import EhModels
import SwiftUI

/// Profile selection and management (legacy `EhProfileSection`).
struct EhProfileSection: View, Equatable {
    @Bindable var model: EhSettingModel
    let profiles: [EhProfile]
    let canCreate: Bool
    let perform: (@escaping () async -> Void) -> Void
    @FocusState private var isNameFocused: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model === rhs.model && lhs.profiles == rhs.profiles && lhs.canCreate == rhs.canCreate
    }

    var body: some View {
        Section(L10n.Localizable.EhSettingView.Section.Title.profileSettings) {
            if let selected = model.selectedProfile {
                Picker(L10n.Localizable.EhSettingView.Title.selectedProfile, selection: selection(selected)) {
                    ForEach(profiles) { profile in
                        Text(profile.name).tag(profile.value)
                    }
                }
                .pickerStyle(.menu)

                if !selected.isDefault {
                    Button(L10n.Localizable.EhSettingView.Button.setAsDefault) {
                        perform { await model.setSelectedProfileAsDefault() }
                    }
                    Button(L10n.Localizable.EhSettingView.Button.deleteProfile, role: .destructive) {
                        model.isConfirmingDeletion = true
                    }
                    .confirmationDialog(
                        L10n.Localizable.ConfirmationDialog.Title.delete,
                        isPresented: $model.isConfirmingDeletion,
                        titleVisibility: .visible
                    ) {
                        Button(L10n.Localizable.ConfirmationDialog.Button.delete, role: .destructive) {
                            perform { await model.deleteSelectedProfile() }
                        }
                    }
                }
            }
        }

        Section {
            TextField(text: $model.editingProfileName) {
                Text(L10n.Localizable.EhSettingView.Title.selectedProfile)
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isNameFocused)

            if model.selectedProfile != nil {
                Button(L10n.Localizable.EhSettingView.Button.rename) {
                    perform { await model.renameSelectedProfile() }
                }
                .disabled(isNameFocused)
            }
            if canCreate {
                Button(L10n.Localizable.EhSettingView.Button.createNew) {
                    perform { await model.createProfile() }
                }
                .disabled(isNameFocused)
            }
        }
    }

    /// Choosing a profile switches it on the server at once, as legacy did.
    private func selection(_ selected: EhProfile) -> Binding<Int> {
        Binding(
            get: { selected.value },
            set: { value in perform { await model.selectProfile(value) } }
        )
    }
}
