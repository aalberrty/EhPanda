import EhModels
import EhNetworking
import Foundation

// The requests behind each step. A request is built from the resolver's state when it starts
// and captures only values, so it runs off the main actor without touching the resolver.
extension ReaderPageResolver {
    typealias Work = @Sendable () async throws -> Output

    func work(for job: Job) -> Work {
        let client = client
        switch job {
        case .links(let previewPage):
            let galleryURL = galleryURL
            return {
                guard let galleryURL else { throw AppError.notFound }
                return .links(try await client.pageLinks(galleryURL: galleryURL, pageNumber: previewPage))
            }
        case .mpvKeys:
            let mpvURL = mpvURL
            return {
                guard let mpvURL else { throw AppError.notFound }
                return .mpvKeys(try await client.mpvKeys(mpvURL: mpvURL))
            }
        case .page(let page):
            return imageWork(for: page)
        }
    }

    /// The image of one page: from the `imagedispatch` API once the gallery's multi-page
    /// viewer keys are known, from the page's viewer page otherwise. A refetch asks for
    /// another image server, in either flow the way legacy did.
    private func imageWork(for page: Int) -> Work {
        let client = client
        let isRefetch = status(of: page) == .refetching
        if let keys = mpvKeys {
            guard let imageKey = keys.imageKeys[page] else { return { throw AppError.notFound } }
            let gid = gid
            // Legacy sent the identifier of the page's last dispatch only when reloading.
            let identifier = isRefetch ? skipServerIdentifiers[page] : nil
            return {
                let result = try await client.mpvPageImage(
                    gid: gid, index: page, mpvKey: keys.mpvKey, imageKey: imageKey,
                    skipServerIdentifier: identifier
                )
                return .image(result.image, skipServerIdentifier: result.skipServerIdentifier)
            }
        }
        guard let link = links[page] else { return { throw AppError.notFound } }
        if isRefetch, let galleryURL, let storedImageURL = images[page]?.imageURL {
            let previewPage = paging.previewPage(for: page)
            return {
                let image = try await client.refetchPageImage(
                    index: page, pageNumber: previewPage, galleryURL: galleryURL,
                    pageLink: link, storedImageURL: storedImageURL
                )
                return .image(image, skipServerIdentifier: nil)
            }
        }
        return { .image(try await client.pageImage(pageLink: link, index: page), skipServerIdentifier: nil) }
    }
}
