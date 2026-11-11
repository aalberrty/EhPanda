import EhModels
import EhNetworking
import Foundation

// What the resolver does with the answer to a request.
extension ReaderPageResolver {
    func handle(_ result: Result<Output, any Error>, of job: Job) {
        switch result {
        case .success(.previewPage(let listed)):
            if case .links(let previewPage) = job {
                previewPageDidLoad(listed, previewPage: previewPage)
            }
        case .success(.mpvKeys(let keys)):
            mpvKeysDidLoad(keys)
        case .success(.image(let image, let identifier)):
            imageDidLoad(image, skipServerIdentifier: identifier)
        case .failure(let error):
            if let error = error as? AppError {
                fail(job, with: error)
            }
            // Anything else is a cancellation: the pages stay as they are.
        }
    }

    /// Takes over the viewer links of a preview page somebody else fetched (the slider reads
    /// preview pages for their thumbnails), so the pages it lists need no request for them.
    func adopt(_ listed: PreviewPage, previewPage: Int) {
        take(listed, previewPage: previewPage)
        schedulePump()
    }

    /// Whether the page size was corrected, or `nil` for a gallery that opens in the
    /// multi-page viewer.
    @discardableResult
    private func take(_ listed: PreviewPage, previewPage: Int) -> Bool? {
        let job = Job.links(previewPage: previewPage)
        let found = listed.pageURLs
        if let mpvLink = found.keys.sorted().lazy.compactMap({ found[$0] }).first(where: { EhURL.isMPVURL($0) }) {
            // The gallery opens in the multi-page viewer: no viewer pages, the keys are next.
            mpvURL = mpvLink
            recoverPages(failedBy: job)
            return nil
        }
        let learned = paging.learn(listed: listed.indices, onPreviewPage: previewPage, pageCount: pageCount)
        links.merge(found) { _, new in new }
        recoverPages(failedBy: job)
        return learned
    }

    /// The answer to the resolver's own request for a preview page.
    private func previewPageDidLoad(_ listed: PreviewPage, previewPage: Int) {
        let job = Job.links(previewPage: previewPage)
        let waiting = pages(waitingFor: job)
        guard let learned = take(listed, previewPage: previewPage) else { return }
        for page in waiting where links[page] == nil {
            // Not listed. If the page size turned out different, the page is on another
            // preview page and stays in the queue; otherwise it does not exist (legacy:
            // "not found" for an empty list).
            if !learned || paging.previewPage(for: page) == previewPage {
                setFailed(page, .notFound, waitingFor: job)
            }
        }
    }

    private func mpvKeysDidLoad(_ keys: MPVKeys) {
        // Legacy: the keys must cover the gallery, else "not found".
        guard keys.imageKeys.count == pageCount else {
            fail(.mpvKeys, with: .notFound)
            return
        }
        mpvKeys = keys
        eager = Array(1...min(3, max(pageCount, 1)))
        recoverPages(failedBy: .mpvKeys)
    }

    private func imageDidLoad(_ image: PageImage, skipServerIdentifier: String?) {
        var image = image
        if image.originalImageURL == nil {
            // A refetched page keeps the original it had (legacy merged with an empty list).
            image.originalImageURL = images[image.index]?.originalImageURL
        }
        images[image.index] = image
        statuses[image.index] = .resolved
        if let skipServerIdentifier {
            skipServerIdentifiers[image.index] = skipServerIdentifier
        }
        eager.removeAll { $0 == image.index }
        onEvent?(.resolved(image))
    }

    private func fail(_ job: Job, with error: AppError) {
        switch job {
        case .page(let page):
            eager.removeAll { $0 == page }
            setFailed(page, error, waitingFor: nil)
        case .links, .mpvKeys:
            // Only the pages that were waiting fail. The others ask again when their turn comes.
            for page in pages(waitingFor: job) {
                setFailed(page, error, waitingFor: job)
            }
        }
    }

    private func setFailed(_ page: Int, _ error: AppError, waitingFor job: Job?) {
        statuses[page] = .failed(error, waitingFor: job)
        onEvent?(.failed(page: page, error: error))
    }

    /// A shared request that failed earlier has now succeeded (after a retry of one of its
    /// pages): the other pages it failed recover with it.
    private func recoverPages(failedBy job: Job) {
        for (page, status) in statuses {
            guard case .failed(_, let failedJob) = status, failedJob == job else { continue }
            statuses[page] = images[page] == nil ? .unresolved : .refetching
            onEvent?(.updated(page: page))
        }
    }
}
