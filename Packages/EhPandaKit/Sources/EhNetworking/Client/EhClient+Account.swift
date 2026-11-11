import EhModels
import Foundation

extension EhClient {
    /// Signs in and stores the session cookies. Throws when the server did not accept the
    /// credentials.
    public func login(username: String, password: String) async throws {
        throw AppError.unknown
    }

    /// Requests exhentai.org once so the server issues the `igneous` cookie, and stores it.
    public func fetchIgneous() async throws {
        throw AppError.unknown
    }

    /// Whether the account has the app's own settings profile, and its index.
    public func verifyEhProfile() async throws -> VerifyEhProfileResponse {
        throw AppError.unknown
    }

    /// Performs a profile action (create, delete, rename, make default, select) and returns
    /// the resulting settings.
    public func ehProfile(
        action: EhProfileAction?, name: String? = nil, set: Int? = nil
    ) async throws -> EhSetting {
        throw AppError.unknown
    }

    public func ehSetting() async throws -> EhSetting {
        throw AppError.unknown
    }

    public func submitEhSetting(_ ehSetting: EhSetting) async throws -> EhSetting {
        throw AppError.unknown
    }

    /// Names of the account's ten favorites categories, by index.
    public func favoriteCategories() async throws -> [Int: String] {
        throw AppError.unknown
    }

    /// The daily "New Dawn" greeting from the news page.
    public func greeting() async throws -> Greeting {
        throw AppError.unknown
    }
}
