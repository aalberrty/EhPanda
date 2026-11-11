import EhFeatures
import EhModels
import SwiftUI

/// Toplists by period, paged by number, with a jump-to-page prompt. Always loaded from
/// e-hentai.org, so the jump button shows on both hosts (legacy hid it on ExHentai).
struct ToplistsScreen: View {
    @State private var model = ToplistsModel()
    @State private var invalidJumps = 0

    var body: some View {
        PagedGalleryList(model: model.list)
            .searchable(text: $model.titleFilter, prompt: L10n.Localizable.Searchable.Prompt.filter)
            .navigationTitle(
                [L10n.Localizable.ToplistsView.Title.toplists, model.type.localizedName].joined(separator: " - ")
            )
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ToolbarPickerMenu(
                        L10n.Localizable.ToplistsView.Title.toplists, systemImage: "dial.low",
                        options: ToplistsType.allCases, selection: model.type,
                        optionTitle: { $0.localizedName }, onSelect: { model.select($0) }
                    )
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
