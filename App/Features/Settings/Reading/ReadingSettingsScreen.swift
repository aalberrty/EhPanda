import EhCore
import EhFeatures
import EhModels
import SwiftUI
import UIKit

/// Settings › Reading (legacy `ReadingSettingView`).
struct ReadingSettingsScreen: View {
    var body: some View {
        ReadingSettingsForm()
            .navigationTitle(L10n.Localizable.ReadingSettingView.Title.reading)
    }
}

/// The reading options. The reader shows the same form in its settings sheet.
///
/// Dual-page mode and "except the cover" are only edited from the reader's panel, as in legacy.
struct ReadingSettingsForm: View {
    @State private var model = ReadingSettingsModel()
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker(L10n.Localizable.ReadingSettingView.Title.direction, selection: $settings.readingDirection) {
                    ForEach(ReadingDirection.allCases) { direction in
                        Text(direction.localizedName).tag(direction)
                    }
                }
                .pickerStyle(.menu)
                Picker(L10n.Localizable.ReadingSettingView.Title.preloadLimit, selection: $settings.prefetchLimit) {
                    ForEach(Array(stride(from: 6, through: 18, by: 4)), id: \.self) { value in
                        Text(L10n.Localizable.Common.Value.pages("\(value)")).tag(value)
                    }
                }
                .pickerStyle(.menu)
                // Only iPhone locks the reader to portrait.
                if UIDevice.current.userInterfaceIdiom != .pad {
                    Toggle(
                        L10n.Localizable.ReadingSettingView.Title.enablesLandscape,
                        isOn: Binding(get: { settings.enablesLandscape }, set: { model.setEnablesLandscape($0) })
                    )
                }
            }
            Section(L10n.Localizable.ReadingSettingView.Section.Title.appearance) {
                Picker(
                    L10n.Localizable.ReadingSettingView.Title.separatorHeight,
                    selection: $settings.contentDividerHeight
                ) {
                    ForEach(Array(stride(from: 0, through: 20, by: 5)), id: \.self) { value in
                        Text(verbatim: "\(value)pt").tag(Double(value))
                    }
                }
                .pickerStyle(.menu)
                // The separator only exists between vertically stacked pages.
                .disabled(settings.readingDirection != .vertical)
                ScaleFactorRow(
                    title: L10n.Localizable.ReadingSettingView.Title.maximumScaleFactor,
                    value: $settings.maximumScaleFactor,
                    range: 1.5...10
                )
                ScaleFactorRow(
                    title: L10n.Localizable.ReadingSettingView.Title.doubleTapScaleFactor,
                    value: $settings.doubleTapScaleFactor,
                    range: 1.5...5
                )
            }
        }
    }
}

/// A zoom factor slider in steps of 0.5. `SettingsStore` keeps double-tap ≤ maximum.
private struct ScaleFactorRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading) {
            LabeledContent(title) {
                Text(Self.format(value)).foregroundStyle(.tint).monospacedDigit()
            }
            Slider(value: $value, in: range, step: 0.5) {
                Text(title)
            } minimumValueLabel: {
                Text(Self.format(range.lowerBound)).font(.callout.weight(.medium))
            } maximumValueLabel: {
                Text(Self.format(range.upperBound)).font(.callout.weight(.medium))
            }
            .accessibilityValue(Self.format(value))
        }
        .padding(.vertical, Tokens.Spacing.xSmall)
    }

    private static func format(_ factor: Double) -> String {
        factor.formatted(.number.precision(.fractionLength(1))) + "x"
    }
}

#Preview {
    SettingsPreview { ReadingSettingsScreen() }
}
