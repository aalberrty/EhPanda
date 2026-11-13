import EhCore
import EhFeatures
import EhModels
import SwiftUI

/// Every field of the gallery; tapping a value copies it.
struct GalleryInfosScreen: View {
    @State private var model: GalleryInfosModel
    @State private var hud: HUDConfiguration?

    @Environment(SettingsStore.self) private var settings

    init(gallery: Gallery, detail: GalleryDetail) {
        _model = State(initialValue: GalleryInfosModel(gallery: gallery, detail: detail))
    }

    var body: some View {
        List(rows) { row in
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.small) {
                Text(row.title)
                    .foregroundStyle(.textPrimary)
                    .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in width / 3 }
                Spacer(minLength: 0)
                Button {
                    if let value = row.value { model.copy(value) }
                } label: {
                    if let category = row.category, let value = row.value {
                        // The category mark, in the values' tint like the rest of the column.
                        CategoryLabel(
                            value, color: category.color(for: settings.galleryHost), font: .caption,
                            foreground: settings.accentColor.appTint
                        )
                    } else {
                        Text(row.value ?? L10n.Localizable.GalleryInfosView.Value.none)
                            .font(.caption)
                            .lineLimit(3)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)
                .disabled(row.value == nil)
            }
            .listRowBackground(Color.raisedGrouped)
            .listRowSeparatorTint(.hairline)
        }
        .screenGround(.grouped)
        .navigationTitle(L10n.Localizable.GalleryInfosView.Title.galleryInfos)
        .hud($hud)
        .onChange(of: model.copyCount) { hud = .copiedToClipboard }
        .sensoryFeedback(.success, trigger: model.copyCount)
    }

    private var rows: [InfoRow] {
        typealias Title = L10n.Localizable.GalleryInfosView.Title
        let gallery = model.gallery
        let detail = model.detail
        let yes = L10n.Localizable.GalleryInfosView.Value.yes
        let no = L10n.Localizable.GalleryInfosView.Value.no
        return [
            InfoRow(Title.id, detail.gid),
            InfoRow(Title.token, gallery.token),
            InfoRow(Title.title, detail.title),
            InfoRow(Title.japaneseTitle, detail.jpnTitle),
            InfoRow(Title.galleryURL, gallery.galleryURL?.absoluteString),
            InfoRow(Title.coverURL, detail.coverURL?.absoluteString),
            InfoRow(Title.archiveURL, detail.archiveURL?.absoluteString),
            InfoRow(Title.torrentURL, model.torrentURL.absoluteString),
            InfoRow(Title.parentURL, detail.parentURL?.absoluteString),
            InfoRow(Title.category, detail.category.localizedName, category: detail.category),
            InfoRow(Title.uploader, detail.uploader),
            InfoRow(Title.postedDate, detail.formattedDateString),
            InfoRow(Title.visibility, detail.visibility.localizedName),
            InfoRow(Title.language, detail.language.localizedName),
            InfoRow(Title.pageCount, String(detail.pageCount)),
            InfoRow(Title.fileSize, detail.formattedSize),
            InfoRow(Title.favoritedTimes, String(detail.favoritedCount)),
            InfoRow(Title.favorited, detail.isFavorited ? yes : no),
            InfoRow(Title.ratingCount, String(detail.ratingCount)),
            // Legacy truncated these to integers; show the precision the site gives.
            InfoRow(Title.averageRating, detail.rating.formatted(.number.precision(.fractionLength(2)))),
            InfoRow(Title.myRating, detail.userRating == 0 ? nil : detail.userRating.formatted()),
            InfoRow(Title.torrentCount, String(detail.torrentCount))
        ]
    }
}

private struct InfoRow: Identifiable {
    let title: String
    let value: String?
    /// Set on the Category row, which shows the category mark.
    let category: Category?

    var id: String { title }

    init(_ title: String, _ value: String?, category: Category? = nil) {
        self.title = title
        self.value = value
        self.category = category
    }
}
