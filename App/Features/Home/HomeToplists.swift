import EhFeatures
import EhModels
import SwiftUI

/// One column per toplists period, swiped sideways and snapping, each 70 % of the width so the
/// next one peeks in (legacy `ToplistsSection`, restyled in E-Toplists). Compact widths show
/// ranks 1–3; regular widths add ranks 4–6 in a second sub-column.
struct HomeToplists: View {
    /// The galleries of each period, in `ToplistsType.allCases` order.
    let periods: [ToplistsPeriod]
    let open: (Gallery) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 22) {
                ForEach(periods) { period in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(period.type.localizedName)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.textSecondary)
                            .padding(.bottom, Tokens.Spacing.xSmall)
                            .accessibilityAddTraits(.isHeader)
                        HStack(alignment: .top, spacing: Tokens.Spacing.xLarge) {
                            ForEach(rankRanges, id: \.lowerBound) { ranks in
                                RankingStack(galleries: period.galleries, ranks: ranks, open: open)
                                    // Legacy: 70% of the window wide, 40% per sub-column on iPad.
                                    .containerRelativeFrame(.horizontal) { [isRegular] length, _ in
                                        length * (isRegular ? 0.4 : 0.7)
                                    }
                            }
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, Tokens.Spacing.large, for: .scrollContent)
    }

    private var isRegular: Bool { sizeClass == .regular }

    private var rankRanges: [ClosedRange<Int>] {
        isRegular ? [1...3, 4...6] : [1...3]
    }
}

/// A period and its galleries, as the toplists section renders it.
struct ToplistsPeriod: Identifiable, Equatable {
    let type: ToplistsType
    let galleries: [Gallery]

    var id: ToplistsType { type }
}

/// Ranked rows with hairlines between them; placeholder rows while the period has no galleries.
private struct RankingStack: View {
    let galleries: [Gallery]
    let ranks: ClosedRange<Int>
    let open: (Gallery) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if galleries.isEmpty {
                ForEach(ranks, id: \.self) { rank in
                    RankingRow(rank: rank, title: Self.placeholderText, uploader: Self.placeholderText, coverURL: nil)
                    if rank != ranks.upperBound { RankingDivider() }
                }
                .accessibilityHidden(true)
            } else {
                let rows = HomeSections.ranking(galleries, ranks: ranks)
                ForEach(rows) { row in
                    Button { open(row.gallery) } label: {
                        RankingRow(
                            rank: row.rank, title: HomeSections.shortTitle(of: row.gallery),
                            uploader: row.gallery.uploader, coverURL: row.gallery.coverURL
                        )
                    }
                    .buttonStyle(.plain)
                    if row.id != rows.last?.id { RankingDivider() }
                }
            }
        }
    }

    /// Legacy's placeholder title and uploader.
    private static let placeholderText = "......"
}

/// Cover, rank in the serif heading face, then title and uploader (E-Toplists).
private struct RankingRow: View {
    let rank: Int
    let title: String
    let uploader: String?
    let coverURL: URL?

    var body: some View {
        HStack(spacing: RankingMetrics.spacing) {
            RemoteImage(
                url: coverURL, size: RankingMetrics.coverSize, contentMode: .fill,
                cornerRadius: RankingMetrics.coverRadius, cropsWebtoon: true
            )
            .overlay {
                RoundedRectangle(cornerRadius: RankingMetrics.coverRadius, style: .continuous)
                    .strokeBorder(.coverEdge, lineWidth: 1)
            }
            Text(rank, format: .number)
                .font(.heading(.title))
                .monospacedDigit()
                .foregroundStyle(.textPrimary)
                .frame(width: RankingMetrics.rankWidth)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let uploader {
                    Text(uploader)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: RankingMetrics.rowHeight)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// A hairline starting under the title, as drawn.
private struct RankingDivider: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(.hairline)
            .frame(height: 1 / displayScale)
            .padding(.leading, RankingMetrics.dividerInset)
    }
}

private enum RankingMetrics {
    static let coverSize = CGSize(width: 46, height: 63)
    static let coverRadius: CGFloat = 6
    static let rankWidth: CGFloat = 26
    static let spacing: CGFloat = 10
    static let rowHeight: CGFloat = 76
    static let dividerInset = coverSize.width + rankWidth + spacing * 2
}

#Preview {
    SchemePreview {
        HomeToplists(
            periods: ToplistsType.allCases.map { ToplistsPeriod(type: $0, galleries: []) },
            open: { _ in }
        )
    }
}
