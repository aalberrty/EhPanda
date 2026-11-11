import EhModels
import EhParser
import Foundation

extension EhClient {
    /// Signs in and stores the session cookies. Throws when the server did not accept the
    /// credentials.
    ///
    /// The forum answers with a page either way; legacy decided success by whether the cookie
    /// jar held a complete login afterwards (`didLogin`), and so does this, after storing the
    /// response's credentials (responses served through domain fronting skip the session's
    /// own cookie handling). A rejected login throws `AppError.unknown`, as legacy reported it.
    public func login(username: String, password: String) async throws {
        try await perform { builder in
            let response = try await send(builder.login(username: username, password: password))
            cookies.setCredentials(response: response.response)
            guard cookies.didLogin else { throw AppError.unknown }
        }
    }

    /// Requests exhentai.org once so the server issues the `igneous` cookie, and stores it.
    public func fetchIgneous() async throws {
        try await perform { builder in
            let response = try await send(builder.igneous())
            cookies.setCredentials(response: response.response)
        }
    }

    /// Whether the account has the app's own settings profile, and its index.
    public func verifyEhProfile() async throws -> VerifyEhProfileResponse {
        try await perform { builder in
            let data = try await body(builder.verifyEhProfile())
            let document = try Parser.htmlDocument(data: data)
            return try Parser.parseProfileIndex(doc: document)
        }
    }

    /// Performs a profile action (create, delete, rename, make default, select) and returns
    /// the resulting settings.
    public func ehProfile(
        action: EhProfileAction?, name: String? = nil, set: Int? = nil
    ) async throws -> EhSetting {
        try await perform { builder in
            try await ehSetting(builder.ehProfile(action: action, name: name, set: set))
        }
    }

    public func ehSetting() async throws -> EhSetting {
        try await perform { builder in
            try await ehSetting(builder.ehSetting())
        }
    }

    public func submitEhSetting(_ ehSetting: EhSetting) async throws -> EhSetting {
        try await perform { builder in
            try await self.ehSetting(builder.submitEhSettingChanges(ehSetting))
        }
    }

    /// Names of the account's ten favorites categories, by index.
    public func favoriteCategories() async throws -> [Int: String] {
        try await perform { builder in
            let data = try await body(builder.favoriteCategories())
            let document = try Parser.htmlDocument(data: data)
            return try Parser.parseFavoriteCategories(doc: document)
        }
    }

    /// The daily "New Dawn" greeting from the news page.
    public func greeting() async throws -> Greeting {
        try await perform { builder in
            let data = try await body(builder.greeting())
            let document = try Parser.htmlDocument(data: data)
            return try Parser.parseGreeting(doc: document)
        }
    }
}

private extension EhClient {
    /// The settings page that `uconfig.php` answers every GET and POST with.
    func ehSetting(_ request: URLRequest) async throws -> EhSetting {
        let data = try await body(request)
        let document = try Parser.htmlDocument(data: data)
        return try Parser.parseEhSetting(doc: document)
    }
}
