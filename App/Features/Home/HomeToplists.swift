import EhFeatures
import EhModels
import SwiftUI

/// One column per toplists period (legacy `ToplistsSection`). Compact widths show ranks 1–3;
/// regular widths add ranks 4–6 in a second sub-column.
struct HomeToplists: View {
    /// The galleries of each period, in `ToplistsType.allCases` order.
    let periods: [ToplistsPeriod]
    let open: (Gallery) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: Tokens.Spacing.xxLarge) {
                ForEach(periods) { period in
                    VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                        Text(period.type.localizedName)
                            .font(.subheadline.bold())
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

/// Ranked rows with dividers between them; placeholder rows while the period has no galleries.
private struct RankingStack: View {
    let galleries: [Gallery]
    let ranks: ClosedRange<Int>
    let open: (Gallery) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            if galleries.isEmpty {
                ForEach(ranks, id: \.self) { rank in
                    RankingRow(rank: rank, title: Self.placeholderText, uploader: Self.placeholderText, coverURL: nil)
                    if rank != ranks.upperBound { Divider() }
                }
                .accessibilityHidden(true)
            } else {
                let rows = HomeSections.ranking(galleries, ranks: ranks)
                ForEach(rows) { row in
                    Button { open(row.gallery) } label: {
                        RankingRow(
                            rank: row.rank, title: row.gallery.trimmedTitle,
                            uploader: row.gallery.uploader, coverURL: row.gallery.coverURL
                        )
                    }
                    .buttonStyle(.plain)
                    if row.id != rows.last?.id { Divider() }
                }
            }
        }
    }

    /// Legacy's placeholder title and uploader.
    private static let placeholderText = "......"
}

private struct RankingRow: View {
    let rank: Int
    let title: String
    let uploader: String?
    let coverURL: URL?

    private static let coverSize = CGSize(
        width: Tokens.ImageSize.row.width * 0.75, height: Tokens.ImageSize.row.height * 0.75
    )

    var body: some View {
        HStack(spacing: Tokens.Spacing.small) {
            RemoteImage(url: coverURL, size: Self.coverSize, contentMode: .fill, cropsWebtoon: true)
            Text(rank, format: .number)
                .font(.title2.weight(.medium))
                .monospacedDigit()
                .frame(minWidth: 36)
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                Text(title)
                    .bold()
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let uploader {
                    Text(uploader)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeToplists(
        periods: ToplistsType.allCases.map { ToplistsPeriod(type: $0, galleries: []) },
        open: { _ in }
    )
}
