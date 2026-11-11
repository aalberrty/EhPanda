import EhCore
import EhDatabase
import EhFeatures
import EhModels
import SwiftUI

/// One row per tag namespace. Tapping a tag searches for it; its context menu offers the tag's
/// translation detail and, when logged in, votes.
struct DetailTagsSection: View {
    let model: GalleryDetailModel

    @Environment(SettingsStore.self) private var settings
    @Environment(StackRouter.self) private var stack: StackRouter?
    @State private var searchCount = 0

    var body: some View {
        if !model.tagRows.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                ForEach(model.tagRows) { row in
                    TagRowView(
                        row: row,
                        translates: settings.translatesTags,
                        translations: settings.translatesTags ? translations(of: row) : [:],
                        showsImages: settings.showsImagesInTags,
                        isLoggedIn: model.isLoggedIn,
                        actions: actions
                    )
                    .equatable()
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: searchCount)
        }
    }

    /// This row's translations, looked up synchronously; reading them observes the service.
    private func translations(of row: DetailTagRow) -> [String: TagTranslationDisplay] {
        row.chips.reduce(into: [:]) { result, chip in
            result[chip.translationKey] = model.translation(for: chip)
        }
    }

    private var actions: TagChipActions {
        TagChipActions(
            search: { keyword in
                searchCount += 1
                stack?.push(.search(keyword: keyword))
            },
            vote: { chip, vote in model.voteTag(chip, vote: vote) },
            showDetail: { detail in model.showTagDetail(detail) }
        )
    }
}

struct TagChipActions {
    let search: (String) -> Void
    let vote: (DetailTagChip, Int) -> Void
    let showDetail: (TagDetail) -> Void
}

private struct TagRowView: View, Equatable {
    let row: DetailTagRow
    let translates: Bool
    /// Empty when tags are not translated.
    let translations: [String: TagTranslationDisplay]
    let showsImages: Bool
    let isLoggedIn: Bool
    let actions: TagChipActions

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.row == rhs.row && lhs.translates == rhs.translates && lhs.translations == rhs.translations && lhs.showsImages == rhs.showsImages
            && lhs.isLoggedIn == rhs.isLoggedIn
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.small) {
            Text(row.tag.namespace?.localizedName ?? row.tag.rawNamespace)
                .font(.subheadline.bold())
                .foregroundStyle(Color(.systemBackground))
                .padding(TagChip.defaultPadding)
                .background(Color(.systemGray), in: .rect(cornerRadius: Tokens.Radius.chip, style: .continuous))
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: Tokens.Spacing.xSmall) {
                ForEach(row.chips) { chip in
                    chipButton(chip)
                }
            }
        }
    }

    private func chipButton(_ chip: DetailTagChip) -> some View {
        let translation = translations[chip.translationKey]
        return Button {
            actions.search(chip.searchKeyword)
        } label: {
            TagChip(
                chip.text(translation: translation, showsImages: showsImages),
                imageURL: showsImages ? translation?.valueImageURL : nil
            )
        }
        .buttonStyle(.plain)
        .contextMenu { menu(for: chip) }
    }

    /// Legacy offered "Detail" only while translating, for a tag whose translation has a description.
    @ViewBuilder
    private func menu(for chip: DetailTagChip) -> some View {
        if translates, let detail = chip.detail {
            Button(L10n.Localizable.DetailView.ContextMenu.Button.detail, systemImage: "doc.richtext") {
                actions.showDetail(detail)
            }
        }
        if isLoggedIn {
            if chip.hasVote {
                Button {
                    actions.vote(chip, chip.withdrawVote)
                } label: {
                    Label(
                        L10n.Localizable.DetailView.ContextMenu.Button.withdrawVote,
                        systemImage: chip.content.isVotedUp ? "hand.thumbsup.fill" : "hand.thumbsdown.fill"
                    )
                }
            } else {
                Button(L10n.Localizable.DetailView.ContextMenu.Button.voteUp, systemImage: "hand.thumbsup") {
                    actions.vote(chip, 1)
                }
                Button(L10n.Localizable.DetailView.ContextMenu.Button.voteDown, systemImage: "hand.thumbsdown") {
                    actions.vote(chip, -1)
                }
            }
        }
    }
}
