# UI overhaul ("Direction E")

The owner chose this redesign on 2026-11-13 after reviewing directions A to D on a design canvas
(https://claude.ai/artifact/2BecwQCoa8q3H5cedjsMy4, private to the owner). It is an approved step
beyond feature parity: the layout and look change, the feature set does not.

The mockups in `mockups/` are the reference. They are HTML for the canvas (they load the canvas's
`support.js` and will not render on their own); read them as source. Values in them (sizes,
spacing, colours, type) are the intent, not pixel law: use the closest native SwiftUI construct.
`Today-*.dc.html` redraw the app as it was before the overhaul, for comparison.

| Mockup | Screen |
|---|---|
| `E-Home.dc.html`, `E-Toplists.dc.html` | Home, top and scrolled to Toplists |
| `E-Library.dc.html` | Library tab (replaces Favorites) |
| `E-List.dc.html`, `B-Extra.dc.html` | Gallery list (two-across covers) and the long-press peek |
| `E-Detail.dc.html`, `E-Detail-Light.dc.html` | Gallery detail, dark and light appearance |
| `E-Reader.dc.html`, `E-Reader-Drag.dc.html` | Reader controls, at rest and while dragging the slider |
| `E-Search.dc.html` | Search tab |

## The owner's decisions

- **Look:** cover-first (direction B). Warm near-black ground, bone-white controls, colour comes
  only from covers and category marks. Screen and section titles use the serif system design
  (New York); gallery titles stay in the default design so mixed-script titles hold up.
- **Liquid Glass** on bars, floating controls and the gallery detail's panels, over a **cover
  glow**: a static mesh of about five colours extracted from the gallery's cover (the palette
  extraction Home's cards used, now `CoverPaletteExtractor` and `CoverPaletteStore`). In light
  appearance the glow is a pastel wash (`E-Detail-Light`).
- **Tabs:** Home, **Library**, Setting, plus Search as today. Library holds Favorites, Watched and
  History behind a three-part control; each keeps its own scroll place; favourite folders are
  chips. Home no longer has the Watched / History / Popular "Other" tiles.
- **Home:** Popular as a cover pager with a quieter glow, Frontpage as a three-across wall with
  titles, Toplists below (today's swipeable period columns, restyled).
- **Gallery list:** two large covers across; a cell shows category, page count and title; the
  rest moves to a long-press peek (with Read and Share) and to the Detail list mode. The
  Detail/Thumbnail switch sits in the list toolbar.
- **Category:** a colour dot plus the name in normal text, everywhere, replacing white text on a
  coloured pill.
- **Gallery detail:** direction B's layout (cover as hero with Read set into it, previews moved up,
  one tag flow, comments after), on glass panels over the cover glow. No tab bar, as drawn, on the
  detail page and on the screens pushed from it (comments, previews, gallery infos), so it does
  not come and go between them (decided 2026-11-13); `RouteDestination` hides it per route.
- **Reader:** reading behaves exactly as before: vertical continuous scroll by default and every
  existing reading mode and setting unchanged. **No glow in the reader.** Only the controls change:
  close, a title capsule ("Page 12 of 64 · 52 left") and More at the top; one glass panel at the
  bottom with a handle (swipe down to close, replacing the second close button), the slider with
  1 and the total at its ends, and labelled Live Text, Auto-Play and Reading setting buttons. The
  page preview strip shows **five** thumbnails (50×69 pt in the mockup) and appears **only while
  the slider is being dragged**, as today; letting go jumps to that page.
- **Search:** direction D's layout restyled: Quick search words as one-tap chips, recent searches
  in two columns, Recently seen as covers, and the search filter chips directly above a bottom
  search field.

## iOS 26 and iOS 18

- **iOS 26:** as drawn: Liquid Glass and the cover glow.
- **iOS 18:** the same rearranged layout, with the **baseline v3 look**: no imitation of Liquid
  Glass and no new effects. Glass surfaces fall back to what v3 already uses on iOS 18
  (`App/DesignSystem/Availability/Glass.swift`, system materials and backgrounds). Where iOS 26
  shows the cover glow, iOS 18 shows what v3 shows there today (the detail page's blurred cover
  backdrop; plain background elsewhere). The choice lives in one place (the design tokens and the
  `Availability` helpers), never in `#available` checks at call sites.

## Light appearance

The app keeps following the system appearance (and the existing Theme setting). Only the detail
page was drawn in light; the other screens derive their light version from it: warm off-white
ground, ink text, the same structure, glass and glow toned down to a pastel wash.

## Not drawn, restyle only

Settings, filters, comments, gallery infos, previews grid, archives, torrents, the share extension
and the login flow keep their structure and pick up the new tokens (ground, text colours, serif
titles, category dot, glass helpers) without new layouts.

## Performance (the repo's rules still apply)

- Glass and glow only on a screen's few large surfaces, never per cell in a scrolling list or grid.
- The glow is a static `MeshGradient`, drawn once; palette extraction runs off the main actor,
  is cached per gallery, and is shared with Home so Detail reuses a palette Home already made.
- Covers are downsampled to their new, larger display size.
- The reader's preview strip loads only while the slider is held.

## New strings

Every new key goes into all `App/Resources/*.lproj/Localizable.strings` and `Strings.swift`.
The keys the overhaul added are listed under "Localized keys to review" at the end.

## Building blocks

The design foundation every screen builds on. Use these instead of defining colours, fonts,
glass or glow at a call site. `AppLook.isRedesigned` (`App/DesignSystem/Availability/AppLook.swift`)
is the one iOS 26 / iOS 18 switch; only the tokens and the `Availability` helpers read it.
Screens never check `#available(iOS 26, *)` for the look.

### Colours (`App/DesignSystem/Tokens/ColorTokens.swift`)

Usable as `Color.ground` or as a shape style: `.background(.ground)`, `.foregroundStyle(.textSecondary)`.
Stronger values apply under Increase Contrast.

| Token | iOS 26 dark | iOS 26 light | iOS 18 | For |
|---|---|---|---|---|
| `ground` | `#100E0C` | `#F6F2EB` | `systemBackground` | behind a screen |
| `groundGrouped` | `#100E0C` | `#F6F2EB` | `systemGroupedBackground` | behind a grouped list or form |
| `raised` | `#1C1917` | `#FFFCF7` | `secondarySystemBackground` | cards and the long-press peek |
| `raisedGrouped` | `#1C1917` | `#FFFCF7` | `secondarySystemGroupedBackground` | rows of a grouped list |
| `textPrimary` | `#F4EFE7` | `#1A1612` | `label` | titles, body |
| `textSecondary` | `#CFC7BC` | `#574F46` | `secondaryLabel` | uploader, meta lines, "Show all", category name |
| `textTertiary` | `#B3AA9F` | `#61594F` | `secondaryLabel` | tag namespaces, chip prefixes (still readable text) |
| `hairline` | bone 12 % | ink 12 % | `separator` | separators, dividers in a glass bar |
| `chipFill` | bone 10 % | ink 7 % | `tertiarySystemFill` | unselected chips, tag pills |
| `selectedFill` / `onSelectedFill` | bone / ground | ink / ground | `label` / `systemBackground` | selected chip or segment and its text |
| `coverEdge` | bone 10 % | ink 6 % | clear | 1 pt ring around covers |

Every text token is at least 5:1 on the ground, on `raised` and on the glass panels in both appearances.

```swift
Text(gallery.uploader).font(.footnote).foregroundStyle(.textSecondary)
RoundedRectangle(cornerRadius: 10).strokeBorder(.coverEdge)
```

### Type (`App/DesignSystem/Tokens/Typography.swift`)

Serif (New York) bold on iOS 26, the default design on iOS 18. Gallery titles never use these.

- `.font(.screenTitle)`: a large title drawn in the content (34 pt). Unused so far: Home and
  Search kept the navigation bar's large title, which is the same serif 34 pt on iOS 26.
- `.font(.sectionTitle)`: a section title (20 pt): "Previews", "Comments", "Quick search".
- `.font(.heading(.title2))`: any other size, e.g. Home's 22 pt "Frontpage".
- Navigation bar titles (large and inline) are serif automatically (`NavigationBarTitles`,
  configured at launch); `.navigationTitle` needs nothing extra. `SubSection` titles use `.sectionTitle`.

### Tint (`App/DesignSystem/Tokens/AppTint.swift`)

The root applies `.tint(settings.accentColor.appTint)`: on iOS 26 bone in dark and ink in light
while the accent setting is the default (any system blue), otherwise the user's colour; on iOS 18
always the setting.

- Anything that re-applies the tint (a sheet, a cover) uses `settings.accentColor.appTint`, never
  `settings.accentColor.color`.
- Text or symbols on a tint-coloured fill use `settings.accentColor.appTintForeground` (ground on
  bone or ink, white on an accent colour). `glassProminentButtonStyle()` already does.

### Ground (`App/DesignSystem/Layout/ScreenGround.swift`)

The root draws `.ground`, but each screen's scroll view, list or navigation container draws its
own system background above it. Put the ground on a screen's root view:

```swift
List { … }.screenGround(.grouped)      // Settings-style lists; rows: .listRowBackground(Color.raisedGrouped)
ScrollView { … }.screenGround()
```

It hides a list's own background and draws the ground under the bars; on iOS 18 it does
nothing. Each screen applies it itself; `RoutedStack` and `RouteDestination` do not.

### Glass (`App/DesignSystem/Availability/Glass.swift`)

Glass only on a screen's few large surfaces (bars, floating buttons, the detail panels), never
per cell. iOS 18 shows the material v3 uses (the bar material for `.bar`) with a hairline edge.

| Helper | iOS 26 |
|---|---|
| `glassSurface(in: shape, tone: .regular, isInteractive: false)` | Liquid Glass in `shape` |
| tone `.panel` | glass warmed toward the ground: panels over the cover glow |
| tone `.bar` | darker glass in dark, paler in light: bars and buttons over bright covers |
| `glassPanel(cornerRadius: Tokens.Radius.panel)` | a `.panel` glass rounded rectangle (24 pt) |
| `glassButtonStyle(tone:)` | `.glass` button (tinted for `.panel` / `.bar` on iOS 26.1+) |
| `glassProminentButtonStyle()` | `.glassProminent` in the tint, label in `appTintForeground` |
| `GlassGroup(spacing:) { … }` | `GlassEffectContainer` so neighbouring glass blends |

```swift
VStack { … }.padding(14).glassPanel()                                   // E-Detail's panels
HStack { filterButton; modeButton }.glassSurface(in: Capsule(), tone: .bar)  // E-List's toolbar
Button("Read") { … }.glassProminentButtonStyle()
```

### Cover glow (`App/DesignSystem/CoverGlow/`)

- `CoverGlow(gallery:coverURL:style:)`: a static `MeshGradient` of the cover's five palette
  colours. Place it as a background; it loads its palette and fades to new colours.
  - `.page`: full screen, opaque, ignores the safe area (dark: dimmed toward the ground; light:
    pastel wash). iOS 18: the blurred cover at the top (today's detail backdrop).
    `ScrollView { … }.background { CoverGlow(gallery: gallery, style: .page) }`
  - `.quiet`: fainter, transparent, fading out toward its bottom edge, for Home's Popular pager;
    it fills the frame it is given and does not ignore the safe area, so size and place it to
    cover the pager and the space above it (E-Home: the top 620 pt). iOS 18: nothing.
    `pager.background(alignment: .top) { CoverGlow(gallery: current, style: .quiet) }`
  - `coverURL` overrides the gallery's own, e.g. `model.gallery.coverURL ?? model.detail?.coverURL`.
- `CoverPaletteStore`: the shared palettes, injected by `AppShellView`. Read it with
  `@Environment(CoverPaletteStore.self) private var palettes`; `palettes.palette(for: gallery.id)`
  observes only that gallery; `await palettes.load(gallery)` from a `.task`. Previews inject
  `.environment(CoverPaletteStore())`. The extraction itself is `CoverPaletteExtractor` in `EhCore`.
  - One palette per gallery for the session (a gallery keeps its cover); the store keeps the
    400 most recent and drops the oldest beyond that.
  - Each gallery's palette is its own observable entry, so a palette arriving redraws only the
    views showing that gallery. `CoverGlow` reads it this way; read it the same way elsewhere,
    never by iterating the store.
  - `load` reuses the cover Kingfisher already downloaded, decodes a small thumbnail and analyses
    it off the main actor. A second call while one runs returns at once; a load cancelled with
    its view's `.task`, or one that failed, runs again on the next call.
  - `load(galleryID:coverURL:)` takes a cover URL the gallery lacks, e.g. the detail's.
- Both are static: Home's pager glow does not drift (the mockup's drift was dropped for
  scrolling cost), and the detail page shows `CoverGlow(.page)` through `DetailBackdrop`.

### Category mark (`App/DesignSystem/Controls/CategoryLabel.swift`)

`CategoryLabel(gallery.category.localizedName, color: gallery.color(for: settings.galleryHost))`
draws the dot and the name in `textSecondary` (`font:` defaults to `.footnote`, `foreground:` to
`.textSecondary`). The dot always uses the vivid (light) category colour with a ring of at least
3:1 against the ground, so every category shows in both appearances. Never put it on a cover.

### Metrics (`App/DesignSystem/Tokens/Tokens.swift`)

`Tokens.Radius.panel` (24) for glass panels; the existing spacing, radius and image tokens are unchanged.

### Rating colour (`App/DesignSystem/Tokens/RatingColor.swift`)

`.foregroundStyle(.rating)` for rating stars that show a rating: the text colour on iOS 26 (colour
comes only from covers and category marks), v3's yellow on iOS 18. The stars that give a rating
(the detail page's `RatingControl`) stay yellow.

### Bars, search fields and titles (`App/DesignSystem/Availability/`)

Each picks its iOS 26 API or the iOS 18 stand-in in one place, like `Glass.swift`.

| Helper | iOS 26 | iOS 18 |
|---|---|---|
| `floatingBar(edge:spacing:background:)` (`SafeAreaBar.swift`) | `safeAreaBar`: content scrolling under the bar fades under the scroll edge effect | `safeAreaInset` with `background` behind the bar: `.none` (the bar draws its own surface), `.material`, or `.materialUnderNavigationBar` (the material runs up behind the navigation bar, whose own background is hidden, so title and bar read as one) |
| `SegmentedControl(_:options:selection:optionTitle:onSelect:)` (`SegmentedControl.swift`) | E-Library's control: a `.bar` glass capsule with a sliding `selectedFill` segment | the native segmented picker |
| `toolbarSearchable(text:prompt:)` plus `ToolbarSearchItem()` in the toolbar (`ToolbarSearch.swift`) | a search button among the toolbar's items that expands into the field (`searchToolbarBehavior(.minimize)`) | the field in the navigation bar drawer |
| `tagSearchable(…, inToolbar: true)` (`Features/Search/Components/TagSearchField.swift`) | the same, for the server search field with tag suggestions (search results outside the Search tab) | the same as `toolbarSearchable` |
| `navigationTitle(_:subtitle:)` (`NavigationSubtitle.swift`) | the title, large, with `navigationSubtitle` under it (Toplists and its period) | one inline title, "Toplists - Yesterday" |
| `risesUnderNavigationBar(by:)` (`HeroUnderBar.swift`) | raises a hero image into the navigation bar, between its glass buttons (E-Detail's cover); apply it to the first view of the scroll content | nothing: the back button carries the previous screen's title and would run over the hero |
| `hidesTopScrollEdgeEffect(_:)` (`HeroUnderBar.swift`) | hides the soft edge under the navigation bar while true, so a hero raised under the bar is not blurred at rest | nothing |

```swift
List { … }
    .floatingBar(edge: .top, spacing: 0, background: .materialUnderNavigationBar) { segmentControl }
PagedGalleryList(model: model)
    .toolbarSearchable(text: $model.titleFilter, prompt: L10n.Localizable.Searchable.Prompt.filter)
    .toolbar {
        ToolbarSearchItem()
        ToolbarItemGroup(placement: .primaryAction) { ListDisplayModeButton(); FiltersButton { … } }
    }
```

Every gallery list puts `ListDisplayModeButton()` (`Features/GalleryList`) first among its
toolbar's actions; it flips the app-wide Detail / Thumbnail setting.

### Presentation helpers (`App/Presentation/`)

- `GalleryDetail.formattedSize`: "183.3 MiB", at most two decimals (the stored `Float` would
  print as 183.300003). The detail page's figures and Gallery infos use it.

### Pitfalls the screen work ran into

- **Context-menu previews do not inherit the environment.** The `preview:` of
  `.contextMenu(menuItems:preview:)` is hosted outside the view hierarchy, so an
  `@Environment(SettingsStore.self)` in it crashes on long-press. Read the stores in the cell and
  pass them on: `GalleryPeek(…).environment(settings).environment(tagTranslations)`
  (`GalleryGridItem` in `GalleryCollection.swift`).
- **`Binding(set:)` with a method reference crashes the compiler.** Swift 6.2.3 crashes while
  compiling when a `@MainActor` method is passed straight to `Binding(set:)`, as in
  `Binding(get: { model.x }, set: model.setX)`. Wrap it in a closure: `set: { model.setX($0) }`.
- **The Search tab owns the search button of its whole stack on iOS 26.** In a `Tab(role: .search)`
  a pushed screen's `ToolbarSearchItem` opens the Search root's field and drops the screen.
  `SearchResultsView` therefore keeps the plain field when its stack is `AppRouter.search`.
- **`onChange(of:initial: true)` runs again when a screen comes back from a pushed one.** A
  handler that resets state (Home's pager used to jump back to its second page) must check that
  the value really changed.

## Localized keys to review

Every key the overhaul added (the lproj files against branch `v3`), with its text in each
language, for a native speaker to check. All eight `.strings` files have every key.

| Key | en | de | ja | ko | zh-Hans | zh-Hant, zh-Hant-HK, zh-Hant-TW |
|---|---|---|---|---|---|---|
| `tab_item.title.library` | Library | Bibliothek | ライブラリ | 보관함 | 资料库 | 資料庫 |
| `search_view.filter_bar.filters_active` (VoiceOver) | Filters, %d active | Filter, %d aktiv | フィルター、%d 件有効 | 필터, %d개 활성 | 筛选，%d 项已启用 | 過濾，%d 項已啟用 |
| `search_view.filter_bar.minimum_rating` | %d+ | %d+ | %d+ | %d+ | %d+ | %d+ |
| `reading_view.toolbar_item.button.live_text` | Live Text | Live Text | テキスト認識表示 | 라이브 텍스트 | 实况文本 | 原況文字 (zh-Hant-HK: 實況文字) |
| `reading_view.title.page_position` | Page %d of %d · %d left | Seite %d von %d · noch %d | %1$d / %2$d ページ · 残り %3$d ページ | %1$d / %2$d페이지 · %3$d페이지 남음 | 第 %d 页，共 %d 页 · 剩余 %d 页 | 第 %d 頁，共 %d 頁 · 剩餘 %d 頁 |
| `search_view.button.remove_keyword` (VoiceOver) | Remove %@ | %@ entfernen | %@を削除 | %@ 삭제 | 移除 %@ | 移除 %@ |

The overhaul also removed ten keys nothing shows any more: `home_view.section.title.other`,
`enum.home_misc_grid_type.title.watched` and `.history` (Home's old tiles), and the seven
`detail_view.description_section.*` keys (the detail page's old figures row).
