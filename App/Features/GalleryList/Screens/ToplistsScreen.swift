import EhFeatures
import EhModels
import SwiftUI

/// Toplists by period, paged by number, with a jump-to-page prompt. Always loaded from
/// e-hentai.org, so the jump button shows on both hosts (legacy hid it on ExHentai). The title
/// and the period chips are pinned above the list, like Library's title and folder chips.
struct ToplistsScreen: View {
    @State private var model = ToplistsModel()
    @State private var invalidJumps = 0

    var body: some View {
        // Each period is a list of its own, so its view is too: a list swapped into the previous
        // period's view opened rows down, under the bars, instead of at its top.
        ZStack {
            PagedGalleryList(model: model.list)
                .id(ObjectIdentifier(model.list))
        }
        .screenGround()
        .titledFloatingBar(L10n.Localizable.ToplistsView.Title.toplists, background: .materialUnderNavigationBar) {
            ToplistsPeriodChips(model: model)
        }
        .toolbarSearchable(
            text: $model.titleFilter, prompt: L10n.Localizable.Searchable.Prompt.filter, alwaysShowsField: true
        )
        .toolbar {
            ToolbarSearchItem()
            ToolbarItemGroup(placement: .primaryAction) {
                ListDisplayModeButton()
                JumpPageButton(isDisabled: !model.list.canJumpPage) { model.presentJumpPage() }
            }
        }
        .alert(L10n.Localizable.JumpPageView.Title.jumpPage, isPresented: $model.isJumpPagePresented) {
            TextField(text: $model.jumpPageText, prompt: Text(verbatim: "1")) { EmptyView() }
                .keyboardType(.numberPad)
            Button(L10n.Localizable.JumpPageView.Button.confirm) {
                if !model.confirmJumpPage() { invalidJumps += 1 }
            }
            .keyboardShortcut(.defaultAction)
            AlertCancelButton(title: L10n.Localizable.JumpPageView.Button.cancel)
        } message: {
            Text(verbatim: "1 – \(model.list.maximumPage)")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.isJumpPagePresented) { _, isShown in isShown }
        .sensoryFeedback(.error, trigger: invalidJumps)
    }
}

/// Yesterday, Past month, Past year and All time, replacing the period menu and subtitle.
private struct ToplistsPeriodChips: View {
    let model: ToplistsModel

    var body: some View {
        ChipRow(
            L10n.Localizable.ToplistsView.Title.toplists, options: ToplistsType.allCases,
            selection: model.type.id, optionTitle: { $0.localizedName }, onSelect: { model.select($0) }
        )
    }
}
