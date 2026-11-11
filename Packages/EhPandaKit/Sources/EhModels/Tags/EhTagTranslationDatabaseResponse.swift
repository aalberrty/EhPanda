import Foundation

/// The `db.raw.json` release asset of the EhTagTranslation database.
public struct EhTagTranslationDatabaseResponse: Codable, Sendable {
    public let data: [Model]

    public init(data: [Model]) {
        self.data = data
    }

    /// Every translation keyed by namespace raw value + tag key, as `TagTranslator` stores them.
    public var tagTranslations: [String: TagTranslation] {
        .init(
            data.flatMap(\.tagTranslations).map { ($0.namespace.rawValue + $0.key, $0) },
            // Keys cannot collide in a well-formed database; keep the first if one does.
            uniquingKeysWith: { first, _ in first }
        )
    }
}

extension EhTagTranslationDatabaseResponse {
    public struct Item: Codable, Sendable {
        public let name: String
        public var intro: String?
        public var links: String?

        public init(name: String, intro: String? = nil, links: String? = nil) {
            self.name = name
            self.intro = intro
            self.links = links
        }
    }

    public struct Model: Codable, Sendable {
        public let namespace: String
        public let data: [String: Item]

        public init(namespace: String, data: [String: Item]) {
            self.namespace = namespace
            self.data = data
        }

        /// The entries of this namespace; empty when the namespace is not one the app knows.
        public var tagTranslations: [TagTranslation] {
            guard let namespace = TagNamespace(rawValue: namespace) else { return [] }
            return data.map {
                .init(namespace: namespace, key: $0, value: $1.name, description: $1.intro, linksString: $1.links)
            }
        }
    }
}
