import EhFeatures
import EhModels
import SwiftUI

/// Everything below "Advanced settings"; disabled unless it is on.
struct FiltersAdvancedSections: View {
    @Bindable var model: FiltersModel
    var focusedBound: FocusState<FiltersModel.Bound?>.Binding

    var body: some View {
        Group {
            Section(L10n.Localizable.FiltersView.Section.Title.advanced) {
                Toggle(L10n.Localizable.FiltersView.Title.searchGalleryName, isOn: $model.filter.galleryName)
                Toggle(L10n.Localizable.FiltersView.Title.searchGalleryTags, isOn: $model.filter.galleryTags)
                Toggle(L10n.Localizable.FiltersView.Title.searchGalleryDescription, isOn: $model.filter.galleryDesc)
                Toggle(
                    L10n.Localizable.FiltersView.Title.searchTorrentFilenames, isOn: $model.filter.torrentFilenames
                )
                Toggle(
                    L10n.Localizable.FiltersView.Title.onlyShowGalleriesWithTorrents,
                    isOn: $model.filter.onlyWithTorrents
                )
                Toggle(L10n.Localizable.FiltersView.Title.searchLowPowerTags, isOn: $model.filter.lowPowerTags)
                Toggle(L10n.Localizable.FiltersView.Title.searchDownvotedTags, isOn: $model.filter.downvotedTags)
                Toggle(
                    L10n.Localizable.FiltersView.Title.searchExpungedGalleries, isOn: $model.filter.expungedGalleries
                )
            }
            Section {
                Toggle(L10n.Localizable.FiltersView.Title.setMinimumRating, isOn: $model.filter.minRatingActivated)
                Picker(L10n.Localizable.FiltersView.Title.minimumRating, selection: $model.filter.minRating) {
                    ForEach(2...5, id: \.self) { number in
                        Text(L10n.Localizable.Common.Value.stars("\(number)")).tag(number)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!model.filter.minRatingActivated)
                Toggle(L10n.Localizable.FiltersView.Title.setPagesRange, isOn: $model.filter.pageRangeActivated)
                    .disabled(model.isPageRangeToggleDisabled)
                pagesRange
                    .disabled(!model.filter.pageRangeActivated)
            }
            Section(L10n.Localizable.FiltersView.Section.Title.defaultFilter) {
                Toggle(L10n.Localizable.FiltersView.Title.disableLanguageFilter, isOn: $model.filter.disableLanguage)
                Toggle(L10n.Localizable.FiltersView.Title.disableUploaderFilter, isOn: $model.filter.disableUploader)
                Toggle(L10n.Localizable.FiltersView.Title.disableTagsFilter, isOn: $model.filter.disableTags)
            }
        }
        .disabled(!model.filter.advanced)
    }

    private var pagesRange: some View {
        HStack {
            Text(L10n.Localizable.FiltersView.Title.pagesRange)
            Spacer()
            SettingTextField(text: $model.filter.pageLowerBound)
                .focused(focusedBound, equals: .lower)
                .submitLabel(.next)
            Text(verbatim: "-")
            SettingTextField(text: $model.filter.pageUpperBound)
                .focused(focusedBound, equals: .upper)
                .submitLabel(.done)
        }
        .onSubmit { model.submitBound() }
    }
}
