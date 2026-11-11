import EhModels
import SwiftUI

// Viewport Override through Multi-Page Viewer: the gallery and viewer pages.

struct ViewportSection: View, Equatable {
    let editor: EhSettingEditor
    let value: Float

    var body: some View {
        EhSettingSection(
            title: L10n.Localizable.EhSettingView.Section.Title.viewportOverride,
            description: L10n.Localizable.EhSettingView.Description.virtualWidth
        ) {
            ValueSlider(
                title: L10n.Localizable.EhSettingView.Title.virtualWidth,
                value: editor.binding(\.viewportVirtualWidth, value), range: 0...9999, unit: "px"
            )
        }
    }
}

struct CommentsSection: View, Equatable {
    let editor: EhSettingEditor
    let order: EhSetting.CommentsSortOrder
    let timing: EhSetting.CommentVotesShowTiming

    var body: some View {
        Section(L10n.Localizable.EhSettingView.Section.Title.galleryComments) {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.commentsSortOrder,
                selection: editor.binding(\.commentsSortOrder, order),
                options: EhSetting.CommentsSortOrder.allCases, name: \.localizedName
            )
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.commentsVotesShowTiming,
                selection: editor.binding(\.commentVotesShowTiming, timing),
                options: EhSetting.CommentVotesShowTiming.allCases, name: \.localizedName
            )
        }
    }
}

struct TagsSection: View, Equatable {
    let editor: EhSettingEditor
    let value: EhSetting.TagsSortOrder

    var body: some View {
        Section(L10n.Localizable.EhSettingView.Section.Title.galleryTags) {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.tagsSortOrder,
                selection: editor.binding(\.tagsSortOrder, value),
                options: EhSetting.TagsSortOrder.allCases, name: \.localizedName
            )
        }
    }
}

struct PageLabelingSection: View, Equatable {
    let editor: EhSettingEditor
    let value: EhSetting.GalleryPageNumbering

    var body: some View {
        Section(L10n.Localizable.EhSettingView.Section.Title.galleryPageThumbnailLabeling) {
            OptionPicker(
                title: L10n.Localizable.EhSettingView.Title.showLabelBelowGalleryThumbnails,
                selection: editor.binding(\.galleryPageNumbering, value),
                options: EhSetting.GalleryPageNumbering.allCases, name: \.localizedName
            )
        }
    }
}

/// Only shown when the page offers the multi-page viewer (legacy showed it when all three
/// options were present).
struct MultiPageViewerSection: View, Equatable {
    let editor: EhSettingEditor
    let isOn: Bool?
    let style: EhSetting.MultiplePageViewerStyle?
    let showsPane: Bool?

    var body: some View {
        if let isOn = editor.binding(\.useMultiplePageViewer, isOn),
           let style = editor.binding(\.multiplePageViewerStyle, style),
           let showsPane = editor.binding(\.multiplePageViewerShowThumbnailPane, showsPane) {
            Section(L10n.Localizable.EhSettingView.Section.Title.multiPageViewer) {
                Toggle(L10n.Localizable.EhSettingView.Title.useMultiPageViewer, isOn: isOn)
                OptionPicker(
                    title: L10n.Localizable.EhSettingView.Title.displayStyle, selection: style,
                    options: EhSetting.MultiplePageViewerStyle.allCases, name: \.localizedName
                )
                Toggle(L10n.Localizable.EhSettingView.Title.showThumbnailPane, isOn: showsPane)
            }
        }
    }
}
