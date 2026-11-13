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
  glow**: a static mesh of about five colours extracted from the gallery's cover (reuse
  `App/Features/Home/CardPalette.swift` and `CardBackground.swift`). In light appearance the glow
  is a pastel wash (`E-Detail-Light`).
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
  one tag flow, comments after), on glass panels over the cover glow.
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
Known so far: "Library" (tab and title), "Page %d of %d · %d left", "Live Text" (visible label),
"Filters, %d active" (accessibility).

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

- `.font(.screenTitle)`: a large title drawn in the content (34 pt), e.g. Home's or Search's header.
- `.font(.sectionTitle)`: a section title (20 pt): "Previews", "Comments", "Quick search".
- `.font(.heading(.title2))`: any other size, e.g. Home's 22 pt "Frontpage".
- Navigation bar titles (large and inline) are serif automatically (`NavigationBarTitles`,
  configured at launch); `.navigationTitle` needs nothing extra. `SubSection` titles use `.sectionTitle`.

### Tint (`App/DesignSystem/Tokens/AppTint.swift`)

The root applies `.tint(settings.accentColor.appTint)`: on iOS 26 bone in dark and ink in light
while the accent setting is the default (any system blue), otherwise the user's colour; on iOS 18
always the setting.

- Anything that re-applies the tint (a sheet, a cover) uses `settings.accentColor.appTint`, never
  `settings.accentColor.color`. `ReaderScreen` still does the latter for its settings sheet.
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
nothing. Doing it once for every pushed screen belongs in `RoutedStack` / `RouteDestination`
(owned by the navigation work, not done here).

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
- `CardBackground(palette:isAnimated:)`: today's drifting card backdrop on Home (legacy
  `ColorfulView`), moved here unchanged. E-Home's pager glow "drifts slowly only while the pager
  is on screen and still"; `CoverGlow` is static, so the Home rework either keeps it still or
  reuses `CardBackground`'s drift.
- The detail page already shows `CoverGlow(.page)` behind today's layout (`DetailBackdrop`).

### Category mark (`App/DesignSystem/Controls/CategoryLabel.swift`)

`CategoryLabel(gallery.category.localizedName, color: gallery.color(for: settings.galleryHost))`
draws the dot and the name in `textSecondary` (`font:` defaults to `.footnote`, `foreground:` to
`.textSecondary`). The dot always uses the vivid (light) category colour with a ring of at least
3:1 against the ground, so every category shows in both appearances. Never put it on a cover.

### Metrics (`App/DesignSystem/Tokens/Tokens.swift`)

`Tokens.Radius.panel` (24) for glass panels; the existing spacing, radius and image tokens are unchanged.
