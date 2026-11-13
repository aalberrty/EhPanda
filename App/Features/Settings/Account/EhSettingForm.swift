import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Every option group of the settings page, in the site's order.
///
/// This view reads `model.setting` and hands each section only the values it shows. Sections
/// are `Equatable`, so an edit re-renders the section that changed and leaves the others.
struct EhSettingForm: View {
    let model: EhSettingModel
    let perform: (@escaping () async -> Void) -> Void
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        if let setting = model.setting {
            let editor = EhSettingEditor(model: model)
            Form {
                Group {
                    EhProfileSection(
                        model: model, profiles: setting.ehProfiles,
                        canCreate: setting.isCapableOfCreatingNewProfile, perform: perform
                    )
                    ImageLoadSection(
                        editor: editor, value: setting.loadThroughHathSetting,
                        options: setting.capableLoadThroughHathSettings,
                        country: setting.browsingCountry,
                        detectedCountry: setting.localizedLiteralBrowsingCountry ?? setting.literalBrowsingCountry
                    )
                    ImageSizeSection(
                        editor: editor, resolution: setting.imageResolution,
                        resolutions: setting.capableImageResolutions, useOriginalImages: setting.useOriginalImages,
                        width: setting.imageSizeWidth, height: setting.imageSizeHeight
                    )
                    GalleryNameSection(editor: editor, value: setting.galleryName)
                    ArchiverSection(editor: editor, value: setting.archiverBehavior)
                    FrontPageSection(
                        editor: editor, host: settings.galleryHost, disabledCategories: setting.disabledCategories,
                        displayMode: setting.displayMode, showsRangeIndicator: setting.showSearchRangeIndicator
                    )
                    OptionalUISection(editor: editor, isOn: setting.enableGalleryThumbnailSelector)
                    FavoritesSection(
                        editor: editor, host: settings.galleryHost,
                        names: setting.favoriteCategories, sortOrder: setting.favoritesSortOrder
                    )
                    SearchResultCountSection(
                        editor: editor, value: setting.searchResultCount, options: setting.capableSearchResultCounts
                    )
                    ThumbnailSection(
                        editor: editor, timing: setting.thumbnailLoadTiming, size: setting.thumbnailConfigSize,
                        sizes: setting.capableThumbnailConfigSizes, rows: setting.thumbnailConfigRows,
                        rowOptions: setting.capableThumbnailConfigRowCounts
                    )
                    CoverScalingSection(editor: editor, value: setting.coverScaleFactor)
                    RatingsSection(editor: editor, value: setting.ratingsColor)
                    TagWatchingSection(editor: editor, value: setting.tagWatchingThreshold)
                    TagFilteringSection(editor: editor, value: setting.tagFilteringThreshold)
                    FilteredRemovalSection(editor: editor, isOn: setting.showFilteredRemovalCount)
                    ExcludedLanguagesSection(editor: editor, values: setting.excludedLanguages)
                    ExcludedUploadersSection(editor: editor, text: setting.excludedUploaders)
                    ViewportSection(editor: editor, value: setting.viewportVirtualWidth)
                    CommentsSection(
                        editor: editor, order: setting.commentsSortOrder, timing: setting.commentVotesShowTiming
                    )
                    TagsSection(editor: editor, value: setting.tagsSortOrder)
                    PageLabelingSection(editor: editor, value: setting.galleryPageNumbering)
                    MultiPageViewerSection(
                        editor: editor, isOn: setting.useMultiplePageViewer,
                        style: setting.multiplePageViewerStyle, showsPane: setting.multiplePageViewerShowThumbnailPane
                    )
                }
                .raisedRows()
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

/// Writes a section's edits back into `model.setting`.
///
/// Equal whenever the model is the same, so a section's equality depends only on the values
/// it shows.
struct EhSettingEditor: Equatable {
    let model: EhSettingModel

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model === rhs.model
    }

    /// A binding that shows `value` (the section's copy) and writes to `keyPath`.
    func binding<Value>(_ keyPath: WritableKeyPath<EhSetting, Value>, _ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { model.setting?[keyPath: keyPath] = $0 })
    }

    /// A binding to an option that only some accounts have; `nil` when the page omits it.
    func binding<Value>(_ keyPath: WritableKeyPath<EhSetting, Value?>, _ value: Value?) -> Binding<Value>? {
        value.map { value in
            Binding(get: { value }, set: { model.setting?[keyPath: keyPath] = $0 })
        }
    }
}

// MARK: Shared rows

/// A form section with the site's group title as header and its explanation as footer.
struct EhSettingSection<Content: View>: View {
    let title: String
    var description: String?
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            content
        } header: {
            Text(title)
        } footer: {
            if let description {
                Text(LocalizedStringKey(description))
            }
        }
    }
}

/// A menu picker over a list of options.
struct OptionPicker<Value: Hashable>: View {
    let title: String
    let selection: Binding<Value>
    let options: [Value]
    let name: (Value) -> String

    var body: some View {
        Picker(title, selection: selection) {
            ForEach(options, id: \.self) { option in
                Text(name(option)).tag(option)
            }
        }
        .pickerStyle(.menu)
    }
}

/// A whole-number slider with its current value (legacy `ValuePicker`).
struct ValueSlider: View {
    let title: String
    let value: Binding<Float>
    let range: ClosedRange<Float>
    var unit = ""

    var body: some View {
        LabeledContent(title) {
            Text(verbatim: format(value.wrappedValue))
                .monospacedDigit()
                .foregroundStyle(.tint)
        }
        Slider(value: value, in: range, step: 1) {
            Text(title)
        } minimumValueLabel: {
            Text(verbatim: format(range.lowerBound)).font(.callout.weight(.medium))
        } maximumValueLabel: {
            Text(verbatim: format(range.upperBound)).font(.callout.weight(.medium))
        }
        .accessibilityValue(Text(verbatim: format(value.wrappedValue)))
    }

    private func format(_ number: Float) -> String {
        String(Int(number)) + unit
    }
}
