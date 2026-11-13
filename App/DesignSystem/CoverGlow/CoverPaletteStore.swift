import CoreGraphics
import EhCore
import EhModels
import Kingfisher
import Observation
import SwiftUI

/// The cover palettes of the galleries the app has shown, keyed by gallery id, shared by every
/// screen through the environment (`AppShellView` injects one), so Detail reuses the palette
/// Home already made for a Popular card.
///
/// A palette is extracted once per gallery: a gallery keeps its cover. Reading a palette
/// observes that gallery's entry only, so a palette arriving for one gallery does not redraw
/// views showing another.
@Observable
final class CoverPaletteStore {
    /// Plenty for a session; the oldest entries go first beyond it.
    private static let capacity = 400

    @ObservationIgnored private var entries: [String: CoverPaletteEntry] = [:]
    @ObservationIgnored private var insertionOrder: [String] = []

    /// The palette of `galleryID`, or `nil` until `load` has made it.
    func palette(for galleryID: String) -> CoverPalette? {
        entry(for: galleryID).palette
    }

    /// Extracts the palette of `gallery`'s cover unless it is known or already being extracted.
    func load(_ gallery: Gallery) async {
        await load(galleryID: gallery.id, coverURL: gallery.coverURL)
    }

    /// Extracts the palette of the cover at `coverURL` for `galleryID`, unless it is known or
    /// already being extracted. Call it from a view's `.task`, so the view going away cancels it;
    /// a cancelled or failed extraction is tried again by the next call.
    func load(galleryID: String, coverURL: URL?) async {
        guard let coverURL else { return }
        let entry = entry(for: galleryID)
        guard entry.palette == nil, !entry.isLoading else { return }
        entry.isLoading = true
        defer { entry.isLoading = false }
        guard let palette = await CoverPaletteLoader.palette(for: coverURL) else { return }
        entry.palette = palette
    }

    private func entry(for galleryID: String) -> CoverPaletteEntry {
        if let entry = entries[galleryID] { return entry }
        let entry = CoverPaletteEntry()
        entries[galleryID] = entry
        insertionOrder.append(galleryID)
        if insertionOrder.count > Self.capacity {
            let evicted = insertionOrder.removeFirst()
            entries[evicted] = nil
        }
        return entry
    }
}

/// One gallery's palette. Its own observable object, so readers observe only this gallery.
@Observable
private final class CoverPaletteEntry {
    var palette: CoverPalette?
    @ObservationIgnored var isLoading = false
}

/// Decodes a cover thumbnail with Kingfisher and analyses it, all off the main actor.
nonisolated enum CoverPaletteLoader {
    static func palette(for url: URL) async -> CoverPalette? {
        // Kingfisher reuses the original the cover view downloaded (or joins its download) and
        // decodes it straight to the thumbnail on its own queue; only the thumbnail is cached.
        let options: KingfisherOptionsInfo = [
            .processor(DownsampleProcessor(pixelSize: CoverPaletteExtractor.samplePixelSize, mode: .fill)),
            .cacheOriginalImage,
            .cacheMemoryOnly,
            .scaleFactor(1)
        ]
        guard let result = try? await KingfisherManager.shared.retrieveImage(with: url, options: options),
              !Task.isCancelled,
              let image = result.image.cgImage
        else { return nil }
        return await analyze(image)
    }

    @concurrent
    private static func analyze(_ image: CGImage) async -> CoverPalette? {
        CoverPaletteExtractor.palette(of: image)
    }
}

extension CoverPalette.RGB {
    nonisolated var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}
