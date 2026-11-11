// swift-tools-version: 6.2

import PackageDescription

// Everything that is not a view lives in this package so it can be built and
// tested on the host with `swift test` (no simulator needed).
//
// Dependency direction (each target may only import the ones above it):
//
//   EhModels  →  EhParser  →  EhNetworking ┐
//            └→  EhDatabase ───────────────┴→  EhCore  →  EhFeatures
let package = Package(
    name: "EhPandaKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(
            name: "EhPandaKit",
            targets: ["EhModels", "EhParser", "EhNetworking", "EhDatabase", "EhCore", "EhFeatures"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.12.0"),
        .package(url: "https://github.com/tid-kijyun/Kanna", from: "6.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.2"),
        .package(url: "https://github.com/ddddxxx/SwiftyOpenCC", from: "2.0.0-beta")
    ],
    targets: [
        // Plain value types shared by every layer. No dependencies, no UI, no localization.
        .target(name: "EhModels"),
        .testTarget(name: "EhModelsTests", dependencies: ["EhModels", "EhTestSupport"]),

        // HTML / JSON responses → EhModels.
        .target(
            name: "EhParser",
            dependencies: ["EhModels", .product(name: "Kanna", package: "Kanna")]
        ),
        .testTarget(name: "EhParserTests", dependencies: ["EhParser", "EhTestSupport"]),

        // HTTP transport, cookies, URL building, domain fronting and the typed `EhClient`.
        .target(name: "EhNetworking", dependencies: ["EhModels", "EhParser"]),
        .testTarget(name: "EhNetworkingTests", dependencies: ["EhNetworking", "EhTestSupport"]),

        // SQLite persistence (GRDB): schema, migrations, queries, legacy Core Data import.
        .target(
            name: "EhDatabase",
            dependencies: ["EhModels", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(name: "EhDatabaseTests", dependencies: ["EhDatabase", "EhTestSupport"]),

        // Dependency keys, settings and UI-independent services built on the layers above.
        .target(
            name: "EhCore",
            dependencies: [
                "EhModels", "EhParser", "EhNetworking", "EhDatabase",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "OpenCC", package: "SwiftyOpenCC")
            ]
        ),
        .testTarget(name: "EhCoreTests", dependencies: ["EhCore", "EhTestSupport"]),

        // `@Observable` feature models that the SwiftUI views in the app target render.
        .target(
            name: "EhFeatures",
            dependencies: ["EhCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "EhFeaturesTests",
            dependencies: ["EhFeatures", "EhTestSupport"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        // Test-only helpers shared by the test targets: fixtures, a stub HTTP transport,
        // in-memory databases. Never linked into the app.
        .target(
            name: "EhTestSupport",
            dependencies: ["EhModels", "EhNetworking", "EhDatabase"],
            resources: [.copy("Fixtures")]
        )
    ]
)
