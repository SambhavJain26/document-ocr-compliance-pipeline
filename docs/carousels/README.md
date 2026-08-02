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

## The concept: the marked-up document

The deck looks like a page somebody has been over with a highlighter and a
pen. Marker swipes, circled words, an underline, a strike-through, one word
boxed like a selected object.

This is not decoration. The subject of this work is documents that a person
reads and annotates, so the annotation layer *is* the argument, and it is
what stops a type-only deck reading as generic. It also gives every slide a
second element without needing photography, icons, or illustration.

**Nothing is a clean rectangle.** The marker swipe has uneven top and bottom
edges, the circles are drawn as open loops that overshoot, the underline is
two strokes at different opacities. If a mark looks machine-made it has
failed.

## Palette

Owner-supplied, 2026-08-02. Replaces the Stage 7 dashboard colors, which
belong to a demo UI and must not be reused here.

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

### The color rule

One rule, and it removes every "is this intentional" question:

> **Type is always ink. Color only ever appears as an annotation on top of
> type, or as the page number.**

Every word on every slide is `#02081F` or `#383B3D`. Nothing else. Color
enters only as a marker swipe, a pen stroke, or a selection box — that is,
only as something a person added on top of a finished page.

| Value | Role |
|---|---|
| `#FDF0D6` | The ground. Every slide |
| `#02081F` | All display type, everywhere |
| `#383B3D` | Running detail copy |
| `#7B8285` | Eyebrow, footer deck title |
| `#F8C043` | The highlighter swipe. Byline rule |
| `#3563CA` | The pen. Circles, underlines, strikes, page number, the second-voice note |
| `#1F4393` | The selection box fill. Once per deck, on the word the argument turns on |
| Everything else | Reserved. Defined in the stylesheet for a deck that needs to look unlike this one |

## Type

Two families.

| Role | Family | Weights |
|---|---|---|
| Everything | **Switzer** | 900 display · 800 lead · 600 turn/checks · 400 detail · 700 micro |
| The second voice: the payoff word, the annotation note | **Zodiak** italic | 700/800 |

Both from Fontshare, loaded at render time, so the render machine needs
network access. A failed fetch falls back to a system face silently rather
than erroring, so check a rendered slide before publishing.

**Deliberately dropped, with reasons.** Clash Display — its period is an
oversized square that wrecks every sentence ending. Boska italic — too light
to hold against a black grotesque. IBM Plex — safe rather than wrong, and
safe is what made the first pass boring. Inter, Roboto, Helvetica, Arial,
Open Sans, Poppins, Montserrat — the generic-template tells.

## Layouts

| Layout | Classes |
|---|---|
| Cover | `.display` `.kicker` |
| Statement | `.lead` `.divider` `.turn` |
| Field list | `.lead` `.tags` `.detail` |
| Check list | `.head` `.checks` |
| Payoff | `.head` `.pay` `.margin-note` |
| Close | `.close-lead` `.close-turn` `.byline` |

Annotation classes, usable inside any of them: `.hl` (marker), `.pen
--circle` / `--under` / `--strike`, `.sel` (selection box).

**Content centers in a bounded band** between the eyebrow and the footer.
Slide copy runs from 8 words to 24, so a fixed top anchor strands short
slides in the upper third with a dead page underneath.

## Standing rules

- **Nothing bleeds across the footer.** An earlier pass let a graphic run
  over the page number and it read as a mistake rather than a decision.
  Overlap is allowed and wanted, but only where a person would have made it:
  a marker over a word, a circle around a phrase.
- No progress dots, no swipe prompt, no logo, no icon sets, no stock or AI
  imagery.
- The document title typed on upload is displayed in the feed. Use the cover
  line, not a filename.
