# Carousel Design System

The fixed template behind every LinkedIn document carousel in
`docs/linkedin-post-scripts.md`. `carousel-template.css` is the single source
of truth; per-post HTML supplies content and picks layout classes only, and
must never introduce its own sizes, colors, or spacing. If a post needs
something the stylesheet cannot express, add a named layout here and to the
stylesheet so later posts inherit it.

Render with `.\scripts\generate-linkedin-carousel.ps1`. Page size is
1080x1350 (4:5), the tallest ratio LinkedIn renders predictably in-feed on
mobile, which is where these get read.

## Palette

Owner-supplied, 2026-08-02. This replaces the earlier saturated blue/yellow
set and the Stage 7 dashboard colors. The dashboard palette is a demo UI and
must not be reused here.

**Primary** `#3563CA` · **Secondary** `#CA9C35`

| Blue | Gold | Neutral |
|---|---|---|
| `#C9D7F0` | `#FDF0D6` | `#EDEFF0` |
| `#96B0E3` | `#F8C043` | `#C2C9CC` |
| `#6389D6` | `#CA9C35` | `#9BA3A8` |
| `#3563CA` | `#A17C28` | `#7B8285` |
| `#1F4393` | `#77581B` | `#595F61` |
| `#0E2455` | `#4C390E` | `#383B3D` |
| `#02081F` | `#251A04` | `#191B1C` |

### Where each color is allowed

1. **`#02081F` is the ground** for cover and close slides only. Interior
   slides are `#EDEFF0` paper. Two dark slides per deck, no more.
2. **Gold is the accent and there is only one accent.** It appears on the
   eyebrow rule, the cover mark, and hairline motif strokes. It never sets
   body copy and never carries a status word.
3. **Blue is structural, not decorative.** `#0E2455` sets headings on paper;
   `#C9D7F0` sets the ghost numerals; `#1F4393` is the radial lift on dark
   grounds. Bright `#3563CA` is used sparingly and never as a fill behind
   text.
4. **Severity, grouping, and emphasis are carried by scale, rules, and
   space, never by hue.** Post 7 splits twelve items into seven and five
   without color doing that work.
5. Real screenshots, if any deck ever carries one, keep their own colors and
   are the only place other colors appear.

## Type

Two families, per current editorial practice. Neo-grotesques have displaced
geometric sans in professional work, and display serifs are the counterweight
that keeps a deck from reading as a template.

| Role | Family | Notes |
|---|---|---|
| Display, labels, ghost numerals | **Instrument Serif** | High-contrast editorial serif. Regular only |
| Detail copy, eyebrows, bylines | **Geist** | Neo-grotesque. 300–600 |

Deliberately not used: Inter, Roboto, Helvetica, Arial, Open Sans, Poppins,
Montserrat, and IBM Plex. The first five are the generic-template tells; Plex
is safe rather than wrong, and safe is what made the first pass boring.

Both load from Google Fonts at render time, so the render machine needs
network access. A failed fetch falls back to a system serif silently rather
than erroring, so check a rendered slide before publishing.

## Graphic system

No stock photography, no AI imagery, no icon sets. Three devices only, all
drawn in CSS:

- **The date grid.** A seven-column field of hairline gold cells with a few
  filled, bleeding off the page edge. Runs on cover and close slides as the
  hero graphic. The concept is literal: the work is documents with dates on
  them.
- **Ghost numerals.** The item number set enormous in `#C9D7F0`, bled off the
  right edge behind the content. Interior slides only. Carries the count
  without a counter widget.
- **Film grain.** A fixed low-opacity turbulence overlay on every slide,
  giving the flat PDF a printed feel rather than a screen one.

## Standing rules

- No slide counter widget, no swipe prompt, no progress dots, no logo.
  LinkedIn renders its own page badge.
- Nothing is vertically centered. Every slide anchors to the same left edge
  and the same top baseline so a swipe reads as pages of one document.
- The detail size is exactly half the label size.
- The document title typed on upload is displayed in the feed. Use the cover
  line, not a filename.
