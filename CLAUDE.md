# EhPanda v2

EhPanda is an unofficial E-Hentai client for iOS / iPadOS 26. Branch `v2` is a ground-up rebuild.
The previous app lives in `Legacy/` **for reference only**: it is not built, must not be imported,
and is deleted once v2 reaches parity.

## Goals, in priority order

1. **Performance.** Smooth scrolling and reading, fast launch, nothing heavy on the main thread.
2. **Modern UI.** Native iOS 26 APIs and Liquid Glass; no third-party UI kits.
3. **Maintainability.** Small files, clear module boundaries, logic covered by host tests.

Scope is **feature parity with `Legacy/` first**. Do not add features the old app does not have.
When behaviour is unclear, read the matching code in `Legacy/` and keep its behaviour.

## Layout

```
App/                      App target (SwiftUI + UIKit views only). Folder is synchronized with
                          Xcode: adding or removing files needs no project edits.
  Features/<Name>/        Views for one feature
  DesignSystem/           Shared components, styles, layout helpers
  Platform/               iOS-only services (haptics, clipboard, photos, biometrics, image cache)
  Generated/Strings.swift SwiftGen output for `App/Resources/*.lproj` (the `L10n` enum)
  Resources/              Asset catalog, alternate icons, localized strings
Configuration/            Info.plists and entitlements
ShareExtension/           Share extension target
Packages/EhPandaKit/      Everything that is not a view (see below)
Legacy/                   Old app, reference only
```

### `Packages/EhPandaKit` targets

Each target may import only the targets to its left.

```
EhModels → EhParser → EhNetworking ┐
        └→ EhDatabase ─────────────┴→ EhCore → EhFeatures
```

| Target | Contents |
|---|---|
| `EhModels` | Plain value types. No dependencies, no UI types, no localized strings. |
| `EhParser` | HTML / JSON → `EhModels` (Kanna). |
| `EhNetworking` | `HTTPTransport`, retry, cookies, URL building, domain fronting, typed `EhClient`. |
| `EhDatabase` | GRDB schema, migrations, queries, one-time import of the legacy Core Data store. |
| `EhCore` | Dependency keys, `SettingsStore`, UI-independent services. |
| `EhFeatures` | `@Observable` feature models (default isolation: `MainActor`). |
| `EhTestSupport` | Test-only helpers and fixtures shared by the test targets. |

The package supports macOS so that all of it builds and tests on the host without a simulator.
Never import SwiftUI, UIKit or Kingfisher in the package.

## Architecture rules

- **No TCA, no Combine** in new code. Use `async`/`await`, `AsyncSequence` and Observation.
- **State:** one `@Observable final class <Name>Model` per screen in `EhFeatures/<Name>/`; its view is
  `App/Features/<Name>/<Name>View.swift`. Views contain layout only; decisions live in the model.
- **Dependencies:** `swift-dependencies`. Models read services with
  `@ObservationIgnored @Dependency(\.ehClient) private var client`. Keys are declared in `EhCore`;
  iOS-only live values are registered from `App/Platform`.
- **Networking:** every request goes through `EhClient`, which sits on an `HTTPTransport`. Tests stub the
  transport with fixture HTML rather than mocking individual endpoints.
- **Persistence:** GRDB through `AppDatabase` async methods only. Preferences live in `UserDefaults`
  behind `SettingsStore`. No Core Data.
- **Models are pure:** user-facing text, colours and symbols for a model type are extensions in the
  app target, never in the package.
- **Localization:** app target only, through `L10n.…` (`App/Generated/Strings.swift`). Reuse existing
  keys; a new key must be added to every `App/Resources/*.lproj/Localizable.strings` and to `Strings.swift`.
- **Images:** Kingfisher 8, app target only.
- **Navigation:** `NavigationStack` with typed, `Hashable` route enums. No `NavigationView`.
- **Logging:** `AppLogger` (os.Logger plus a file sink). Never log per action, per frame or per cell.

## Performance rules

These are requirements, not suggestions.

1. No I/O, parsing, JSON coding or image decoding on the main actor.
2. A view reads only what it renders. List cells take small `Equatable` values or read individual
   `@Observable` properties; never hand a cell a whole settings object, a dictionary of all rows,
   or a model it does not need.
3. Scrolling content is lazy (`List`, `LazyVStack`, `LazyVGrid`, `UICollectionView`) with stable
   identities. No `.id()` resets, no `GeometryReader` or `AnyView` inside cells.
4. Images are downsampled to their display size and their loads are cancelled when cells go away.
5. Database writes are batched in a single transaction; never one write per item in a loop.
6. Network work is cancellable end to end and fan-out is bounded (task groups with a limit).
7. Nothing reads window or screen size from globals. Use size classes, `containerRelativeFrame`,
   `onGeometryChange` or the view's own bounds.

## Swift conventions

- Swift 6 language mode everywhere; no `@unchecked Sendable` or `nonisolated(unsafe)` without a
  comment explaining why it is safe.
- The app target defaults to `MainActor` isolation and has approachable concurrency on, so a
  `nonisolated` async function there still runs on the caller's actor. Mark CPU-heavy work `@concurrent`.
  Package targets other than `EhFeatures` are nonisolated by default.
- No force unwraps or `try!` outside tests and static constants that cannot fail.
- Keep files under ~400 lines and functions under ~60; split by responsibility, not by line count.
- `public` only for what another target needs. Prefer `struct` and `enum`; `final class` for models.
- Comments explain why, not what. No file-header boilerplate.
- Tests use Swift Testing (`import Testing`). Every parser function, database query and model state
  transition added to the package gets a test.

## Commands

`xcode-select` may point at the Command Line Tools, so set the toolchain explicitly:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Package (fast, host only)
swift build --package-path Packages/EhPandaKit --target EhModels
swift test  --package-path Packages/EhPandaKit --filter EhParserTests
swift test  --package-path Packages/EhPandaKit

# App
xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda \
  -destination 'platform=iOS Simulator,name=iPhone 17' -skipMacroValidation -quiet
```

A change is done when the package tests pass and the app builds without new warnings.
