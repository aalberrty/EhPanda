import EhCore
import EhDatabase
import EhFeatures
import EhModels
import SwiftUI

/// Every tag in one flow on a glass panel, each namespace named once in front of its chips
/// (E-Detail). Tapping a tag searches for it; its context menu offers the tag's translation
/// detail and, when logged in, votes.
struct DetailTagsSection: View {
    let model: GalleryDetailModel

    @Environment(SettingsStore.self) private var settings
    @Environment(StackRouter.self) private var stack: StackRouter?
    @State private var searchCount = 0

    var body: some View {
        if !model.tagRows.isEmpty {
            let translates = settings.translatesTags
            let showsImages = settings.showsImagesInTags
            FlowLayout(spacing: Self.chipSpacing, lineSpacing: Tokens.Spacing.small + Tokens.Spacing.xxSmall) {
                ForEach(model.tagRows) { row in
                    ForEach(row.chips) { chip in
                        TagFlowItem(
                            namespace: chip.id == row.chips.first?.id ? namespaceName(of: row) : nil,
                            chip: chip,
                            translation: translates ? model.translation(for: chip) : nil,
                            translates: translates,
                            showsImages: showsImages,
                            isLoggedIn: model.isLoggedIn,
                            // The last chip of a namespace keeps the wider gap to the next one.
                            trailingGap: chip.id == row.chips.last?.id ? Self.namespaceSpacing - Self.chipSpacing : 0,
                            actions: actions
                        )
                        .equatable()
                    }
                }
            }
            .padding(DetailMetrics.panelInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel()
            .sensoryFeedback(.impact(flexibility: .soft), trigger: searchCount)
        }
    }

    private func namespaceName(of row: DetailTagRow) -> String {
        row.tag.namespace?.localizedName ?? row.tag.rawNamespace
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

    private static let chipSpacing: CGFloat = 6
    private static let namespaceSpacing: CGFloat = 14
}

struct TagChipActions {
    let search: (String) -> Void
    let vote: (DetailTagChip, Int) -> Void
    let showDetail: (TagDetail) -> Void
}

/// One chip of the flow; the first chip of a namespace carries the namespace's name in front,
/// so the name never ends a line on its own.
private struct TagFlowItem: View, Equatable {
    let namespace: String?
    let chip: DetailTagChip
    let translation: TagTranslationDisplay?
    let translates: Bool
    let showsImages: Bool
    let isLoggedIn: Bool
    let trailingGap: CGFloat
    let actions: TagChipActions

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.namespace == rhs.namespace && lhs.chip == rhs.chip && lhs.translation == rhs.translation
            && lhs.translates == rhs.translates && lhs.showsImages == rhs.showsImages
            && lhs.isLoggedIn == rhs.isLoggedIn && lhs.trailingGap == rhs.trailingGap
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.small - Tokens.Spacing.xxSmall) {
            if let namespace {
                // Fixed, so the stack gives the chip all the rest: otherwise a chip with an image
                // can be offered only half the width and truncate beside a short name.
                Text(namespace)
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
                    .fixedSize()
                    .accessibilityAddTraits(.isHeader)
            }
            chipButton
        }
        .padding(.trailing, trailingGap)
    }

    private var chipButton: some View {
        Button {
            actions.search(chip.searchKeyword)
        } label: {
            TagChip(
                chip.content.chipText(translation: translation, showsImages: showsImages),
                imageURL: showsImages ? translation?.valueImageURL : nil,
                font: .subheadline,
                padding: Self.chipPadding,
                foreground: .textPrimary,
                background: .chipFill
            )
        }
        .buttonStyle(.plain)
        .contextMenu { menu }
    }

    /// Legacy offered "Detail" only while translating, for a tag whose translation has a description.
    @ViewBuilder
    private var menu: some View {
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

    /// E-Detail's 32 pt chips.
    private static let chipPadding = EdgeInsets(top: 6, leading: 11, bottom: 6, trailing: 11)
}
