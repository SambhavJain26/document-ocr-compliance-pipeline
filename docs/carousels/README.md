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

### Every value has a job

A palette is a range to select from, not a checklist — twenty-one colors
inside one eight-slide deck would look worse, not better. But every value
carries a defined role across the system, so different layouts and different
carousels draw on different parts of each ramp.

| Value | Role |
|---|---|
| `#C9D7F0` | Running copy on dark grounds. Ghost numerals on the light variant |
| `#96B0E3` | Index rail, eyebrow counts, secondary copy on dark |
| `#6389D6` | Eyebrow text, list numerals in the grouped layout |
| `#3563CA` | Hairlines and annotation text on dark. Never a fill behind copy |
| `#1F4393` | Ghost numerals, radial lift on both grounds |
| `#0E2455` | Interior slide ground |
| `#02081F` | Cover and close ground |
| `#FDF0D6` | Type set on a gold fill |
| `#F8C043` | The accent. Eyebrow rule, cover mark, active index item, italic emphasis, the one figure that matters |
| `#CA9C35` | Date-grid strokes and fills on dark |
| `#A17C28` | Date-grid strokes on light surfaces |
| `#77581B` | Low grid fill |
| `#4C390E` | Deepest grid fill on dark |
| `#251A04` | Reserved: the artifact border, if a deck ever carries a real screenshot |
| `#EDEFF0` | Headline type on dark. Ground for the light variant |
| `#C2C9CC` | Hairlines on light surfaces |
| `#9BA3A8` | Annotations and estimate marks on light |
| `#7B8285` | Eyebrow text on light |
| `#595F61` | Running copy on light |
| `#383B3D` | Secondary headings on light |
| `#191B1C` | Headline type on light |

### Standing color rules

1. **The deck is dark by default.** `#02081F` for the bookends, `#0E2455`
   for the interior. `.slide--paper` exists for a deck that needs a light
   slide for contrast; it is the exception, not the default.
2. **Gold is the only accent and there is only one.** It never sets body copy
   and never carries a status word.
3. **Severity, grouping, and emphasis are carried by scale, rules, and
   space, never by hue.** Post 7 splits twelve items into seven and five
   without color doing that work — the two group labels differ in rule
   weight, not color.
4. Real screenshots, if any deck ever carries one, keep their own colors and
   are the only place anything outside this table appears.

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

## Layouts

Six named layouts cover all four carousels. `template-specimen.html` renders
every one of them on a single page using real copy, so a new post is a
matter of picking layouts rather than designing slides.

| Layout | Classes | Used by |
|---|---|---|
| Cover | `.display` `.mark` `.sub` | all four |
| Numbered item | `.ghost` `.label` `.detail` `.index` | post 1, slides 2–7 |
| Grouped list | `.group__label` `.items` | post 7, slides 2–7 |
| Figure stack | `.figures` `.figure` `.figure__cap` `.note` | post 4, slides 4–5; post 13, slides 5–7 |
| Matched pair | `.pair__head` `.pair__body` | post 13, slides 3–4 |
| Close | `.close-lead` `.close-detail` `.close-ask` `.byline` | all four |

The index rail is the answer to short copy. Slides carry at most 22 words,
so a numbered item leaves the lower half of the page empty. Listing all six
items with the current one live fills it with the thing a Value-Stack deck
most needs to prove — that the cover's count is real and the set is complete
— and it removes any need for a progress-dot widget.

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
