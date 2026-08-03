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
pen. Marker swipes, circled words, an underline, a strike-through, and one
word boxed like an object picked up in a design tool.

This is not decoration. The subject of this work is documents that a person
reads and annotates, so the annotation layer *is* the argument, and it is
what stops a type-only deck reading as generic. It also gives every slide a
second element without needing photography, icons, or illustration.

**Nothing is a clean rectangle.** The marker swipe has uneven top and bottom
edges, the circles are drawn as open loops that overshoot, the underline is
two strokes at different opacities. If a mark looks machine-made it has
failed.

**The page is ruled, horizontally and vertically.** Faint horizontal lines
every 72px plus one vertical margin rule at 56px, the way a notebook page is
ruled. The vertical stroke is what makes the horizontal ruling read as a grid
somebody printed rather than a texture somebody applied.

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
enters only as a marker swipe, a pen stroke, or the selection box — that is,
only as something a person added on top of a finished page. Page furniture —
the horizontal ruling and the vertical margin rule — is an ink tint, because
it is printed rather than added by hand.

| Value | Role |
|---|---|
| `#FDF0D6` | The ground. Every slide |
| `#02081F` | All display type, everywhere |
| `#383B3D` | Running detail copy |
| `#7B8285` | Eyebrow, footer deck title |
| `#F8C043` | The highlighter swipe. Byline rule |
| `#3563CA` | The pen. Circles, underlines, strikes, the selection handles, page number |
| `#1F4393` | The selection box fill. Once per deck, on the cover |
| Everything else | Reserved. Defined in the stylesheet for a deck that needs to look unlike this one |

## Type

Two families.

| Role | Family | Weights |
|---|---|---|
| Everything | **Switzer** | 900 display · 800 lead · 600 turn/checks · 400 detail · 700 micro |
| The second voice: the payoff word, and nothing else | **Zodiak** italic | 800 |

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
| Field list | `.lead` `.tags` `.divider` `.turn` |
| Check list | `.head` `.checks` |
| Payoff | `.head` `.pay` `.margin-note` |
| Close | `.close-lead` `.divider` `.turn` `.byline` |

Annotation classes, usable inside any of them: `.hl` (marker),
`.pen--circle` / `--under` / `--strike` (inline pen marks), and `.sel` (a word
boxed with corner handles, once per deck on the cover).

**Every mark sits on a word.** A brace hung in the right margin was tried and
cut: at the sizes this deck runs, a mark floating outside the text block reads
as debris rather than as annotation.

**Zodiak sets exactly one word in the deck** — the payoff on slide 6. The note
underneath it takes the same treatment as the second line on every other
slide, so the second voice speaks once and means something.

**Content centers in a bounded band** between the eyebrow and the footer.
Slide copy runs from 8 words to 24, so a fixed top anchor strands short
slides in the upper third with a dead page underneath.

## One deck, no variants

There was briefly a `theme-flip` theme (ink and pen swapped) and a `loud`
theme (bigger type, tighter margins, heavier strokes) layered over a quieter
base. The loud settings won and are now the template's own values. Both
variant files are deleted.

Do not reintroduce a theme layer for a single consumer. Every change then has
to be made twice, and the base it overrides has no other reader. If a future
post needs a different treatment, add a named layout, not a theme.

## The baseline grid

The ruled lines are drawn every 72px. The **baseline unit is 24px** — every
third unit is a drawn rule.

- **Every leading is set in px and is a multiple of 24.** Display 144, lead
  120, turn 72, checks 72, detail and note 48, payoff 192.
- **Every vertical margin and padding is a multiple of 24.** No exceptions,
  including the eyebrow offset, the footer band, and the divider.
- `.turn` and `.checks` sit exactly on a drawn rule on every line, because
  their leading is 72. Display and detail land on the sub-grid and coincide
  with a drawn rule periodically, which is what a baseline grid normally
  looks like.
- **The content block is vertically centred, so a render-time script snaps
  it.** It measures each slide's first baseline with a zero-size inline-block
  probe and translates the block onto the nearest unit. The shift is never
  more than 12px, so centring survives. The script lives at the foot of each
  post file and runs before Chrome prints.

Changing a type size means checking its leading is still a whole number of
units. That is the only maintenance cost of the grid, and it is the thing
that makes the page read as constructed rather than decorated.

## The inverted slide

**One inverted slide per deck**, on the page the argument turns on. In post 1
that is slide 6, the payoff. Used more often it stops being a spike and
becomes a pattern, which reads quieter, not louder.

The cover was briefly inverted too, to establish the dark ground before slide
6 used it. That was reverted: a light cover keeps the dark slide as the single
loudest frame in the deck. If slide 6 ever starts reading as a mistake rather
than as the payoff, the fix is to make slides 5 and 6 an obviously matched
pair, not to invert the cover again.

On an inverted slide the colour rule still holds: every word is one value
(`--paper`), and only annotations carry colour. Highlighted words go dark so
they stay legible on the gold swipe.

## Consistency rules

Learned from an audit that found eleven inconsistencies in the first build.
Each of these exists because something looked like a mistake.

1. **Three rule weights, declared, and nothing uses a number outside them.**
   `--w-hair` separates, `--w-line` outlines, `--w-mark` is furniture the eye
   reads as a deliberate stroke.
2. **Both furniture marks are gold.** The eyebrow rule and the byline rule
   are the same 38px stroke and must stay the same color.
3. **One treatment for "the line after the statement."** Always `.turn`,
   always behind a `.divider`. There is no second, quieter variant — an
   earlier pass set one slide's closer in 400-weight grey and it buried a
   load-bearing line.
4. **Parallel copy gets parallel marks.** Mirrored sentences take the same
   device with different hand-drawn paths, never different devices.
5. **Every slide carries at least one mark.** In a deck whose identity is
   the annotation layer, a bare page reads as an omission.
6. **`.hl` cancels its own padding with an equal negative margin.** Without
   it the character after a highlight detaches and reads as a typo.
7. **No flex containers around annotated text.** A flex parent turns an
   inline `.pen` span into its own flex item and tears the sentence apart.
   `.checks` positions its numeral instead.

## The film grain, and why it is a tile

A 128x128 noise tile at 5% opacity on every slide, so a flat PDF reads as
printed rather than screenshotted. Two constraints, both learned the hard
way, and both worth keeping.

**It must never be an `feTurbulence` filter.** A filter has to be evaluated
at output resolution, so Chrome bakes a full-page bitmap into every slide.
That took the PDF from 132 KB to **24 MB** for visually identical output —
32 embedded images instead of 1. Shrinking the filter's tile does nothing;
only baking it to a real image does.

**The tile must be high-passed.** Generate noise, blur it lightly so it
clumps like fractal noise rather than looking sandy, then subtract a heavily
blurred copy so the tile carries no large-scale light and dark regions. Skip
that step and the tile's own variation repeats across the page and the grid
becomes plainly visible. All blurs wrap at the edges so there is no seam.

Nothing else in the deck is raster. Type is vector with embedded font
subsets, and every mark, rule and box is a vector shape, so file size and
visual quality are independent here.

## Standing rules

- **Nothing bleeds across the footer.** An earlier pass let a graphic run
  over the page number and it read as a mistake rather than a decision.
  Overlap is allowed and wanted, but only where a person would have made it:
  a marker over a word, a circle around a phrase.
- No progress dots, no swipe prompt, no logo, no icon sets, no stock or AI
  imagery.
- The document title typed on upload is displayed in the feed. Use the cover
  line, not a filename.
