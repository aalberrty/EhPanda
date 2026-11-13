import EhCore
import EhDatabase
import EhFeatures
import EhModels
import SwiftUI

/// Every tag in one flow on a glass panel, each namespace named once in front of its chips
/// (E-Detail). Tapping a tag searches for it; its context menu offers the tag's translation
/// detail and, when logged in, votes.
///
/// At accessibility sizes a name and a chip no longer fit side by side, so each namespace's
/// name goes on a line of its own above its chips.
struct DetailTagsSection: View {
    let model: GalleryDetailModel

    @Environment(SettingsStore.self) private var settings
    @Environment(StackRouter.self) private var stack: StackRouter?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchCount = 0

    var body: some View {
        if !model.tagRows.isEmpty {
            // Read once here rather than per chip.
            let options = ItemOptions(translates: settings.translatesTags, showsImages: settings.showsImagesInTags)
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    namespaceStack(options)
                } else {
                    flow(options)
                }
            }
            .padding(DetailMetrics.panelInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel()
            .sensoryFeedback(.impact(flexibility: .soft), trigger: searchCount)
        }
    }

    private func flow(_ options: ItemOptions) -> some View {
        FlowLayout(spacing: Self.chipSpacing, lineSpacing: Self.lineSpacing) {
            ForEach(model.tagRows) { row in
                ForEach(row.chips) { chip in
                    item(
                        chip, options: options,
                        namespace: chip.id == row.chips.first?.id ? namespaceName(of: row) : nil,
                        // The last chip of a namespace keeps the wider gap to the next one.
                        trailingGap: chip.id == row.chips.last?.id ? Self.namespaceSpacing - Self.chipSpacing : 0
                    )
                }
            }
        }
    }

    private func namespaceStack(_ options: ItemOptions) -> some View {
        VStack(alignment: .leading, spacing: Self.namespaceSpacing) {
            ForEach(model.tagRows) { row in
                VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
                    NamespaceName(name: namespaceName(of: row))
                    FlowLayout(spacing: Self.chipSpacing, lineSpacing: Self.lineSpacing) {
                        ForEach(row.chips) { chip in
                            item(chip, options: options, namespace: nil, trailingGap: 0)
                        }
                    }
                }
            }
        }
    }

    private func item(
        _ chip: DetailTagChip, options: ItemOptions, namespace: String?, trailingGap: CGFloat
    ) -> some View {
        TagFlowItem(
            namespace: namespace,
            chip: chip,
            translation: options.translates ? model.translation(for: chip) : nil,
            translates: options.translates,
            showsImages: options.showsImages,
            isLoggedIn: model.isLoggedIn,
            trailingGap: trailingGap,
            actions: actions
        )
        .equatable()
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
    private static let lineSpacing: CGFloat = Tokens.Spacing.small + Tokens.Spacing.xxSmall

    private struct ItemOptions {
        let translates: Bool
        let showsImages: Bool
    }
}

/// A namespace's name in front of (or, at accessibility sizes, above) its chips.
private struct NamespaceName: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption)
            .foregroundStyle(.textTertiary)
            .accessibilityAddTraits(.isHeader)
    }
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
                NamespaceName(name: namespace)
                    .fixedSize()
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
