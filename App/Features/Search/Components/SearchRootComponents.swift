import EhFeatures
import EhModels
import SwiftUI

/// Quick-search words as chips that wrap like words; one tap searches the word. With no saved
/// words a single chip opens the form for the first one.
struct QuickSearchChips: View {
    let keywords: [SearchKeyword]
    let search: (String) -> Void
    let addWord: () -> Void

    var body: some View {
        FlowLayout(spacing: Tokens.Spacing.small, lineSpacing: 0) {
            if keywords.isEmpty {
                Button(action: addWord) {
                    Label(L10n.Localizable.QuickSearchView.Title.newWord, systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.textSecondary)
                        .modifier(KeywordChipShape(isDashed: true))
                }
                .buttonStyle(.plain)
            }
            ForEach(keywords, id: \.self) { keyword in
                Button { search(keyword.keyword) } label: {
                    KeywordChipLabel(keyword: keyword)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(keyword.title)
            }
        }
        .padding(.horizontal)
    }
}

/// A word's title; a leading namespace (`language:`) is drawn quieter than its value.
private struct KeywordChipLabel: View {
    let keyword: SearchKeyword

    var body: some View {
        Group {
            if let title = keyword.namespacedTitle {
                Text("\(Text(title.namespace).fontWeight(.medium).foregroundStyle(.textTertiary))\(Text(title.value))")
            } else {
                Text(keyword.title)
            }
        }
        .foregroundStyle(.textPrimary)
        .lineLimit(1)
        .modifier(KeywordChipShape(isDashed: false))
    }
}

/// A 32 pt rounded chip inside a 44 pt tap target.
private struct KeywordChipShape: ViewModifier {
    let isDashed: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
        content
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 11)
            .frame(minHeight: 32)
            .background {
                if isDashed {
                    shape.strokeBorder(.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                } else {
                    shape.fill(.chipFill)
                }
            }
            .padding(.vertical, 6)
            .contentShape(.rect)
    }
}

/// Recently searched keywords in rows (`SearchRootModel.keywordRows`), left to right, each with
/// a remove button.
struct KeywordRows: View {
    let rows: [[SearchKeyword]]
    let search: (String) -> Void
    let remove: (String) -> Void

    var body: some View {
        let columns = rows.first?.count ?? 0
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                GridRow {
                    ForEach(rows[index], id: \.self) { keyword in
                        KeywordRow(keyword: keyword, search: search, remove: remove)
                            .overlay(alignment: .top) {
                                if index > 0 {
                                    Rectangle().fill(.hairline).frame(height: 0.5)
                                }
                            }
                    }
                    // A short last row keeps its keyword in the first column's width.
                    if rows[index].count < columns {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
        .padding(.leading)
        .padding(.trailing, 6)
    }
}

private struct KeywordRow: View {
    let keyword: SearchKeyword
    let search: (String) -> Void
    let remove: (String) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 0) {
            Button {
                search(keyword.keyword)
            } label: {
                HStack(spacing: Tokens.Spacing.small) {
                    Image(systemName: "magnifyingglass")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.textTertiary)
                    Text(keyword.title)
                        .foregroundStyle(.textPrimary)
                        // In the one column of the accessibility sizes, long keywords wrap.
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(keyword.title)

            Button {
                remove(keyword.keyword)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Localizable.SearchView.Button.removeKeyword(keyword.title))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Recently opened galleries as a strip of covers with their titles (E-Search).
struct RecentGalleries: View {
    let galleries: [Gallery]
    let open: (Gallery) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: Tokens.Spacing.medium) {
                ForEach(galleries) { gallery in
                    Button { open(gallery) } label: {
                        RecentGalleryCell(gallery: RecentGalleryCell.Content(gallery))
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
    }
}

private struct RecentGalleryCell: View, Equatable {
    struct Content: Equatable {
        let title: String
        let coverURL: URL?

        init(_ gallery: Gallery) {
            title = gallery.trimmedTitle
            coverURL = gallery.coverURL
        }
    }

    let gallery: Content

    private static let coverSize = CGSize(width: 96, height: 96 / Tokens.Aspect.cover)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: gallery.coverURL, size: Self.coverSize, contentMode: .fill)
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.image, style: .continuous)
                        .strokeBorder(.coverEdge, lineWidth: 1)
                }
            Text(gallery.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.textPrimary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
        }
        .frame(width: Self.coverSize.width)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
