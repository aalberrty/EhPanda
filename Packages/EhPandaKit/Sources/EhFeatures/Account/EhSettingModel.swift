import Dependencies
import EhCore
import EhModels
import EhNetworking
import Foundation
import Observation

/// The site-side settings page (`uconfig.php`): loading, profile actions and submit.
@Observable public final class EhSettingModel {
    nonisolated public enum Destination: Hashable, Sendable, Identifiable {
        /// The settings page itself in a web view.
        case webView(URL)

        public var id: Self { self }
    }

    /// The form being edited. `nil` until the first load succeeds.
    public var setting: EhSetting?
    /// The profile the page reports as selected, or the first one when it reports none.
    public private(set) var selectedProfile: EhProfile?
    public var editingProfileName = ""
    public private(set) var loadingState: LoadingState = .idle
    public private(set) var submittingState: LoadingState = .idle
    public var destination: Destination?
    public var isConfirmingDeletion = false

    @ObservationIgnored @Dependency(\.ehClient) private var client
    @ObservationIgnored @Dependency(\.settings) private var settings
    @ObservationIgnored @Dependency(\.accountSession) private var session

    public init() {}

    public var galleryHost: GalleryHost { settings.galleryHost }

    /// The web view opens the page directly, which domain fronting cannot route.
    public var isWebViewAvailable: Bool { !settings.bypassesSNIFiltering }

    public var isSubmitDisabled: Bool { setting == nil || submittingState.isLoading }

    /// Loads the page unless it is already loaded (legacy loaded on first appear only).
    public func loadIfNeeded() async {
        guard setting == nil else { return }
        await load()
    }

    public func load() async {
        guard !loadingState.isLoading else { return }
        loadingState = .loading
        do {
            apply(try await client.ehSetting())
            loadingState = .idle
        } catch is CancellationError {
            loadingState = .idle
        } catch {
            loadingState = .failed(error as? AppError ?? .unknown)
        }
    }

    /// Posts every value; the server answers with the re-rendered form.
    public func submit() async {
        guard let setting else { return }
        await perform { try await $0.submitEhSetting(setting) }
    }

    // MARK: Profiles

    /// Switches the server-side profile; the page reloads with its values.
    public func selectProfile(_ value: Int) async {
        guard value != selectedProfile?.value else { return }
        await profileAction(nil, set: value)
    }

    public func setSelectedProfileAsDefault() async {
        guard let profile = selectedProfile, !profile.isDefault else { return }
        await profileAction(.default, set: profile.value)
    }

    public func deleteSelectedProfile() async {
        guard let profile = selectedProfile, !profile.isDefault else { return }
        await profileAction(.delete, set: profile.value)
    }

    public func renameSelectedProfile() async {
        guard let profile = selectedProfile else { return }
        await profileAction(.rename, name: editingProfileName, set: profile.value)
    }

    public func createProfile() async {
        guard let setting, setting.isCapableOfCreatingNewProfile else { return }
        await profileAction(.create, name: editingProfileName, set: selectedProfile?.value)
    }

    public func presentWebView() {
        guard isWebViewAvailable else { return }
        destination = .webView(galleryHost.url.appending(path: "uconfig.php"))
    }

    /// Leaving the screen: the app keeps browsing with its own profile whatever was selected
    /// here (legacy `setDefaultProfile` on disappear).
    public func restoreEhPandaProfile() {
        if let value = setting?.ehpandaProfile?.value {
            session.selectProfile(value)
        }
    }

    // MARK: Private

    private func profileAction(_ action: EhProfileAction?, name: String? = nil, set: Int?) async {
        await perform { try await $0.ehProfile(action: action, name: name, set: set) }
    }

    private func perform(_ operation: (EhClient) async throws -> EhSetting) async {
        guard !submittingState.isLoading else { return }
        submittingState = .loading
        do {
            apply(try await operation(client))
            submittingState = .idle
        } catch is CancellationError {
            submittingState = .idle
        } catch {
            submittingState = .failed(error as? AppError ?? .unknown)
        }
    }

    /// Legacy `setEhSetting`, without its force unwrap: a page with no selected profile
    /// falls back to the first one.
    func apply(_ setting: EhSetting) {
        let profile = setting.ehProfiles.first(where: \.isSelected) ?? setting.ehProfiles.first
        self.setting = setting
        selectedProfile = profile
        editingProfileName = profile?.name ?? ""
    }
}
