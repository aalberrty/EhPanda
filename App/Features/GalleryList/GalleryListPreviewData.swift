import EhCore
import EhModels
import Foundation

/// Sample galleries for the list's SwiftUI previews.
enum GalleryListPreviewData {
    static let galleries: [Gallery] = [
        gallery("1", "Morning Light Sketchbook", .artistCG, uploader: "kumo_archive", pages: 64, rating: 4.5),
        gallery("2", "Harbor Town Chronicle Vol. 2 [English] [Digital]", .manga, uploader: "harbor", pages: 212, rating: 4),
        gallery("3", "Paper Lantern Festival", .doujinshi, uploader: "lantern", pages: 28, rating: 3.5),
        gallery("4", "Cosmic Drift Concept Art", .imageSet, uploader: "drift", pages: 140, rating: 5),
        gallery("5", "Rainy Season Diary", .nonH, uploader: "rain", pages: 36, rating: 2.5),
        gallery("6", "Clockwork Garden Artbook", .misc, uploader: nil, pages: 88, rating: 4),
    ]

    private static func gallery(
        _ gid: String, _ title: String, _ category: EhModels.Category, uploader: String?, pages: Int, rating: Float
    ) -> Gallery {
        Gallery(
            gid: gid, token: "token", title: title, rating: rating,
            tags: [
                GalleryTag(rawNamespace: "language", contents: [content("language", "english")]),
                GalleryTag(rawNamespace: "artist", contents: [content("artist", "tsukimi")]),
                GalleryTag(rawNamespace: "other", contents: [content("other", "full color"), content("other", "artbook")]),
            ],
            category: category, uploader: uploader, pageCount: pages,
            postedDate: Date(timeIntervalSince1970: 1_794_500_000),
            coverURL: URL(string: "https://picsum.photos/id/\(10 + (Int(gid) ?? 0) * 7)/400/550"),
            galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token/")
        )
    }

    private static func content(_ namespace: String, _ text: String) -> GalleryTag.Content {
        GalleryTag.Content(rawNamespace: namespace, text: text, isVotedUp: false, isVotedDown: false, backgroundColor: nil)
    }

    @MainActor static var settings: SettingsStore { SettingsStore(defaults: .standard) }
}
