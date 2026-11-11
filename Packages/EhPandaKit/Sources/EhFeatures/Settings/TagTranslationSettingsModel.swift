import Dependencies
import EhCore
import EhModels
import Foundation
import Observation

/// The Tags section of Settings › General: the tags extension, its download and custom
/// translation files. The translation toggles bind to `SettingsStore` directly.
@Observable
public final class TagTranslationSettingsModel {
    /// A picked file that could not be read; the service reports every other failure.
    public private(set) var fileReadFailed = false

    @ObservationIgnored @Dependency(\.tagTranslationService) private var service
    @ObservationIgnored @Dependency(\.settings) private var settings

    public init() {}

    public var isLoading: Bool { service.loadingState == .loading }
    public var hasCustomTranslations: Bool { service.hasCustomTranslations }

    /// The translate / suggestions / images toggles only appear once there is something to
    /// translate with (legacy).
    public var showsTranslationOptions: Bool { settings.enablesTagsExtension && !service.isEmpty }

    /// Legacy's yellow warning: translation is on but nothing is downloaded.
    public var showsEmptyWarning: Bool { settings.translatesTags && service.isEmpty && !isLoading }

    /// The last download or import failure worth showing. "No updates" is not a failure here.
    public var failure: AppError? {
        if fileReadFailed { return .parseFailed }
        guard case .failed(let error) = service.loadingState else { return nil }
        return switch error {
        case .noUpdates: nil
        case .parseFailed: .parseFailed
        case .networkingFailed: .networkingFailed
        case .databaseFailed: .unknown
        }
    }

    /// Reads the stored translations, so the toggles show without waiting for a download.
    public func onAppear() async {
        await service.load()
    }

    /// Turning the extension on downloads the translations for the user's language;
    /// `SettingsStore` turns the dependent options off with it.
    public func setEnablesTagsExtension(_ isOn: Bool) async {
        settings.enablesTagsExtension = isOn
        guard isOn else { return }
        fileReadFailed = false
        await service.fetchUpdates()
    }

    /// Replaces the translations with a picked `db.raw.json`; downloads stop until removed.
    public func importCustomTranslations(from url: URL) async {
        fileReadFailed = false
        guard let data = await Self.readFile(at: url) else {
            fileReadFailed = true
            return
        }
        await service.importCustomTranslations(from: data)
    }

    public func removeCustomTranslations() async {
        fileReadFailed = false
        await service.removeCustomTranslations()
    }

    /// Files from the document picker are security-scoped.
    @concurrent
    nonisolated static func readFile(at url: URL) async -> Data? {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }
}
