import EhCore
import EhFeatures
import SwiftUI
import UniformTypeIdentifiers

/// The Tags section of Settings › General (legacy `GeneralSettingView`, "Tags").
struct TagTranslationSection: View {
    @State private var model = TagTranslationSettingsModel()
    @State private var isImporting = false
    @State private var isConfirmingRemoval = false
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Section {
            Toggle(isOn: enablesTagsExtension) {
                HStack {
                    Text(L10n.Localizable.GeneralSettingView.Title.enablesTagsExtension)
                    Spacer()
                    if model.isLoading {
                        ProgressView()
                    } else if model.showsEmptyWarning {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                    }
                }
            }
            if model.showsTranslationOptions {
                Toggle(L10n.Localizable.GeneralSettingView.Title.translatesTags, isOn: $settings.translatesTags)
                Toggle(
                    L10n.Localizable.GeneralSettingView.Title.showsTagsSearchSuggestion,
                    isOn: $settings.showsTagsSearchSuggestion
                )
                Toggle(L10n.Localizable.GeneralSettingView.Title.showsImagesInTags, isOn: $settings.showsImagesInTags)
            }
            Button(L10n.Localizable.GeneralSettingView.Button.importCustomTranslations) {
                isImporting = true
            }
            .disabled(model.isLoading)
            if model.hasCustomTranslations {
                Button(L10n.Localizable.GeneralSettingView.Button.removeCustomTranslations, role: .destructive) {
                    isConfirmingRemoval = true
                }
                .confirmationDialog(
                    L10n.Localizable.ConfirmationDialog.Title.removeCustomTranslations,
                    isPresented: $isConfirmingRemoval,
                    titleVisibility: .visible
                ) {
                    Button(L10n.Localizable.ConfirmationDialog.Button.remove, role: .destructive) {
                        Task { await model.removeCustomTranslations() }
                    }
                }
            }
        } header: {
            Text(L10n.Localizable.GeneralSettingView.Section.Title.tags)
        } footer: {
            if let failure = model.failure {
                Label {
                    Text(failure.alertText)
                } icon: {
                    Image(systemName: failure.symbol.rawValue).accessibilityHidden(true)
                }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            Task { await model.importCustomTranslations(from: url) }
        }
        .task { await model.onAppear() }
        .animation(.default, value: model.showsTranslationOptions)
        .animation(.default, value: model.hasCustomTranslations)
        .animation(.default, value: model.isLoading)
    }

    private var enablesTagsExtension: Binding<Bool> {
        Binding(
            get: { settings.enablesTagsExtension },
            set: { isOn in Task { await model.setEnablesTagsExtension(isOn) } }
        )
    }
}
