import EhCore
import EhFeatures
import EhModels
import SwiftUI
import UIKit

/// Settings › Appearance › App icon (legacy `AppIconView`).
struct AppIconScreen: View {
    @State private var model = AppIconModel()
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        Form {
            Section {
                ForEach(AppIconType.allCases) { icon in
                    Button {
                        Task { await model.select(icon) }
                    } label: {
                        AppIconRow(icon: icon, isSelected: icon == settings.appIconType)
                    }
                    .buttonStyle(.plain)
                }
            }
            .raisedRows()
        }
        .screenGround(.grouped)
        .navigationTitle(L10n.Localizable.AppIconView.Title.appIcon)
        .sensoryFeedback(.selection, trigger: settings.appIconType)
        .task { model.syncWithSystem() }
    }
}

private struct AppIconRow: View {
    let icon: AppIconType
    let isSelected: Bool

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 60

    var body: some View {
        HStack(spacing: Tokens.Spacing.xLarge) {
            // The icon files are loose PNGs in the bundle (also used by `CFBundleAlternateIcons`).
            if let image = UIImage(named: icon.filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(.rect(cornerRadius: size / 4, style: .continuous))
                    .accessibilityHidden(true)
            }
            Text(icon.localizedName)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Tokens.Spacing.small)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SettingsPreview { AppIconScreen() }
}
