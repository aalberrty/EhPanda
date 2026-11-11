import EhModels
import Foundation
import Kanna

// Response handling that legacy kept inside its `Request` structs.

// MARK: Gallery detail

/// Everything legacy `GalleryDetailRequest` read from a detail page.
public struct GalleryDetailResponse: Sendable {
    public let detail: GalleryDetail
    public let state: GalleryState
    public let apiKey: String
    public let greeting: Greeting?

    /// The gallery's first preview page, which the detail page is: the thumbnails and the
    /// viewer links of the pages it lists.
    public var previewPage: PreviewPage {
        PreviewPage(previewURLs: state.previewURLs, pageURLs: state.thumbnailURLs)
    }
}

extension Parser {
    /// A detail page's gallery, state, API key and (if shown) daily greeting.
    /// Replaces legacy `GalleryDetailRequest`; create `doc` with `recoversInvalidUTF8: true`.
    public static func parseGalleryDetailResponse(doc: HTMLDocument, gid: String) throws -> GalleryDetailResponse {
        let (detail, state) = try parseGalleryDetail(doc: doc, gid: gid)
        let apiKey = try parseAPIKey(doc: doc)
        return GalleryDetailResponse(
            detail: detail, state: state, apiKey: apiKey, greeting: try? parseGreeting(doc: doc)
        )
    }

    /// The list entry for a gallery opened by URL (legacy `GalleryReverseRequest`), or
    /// `nil` when the page is not a parsable detail page.
    public static func parseGallery(doc: HTMLDocument, galleryURL: URL) -> Gallery? {
        let components = galleryURL.pathComponents
        guard components.count >= 4,
              let (detail, _) = try? parseGalleryDetail(doc: doc, gid: components[2])
        else { return nil }

        return Gallery(
            gid: components[2],
            token: components[3],
            title: detail.title,
            rating: detail.rating,
            tags: [],
            category: detail.category,
            uploader: detail.uploader,
            pageCount: detail.pageCount,
            postedDate: detail.postedDate,
            coverURL: detail.coverURL,
            galleryURL: galleryURL
        )
    }
}

// MARK: Archive

extension Parser {
    /// The archive options plus, when shown, the user's funds (legacy `GalleryArchiveRequest`).
    public static func parseGalleryArchiveResponse(
        doc: HTMLDocument
    ) throws -> (archive: GalleryArchive, galleryPoints: String?, credits: String?) {
        let archive = try parseGalleryArchive(doc: doc)
        guard let (galleryPoints, credits) = try? parseCurrentFunds(doc: doc)
        else { return (archive, nil, nil) }
        return (archive, galleryPoints, credits)
    }
}

// MARK: Image URL refetch

extension Parser {
    /// For legacy `GalleryNormalImageURLRefetchRequest`: from a single image page, the same
    /// page's URL with its skip-server identifier (`nl`) appended, and the image URL it showed.
    public static func parseRenewedThumbnailURL(
        doc: HTMLDocument, thumbnailURL: URL, index: Int
    ) throws -> (renewedThumbnailURL: URL, imageURL: URL) {
        let identifier = try parseSkipServerIdentifier(doc: doc)
        let imageURL = try parseGalleryNormalImageURL(doc: doc, index: index).1
        let renewedURL = thumbnailURL.appendingQueryItems([
            URLQueryItem(name: QueryKey.skipServerIdentifier, value: identifier)
        ])
        return (renewedURL, imageURL)
    }

    /// Picks the refetched image URL: the first page load's image unless it is the one that
    /// already failed (`storedImageURL`), in which case the reloaded page's image.
    public static func refetchedImageURL(first: URL, reloaded: URL, storedImageURL: URL) -> URL {
        first != storedImageURL ? first : reloaded
    }
}

// MARK: Tag translation

extension Parser {
    /// Reads `published_at` from a GitHub "latest release" response.
    ///
    /// - Throws: `AppError.noUpdates` unless it is later than `updatedDate`, `.parseFailed`
    ///   when the response has no readable date.
    public static func parseTagTranslatorReleaseDate(data: Data, updatedDate: Date) throws -> Date {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let postedDateString = dict["published_at"] as? String,
              let postedDate = try? parseDate(time: postedDateString, format: DateFormat.github)
        else { throw AppError.parseFailed }

        guard postedDate > updatedDate
        else { throw AppError.noUpdates }
        return postedDate
    }

    /// Decodes an EhTagTranslation `db.raw.json` into translations keyed as `TagTranslator`
    /// stores them. Legacy then converted them to Traditional Chinese for that language;
    /// that conversion (OpenCC) is left to the caller.
    public static func parseTagTranslations(data: Data) throws -> [String: TagTranslation] {
        guard let response = try? JSONDecoder().decode(EhTagTranslationDatabaseResponse.self, from: data)
        else { throw AppError.parseFailed }
        let translations = response.tagTranslations
        guard !translations.isEmpty else { throw AppError.parseFailed }
        return translations
    }
}
