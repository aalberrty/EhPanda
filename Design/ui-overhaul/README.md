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
