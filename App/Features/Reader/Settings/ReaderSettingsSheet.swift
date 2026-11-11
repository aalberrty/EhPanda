import EhCore
import EhModels
import SwiftUI

/// The reading settings, as a sheet inside the reader (legacy `ReadingSettingView` in the
/// reader's sheet). Every control writes its `SettingsStore` property, and the reader behind
/// the sheet follows at once.
struct ReaderSettingsSheet: View {
    /// The landscape toggle is for iPhone only.
    let showsLandscapeSetting: Bool

    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private typealias Strings = L10n.Localizable.ReadingSettingView

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker(Strings.Title.direction, selection: $settings.readingDirection) {
                        ForEach(ReadingDirection.allCases) { direction in
                            Text(direction.localizedName).tag(direction)
                        }
                    }
                    Picker(Strings.Title.preloadLimit, selection: $settings.prefetchLimit) {
                        ForEach([6, 10, 14, 18], id: \.self) { limit in
                            Text(L10n.Localizable.Common.Value.pages("\(limit)")).tag(limit)
                        }
                    }
                    if showsLandscapeSetting {
                        Toggle(Strings.Title.enablesLandscape, isOn: $settings.enablesLandscape)
                    }
                }
                Section(Strings.Section.Title.appearance) {
                    Picker(Strings.Title.separatorHeight, selection: $settings.contentDividerHeight) {
                        ForEach([0, 5, 10, 15, 20], id: \.self) { height in
                            Text(verbatim: "\(height)pt").tag(Double(height))
                        }
                    }
                    // The separator sits between the pages of the vertical strip.
                    .disabled(settings.readingDirection != .vertical)
                    ReaderScaleFactorRow(
                        title: Strings.Title.maximumScaleFactor, value: $settings.maximumScaleFactor, range: 1.5...10
                    )
                    ReaderScaleFactorRow(
                        title: Strings.Title.doubleTapScaleFactor, value: $settings.doubleTapScaleFactor, range: 1.5...5
                    )
                }
            }
            .pickerStyle(.menu)
            .navigationTitle(Strings.Title.reading)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                // Legacy: an iPhone in landscape has no room to pull the sheet down.
                if verticalSizeClass == .compact {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                    }
                }
            }
        }
        // Half height leaves the page visible while its settings change.
        .presentationDetents([.medium, .large])
    }
}

private struct ReaderScaleFactorRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack {
            LabeledContent(title) {
                Text(verbatim: label(value)).foregroundStyle(.tint)
            }
            Slider(value: $value, in: range, step: 0.5) {
                Text(title)
            } minimumValueLabel: {
                Text(verbatim: label(range.lowerBound)).font(.callout.weight(.medium))
            } maximumValueLabel: {
                Text(verbatim: label(range.upperBound)).font(.callout.weight(.medium))
            }
        }
        .padding(.vertical, Tokens.Spacing.small)
    }

    private func label(_ factor: Double) -> String {
        "\(factor.formatted(.number.precision(.fractionLength(1))))x"
    }
}
