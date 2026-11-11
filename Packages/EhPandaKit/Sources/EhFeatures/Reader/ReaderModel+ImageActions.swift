import Foundation

// The context menu of a page (legacy `ReadingView` context menu and `ImageAction`).
extension ReaderModel {
    /// What the menu of a page offers: "Reload" always, the rest once the page has an image,
    /// "Save original" only when the site offers one.
    public func imageActions(for page: Int) -> [ReaderImageAction] {
        guard let image = resolver.image(of: page) else { return [.reload] }
        var actions: [ReaderImageAction] = [.reload, .copy, .save]
        if image.originalImageURL != nil {
            actions.append(.saveOriginal)
        }
        actions.append(.share)
        return actions
    }

    public func perform(_ action: ReaderImageAction, page: Int) {
        if action == .reload {
            failedImagePages.remove(page)
            staleCandidates.remove(page)
            resolver.refetch(page)
            return
        }
        guard let image = resolver.image(of: page),
              let url = action == .saveOriginal ? image.originalImageURL : image.imageURL
        else { return }
        lastActionID += 1
        let id = lastActionID
        actionTasks[id] = Task { [weak self] in
            await self?.run(action, url: url, page: page)
            self?.actionTasks[id] = nil
        }
    }

    /// Gets the image's original bytes (from the image cache, else downloaded) and hands them
    /// on untouched, so an animated GIF stays animated.
    private func run(_ action: ReaderImageAction, url: URL, page: Int) async {
        let data: Data
        do {
            data = try await imageCache.imageData(url)
        } catch {
            if !Task.isCancelled {
                notice = .error
            }
            return
        }
        guard !Task.isCancelled else { return }
        switch action {
        case .reload:
            break
        case .copy:
            await clipboard.copyImage(data)
            notice = .copiedToClipboard
        case .save, .saveOriginal:
            notice = await photoLibrary.saveImage(data) ? .savedToPhotoLibrary : .error
        case .share:
            do {
                let file = try await ReaderShareFile.write(data, gid: gallery.gid, page: page)
                removeSharedFile()
                sharedFile = file
                destination = .share(file)
            } catch {
                notice = .error
            }
        }
    }

    /// Deletes the file of the previous share.
    func removeSharedFile() {
        guard let file = sharedFile else { return }
        sharedFile = nil
        Task { await ReaderShareFile.remove(file) }
    }
}
