import EhModels
import SwiftUI

// Gallery Name Display through Cover Scaling: how lists and galleries look on the site.

struct GalleryNameSection: View, Equatable {
    let editor: EhSettingEditor
    let value: EhSetting.GalleryName

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.galleryNameDisplay,
            description: L10n.Localizable.EhSettingView.Description.galleryName
        ) {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.galleryName,
                selection: editor.binding(\.galleryName, value),
                options: EhSetting.GalleryName.allCases, name: \.localizedName
            )
        }
    }
}

struct ArchiverSection: View, Equatable {
    let editor: EhSettingEditor
    let value: EhSetting.ArchiverBehavior

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.archiverSettings,
            description: L10n.Localizable.EhSettingView.Description.archiverBehavior
        ) {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.archiverBehavior,
                selection: editor.binding(\.archiverBehavior, value),
                options: EhSetting.ArchiverBehavior.allCases, name: \.localizedName
            )
        }
    }
}

struct FrontPageSection: View, Equatable {
    let editor: EhSettingEditor
    let host: GalleryHost
    let disabledCategories: [Bool]
    let displayMode: EhSetting.DisplayMode
    let showsRangeIndicator: Bool

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.frontPageSettings,
            description: L10n.Localizable.EhSettingView.Description.galleryCategory
        ) {
            CategoryGrid(host: host, disabled: editor.binding(\.disabledCategories, disabledCategories))
        }
        Section {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.displayMode,
                selection: editor.binding(\.displayMode, displayMode),
                options: EhSetting.DisplayMode.allCases, name: \.localizedName
            )
        } footer: {
            Text(L10n.Localizable.EhSettingView.Description.displayMode)
        }
        Section(L10n.Localizable.EhSettingView.Section.Title.showSearchRangeIndicator) {
            Toggle(
                L10n.Localizable.EhSettingView.Title.showSearchRangeIndicator,
                isOn: editor.binding(\.showSearchRangeIndicator, showsRangeIndicator)
            )
        }
    }
}

/// Category tiles; a struck-through tile is hidden from the front page (legacy `CategoryView`).
private struct CategoryGrid: View {
    let host: GalleryHost
    @Binding var disabled: [Bool]
    @ScaledMetric(relativeTo: .body) private var minimumWidth: CGFloat = 80

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth, maximum: minimumWidth * 1.25))]) {
            ForEach(Array(Category.allFiltersCases.enumerated()), id: \.element) { index, category in
                if disabled.indices.contains(index) {
                    CategoryTile(category: category, host: host, isDisabled: $disabled[index])
                }
            }
        }
        .padding(.vertical, Tokens.Spacing.small)
    }
}

private struct CategoryTile: View {
    let category: Category
    let host: GalleryHost
    @Binding var isDisabled: Bool

    var body: some View {
        CategoryToggleTile(category.localizedName, color: category.color(for: host), isOn: !isDisabled) {
            isDisabled.toggle()
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isDisabled)
    }
}

struct OptionalUISection: View, Equatable {
    let editor: EhSettingEditor
    let isOn: Bool

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.optionalUIElements,
            description: L10n.Localizable.EhSettingView.Description.optionalUIElements
        ) {
            Toggle(
                L10n.Localizable.EhSettingView.Title.enableGalleryThumbnailSelector,
                isOn: editor.binding(\.enableGalleryThumbnailSelector, isOn)
            )
        }
    }
}

struct FavoritesSection: View, Equatable {
    let editor: EhSettingEditor
    let host: GalleryHost
    let names: [String]
    let sortOrder: EhSetting.FavoritesSortOrder

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.favorites,
            description: L10n.Localizable.EhSettingView.Description.favoriteCategories
        ) {
            let names = editor.binding(\.favoriteCategories, names)
            ForEach(Array(Category.allFavoritesCases.enumerated()), id: \.element) { index, category in
                if names.wrappedValue.indices.contains(index) {
                    HStack(spacing: Tokens.Spacing.large) {
                        // The folder's colour as a category mark: the vivid colour in a ring.
                        Circle()
                            .fill(category.color(for: host))
                            .environment(\.colorScheme, .light)
                            .overlay { Circle().strokeBorder(DesignColors.categoryRing, lineWidth: 1) }
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                        TextField(text: names[index]) {
                            Text(category.localizedName)
                        }
                        .autocorrectionDisabled()
                    }
                }
            }
        }
        Section {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.favoritesSortOrder,
                selection: editor.binding(\.favoritesSortOrder, sortOrder),
                options: EhSetting.FavoritesSortOrder.allCases, name: \.localizedName
            )
        } footer: {
            Text(L10n.Localizable.EhSettingView.Description.favoritesSortOrder)
        }
    }
}

struct SearchResultCountSection: View, Equatable {
    let editor: EhSettingEditor
    let value: EhSetting.SearchResultCount
    let options: [EhSetting.SearchResultCount]

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.searchResultCount,
            description: L10n.Localizable.EhSettingView.Description.resultCount
        ) {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.resultCount,
                selection: editor.binding(\.searchResultCount, value), options: options, name: \.localizedName
            )
        }
    }
}

struct ThumbnailSection: View, Equatable {
    let editor: EhSettingEditor
    let timing: EhSetting.ThumbnailLoadTiming
    let size: EhSetting.ThumbnailSize
    let sizes: [EhSetting.ThumbnailSize]
    let rows: EhSetting.ThumbnailRowCount
    let rowOptions: [EhSetting.ThumbnailRowCount]

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.thumbnailSettings,
            description: [
                L10n.Localizable.EhSettingView.Description.thumbnailLoadTiming, timing.localizedDescription
            ].joined(separator: "\n")
        ) {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.thumbnailLoadTiming,
                selection: editor.binding(\.thumbnailLoadTiming, timing),
                options: EhSetting.ThumbnailLoadTiming.allCases, name: \.localizedName
            )
        }
        Section {
            SegmentedRow(
                title: L10n.Localizable.EhSettingView.Title.thumbnailSize,
                selection: editor.binding(\.thumbnailConfigSize, size), options: sizes, name: \.localizedName
            )
            SegmentedRow(
                title: L10n.Localizable.EhSettingView.Title.thumbnailRowCount,
                selection: editor.binding(\.thumbnailConfigRows, rows), options: rowOptions, name: \.localizedName
            )
        } footer: {
            Text(L10n.Localizable.EhSettingView.Description.thumbnailConfiguration)
        }
    }
}

private struct SegmentedRow<Value: Hashable>: View {
    let title: String
    let selection: Binding<Value>
    let options: [Value]
    let name: (Value) -> String

    var body: some View {
        LabeledContent(title) {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(name(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }
}

struct CoverScalingSection: View, Equatable {
    let editor: EhSettingEditor
    let value: Float

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.coverScaling,
            description: L10n.Localizable.EhSettingView.Description.coverScaleFactor
        ) {
            ValueSlider(
                title: L10n.Localizable.EhSettingView.Title.scaleFactor,
                value: editor.binding(\.coverScaleFactor, value), range: 75...150, unit: "%"
            )
        }
    }
}
