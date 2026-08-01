# Carousel Design System

The fixed template behind every LinkedIn document carousel in
`docs/linkedin-post-scripts.md`. `carousel-template.css` is the single source
of truth; per-post HTML supplies content and picks layout classes only, and
must never introduce its own sizes, colors, or spacing. If a post needs
something the stylesheet cannot express, add a named layout here and to the
stylesheet so later posts inherit it.

`template-specimen.html` renders every layout on one page with real copy, so
a new post is a matter of picking layouts rather than designing slides.
Render with `.\scripts\generate-linkedin-carousel.ps1`. Page size is
1080x1350 (4:5), the tallest ratio LinkedIn renders predictably in-feed on
mobile, which is where these get read.

## Palette

Owner-supplied, 2026-08-02. This replaces the Stage 7 dashboard colors,
which belong to a demo UI and must not be reused here.

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
| `#C9D7F0` | Reserved: type on a deep-blue fill |
| `#96B0E3` | Reserved: muted copy if a deck inverts to a dark ground |
| `#6389D6` | Reserved: secondary marks on a dark ground |
| `#3563CA` | The brand blue at full strength. Reserved for a figure that must shout |
| `#1F4393` | **Headings.** Item labels, figure stacks, matched pairs, page numbers, the italic emphasis word |
| `#0E2455` | Reserved: dark-ground variant |
| `#02081F` | Display type on the cover and close. Badge text |
| `#FDF0D6` | **The ground.** Every slide |
| `#F8C043` | Brightest gold. Reserved for a grid cell that must read as marked |
| `#CA9C35` | Badge fill, eyebrow rule, cover mark, date-grid strokes, ghost numerals |
| `#A17C28` | Step labels, hairlines, footer rules |
| `#77581B` | Reserved: deeper gold fill |
| `#4C390E` | Reserved: deepest gold fill |
| `#251A04` | Reserved: artifact border, if a deck ever carries a real screenshot |
| `#EDEFF0` | Reserved: cool light ground for a deck that needs to look unlike this one |
| `#C2C9CC` | Reserved: cool hairline |
| `#9BA3A8` | Index rail numerals |
| `#7B8285` | Index rail inactive items, footer deck title |
| `#595F61` | Reserved: tertiary copy |
| `#383B3D` | Running detail copy |
| `#191B1C` | Reserved: maximum-contrast ink |

### Standing color rules

1. **The deck is light and warm.** `#FDF0D6` on every slide. An earlier pass
   ran the whole deck on the navy ramp; the reversal is deliberate and the
   dark tokens stay defined for a deck that needs to look different.
2. **Blue carries type, gold carries structure.** Gold on cream is nearly
   the same value as cream, so gold set at size goes monochrome and muddy.
   Headings take `#1F4393`; gold does badges, rules, grid, and ghosts.
3. **Severity, grouping, and emphasis are carried by scale, rules, and
   space, never by hue.** Post 7 splits twelve items into seven and five
   through rule weight on the group label, not color.
4. Real screenshots, if any deck ever carries one, keep their own colors and
   are the only place anything outside this table appears.

## Type

Three families. That is one more than the usual two-font ceiling and it is
deliberate: the mixed-face headline, where one emphasized word inside a
sentence switches to a contrast serif italic, is the single strongest device
in the reference decks and it needs a third voice.

| Role | Family | Source |
|---|---|---|
| Display, labels, figures, list items | **Clash Display** 500/600 | Fontshare |
| The emphasis word inside a headline, step labels, estimate notes | **Boska** italic | Fontshare |
| All running copy, eyebrows, index rail, footer | **Satoshi** 400/500/700 | Fontshare |

Deliberately not used: Inter, Roboto, Helvetica, Arial, Open Sans, Poppins,
Montserrat, and IBM Plex. The first several are the generic-template tells;
Plex is safe rather than wrong, and safe is what made the first pass boring.

All three load from `api.fontshare.com` at render time, so the render machine
needs network access. A failed fetch falls back to a system face silently
rather than erroring, so check a rendered slide before publishing.

## Layouts

| Layout | Classes | Used by |
|---|---|---|
| Cover | `.badge` `.display` `.mark` `.sub` | all four |
| Numbered item | `.ghost` `.step` `.label` `.detail` `.index` | post 1, slides 2–7 |
| Grouped list | `.group__label` `.items` | post 7, slides 2–7 |
| Figure stack | `.figures` `.figure` `.figure__cap` `.note` | post 4, slides 4–5; post 13, slides 5–7 |
| Matched pair | `.pair__head` `.pair__body` | post 13, slides 3–4 |
| Close | `.close-lead` `.close-detail` `.close-ask` `.byline` | all four |

Persistent on every slide: `.eyebrow` top left, and `.footer` carrying the
deck title and page number above a hairline.

The index rail is the answer to short copy. Slides carry at most 22 words,
so a numbered item leaves the lower field empty. Listing all six items with
the current one live fills it with the thing a count-based deck most needs to
prove — that the cover's count is real and the set is complete — and it
removes any need for a progress-dot widget.

## Graphic system

No stock photography, no AI imagery, no icon sets. Four devices, all drawn
in CSS:

- **The date grid.** A seven-column field of hairline gold cells with a few
  filled, bleeding off the page corner. Bookend slides only. The concept is
  literal: the work is documents with dates on them.
- **Ghost numerals.** The item number set at 620px in Clash Display, bled off
  the right edge in transparent gold. Interior slides only. Carries the count
  without a counter widget. Fixed width and right-aligned so every digit
  clips by the same amount — without that a "1" and a "4" look accidental.
- **The badge.** A solid gold block on the cover carrying the promise.
- **Film grain.** A turbulence overlay at 5% on every slide, so a flat PDF
  reads as printed rather than screenshotted.

## Standing rules

- No progress dots, no swipe prompt, no logo. LinkedIn renders its own page
  badge and the footer carries a page number.
- Nothing is vertically centered. Every slide anchors to the same left edge
  so a swipe reads as pages of one document.
- The document title typed on upload is displayed in the feed. Use the cover
  line, not a filename.
