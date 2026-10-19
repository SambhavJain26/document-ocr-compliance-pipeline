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
| Grouped list | `.group` `.checks` · `.checks--marked` |
| Claim | `.claim`, optionally `.lead-in` above |
| Figure | `.lead-in` `.fig` `.lead-out` |
| Payoff | `.head` `.pay` `.margin-note` |
| Close | `.close-lead` `.divider` `.turn` `.byline` |

**Grouped list is for one list split by severity across several slides.** Post 7
runs twelve flags over six slides in two groups. The `.group` label sits under a
rule heavier than the hairline between rows, so it reads as a boundary rather
than another row, and the numerals hold one left column on every slide of the
group, so a slide carrying no label still belongs to it. Label sentences are set
at turn size rather than as a `.head`, because they are sentences the writer
wrote and 18px furniture buries them.

**The numerals are one treatment across the whole list.** An earlier pass gave
the first group swiped numerals and the second plain ones, to carry the severity
split visually. Owner's call, 2026-08-03: all twelve read the same, and the
labels and their rules carry the split on their own. `.checks--marked` is
therefore a numeral treatment, not a severity signal — do not reach for it to
mean "worse". Post 1 keeps plain `.checks`, so the modifier is what a deck opts
into rather than something `.checks` does by default.

**Claim is a statement too long for `.lead` and too load-bearing for `.turn`.**
The band holds seven and a half lines of `.lead`, so a statement much past a
hundred characters needs eight and overruns. Dropping it to `.turn` is worse
than the overset: it makes a slide carrying a whole claim on its own the
quietest slide in the deck. `.claim` sits between them at 78px on a 96px
leading. Post 13's matched pair uses it on both halves, so the only difference
between those two slides is the words, with `.lead-in` above the first to
introduce the pair.

**Nothing in the system is raster.** A `.shot` image layout was built for post
13's receipt slide and removed the same day: owner's call, 2026-08-04, no
screenshots in these decks. Type is vector with embedded font subsets and every
mark is a vector shape, so the only bitmap in a rendered PDF is the grain tile.
If a deck ever needs an artifact again, state it in prose rather than drawing a
frame that imitates an interface — a post about not faking your evidence cannot
be the one that ships a mocked-up screenshot.

**A long line drops a size step rather than overrunning.** The display sizes
assume short lines. Past roughly forty characters `.close-lead` runs to five
lines at 112px, overruns the `.body--close` band and pushes the turn into the
byline — post 7's close did exactly that, and post 13's cover did the same at
`.display`. Drop one step, to `.lead` in both cases, and the slide gets the air
it was supposed to have. Everything else about the layout is unchanged.

**A mark cannot span a line break inside `.pen`.** `.pen` is an inline-block, so
a phrase too wide for the line wraps *inside* it while the stroke, positioned
against the box, covers only part. Post 13's cover struck a five-word quoted
question at display size and the stroke landed on line one alone. Mark one word,
or use `.nb`, or drop a size step. `.hl` is exempt: it paints as a background
and clones onto every line box.

**Figure is for a slide whose subject is a number.** The numeral runs at 208px
and the sentence framing it is deliberately quiet, so the number is read first
and the sentence only explains it. A statement layout cannot do this: its lead
and turn are sized for prose, and a figure set at prose size stops being the
point of the slide. `.lead-in` and `.lead-out` are the same treatment above
and below the figure, because they are one sentence either side of a number
rather than two voices. Post 4 opens on `$0.002` this way.

Annotation classes, usable inside any of them: `.hl` (marker),
`.pen--circle` / `--under` / `--strike` (inline pen marks), and `.sel` (a word
boxed with corner handles, once per deck on the cover).

**Every mark sits on a word.** A brace hung in the right margin was tried and
cut: at the sizes this deck runs, a mark floating outside the text block reads
as debris rather than as annotation.

**A circle goes on one word.** Stretched over a phrase it flattens into a wide
ellipse that overshoots the last word and cuts through the first, and it stops
looking drawn. Two of post 7's circles were pulled back to a single word for
this reason. If a phrase needs marking, that is what the marker is for.

**The marker swipe lives once, in `--swipe`.** Both things that paint it — a
highlighted phrase and a `.checks--marked` numeral — read the same custom
property, so they cannot drift apart. Note that its default placement is set
for prose, which has descenders and wants the swipe to overhang the baseline.
Lining figures have neither, so `.checks--marked` raises and grows the swipe;
without that it sits under the numeral as a faint underline rather than behind
it. The same correction is why the inverted slide restates it.

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
that is slide 6, the payoff; in post 4 it is slide 5, the question the whole
post hands to the reader; in post 7 it is slide 9, the thesis. Used more often
it stops being a spike and becomes a pattern, which reads quieter, not louder.

Post 13 is the one deck that inverts its **close**, and the reason is worth
keeping. That slide was to have been a screenshot of a real approval email, and
when the artifact was dropped the proof had to be stated in type instead. Left
alone it would have been another statement slide in a deck of statement slides,
so the inversion carries the weight the photograph would have. Invert a close
only when it is doing that job, not because it is last.

**A layout is not finished until its inverted colours exist.** Inverting post
13's close put a `.byline` on the dark ground for the first time and it vanished,
because `.byline` is ink and nothing had ever needed it otherwise. `.claim`,
`.group`, `.lead-in`, `.lead-out` and `.detail` were unhandled for the same
reason. Add a layout, add its `.slide--invert` line in the same pass.

The cover was briefly inverted too, to establish the dark ground before slide
6 used it. That was reverted: a light cover keeps the dark slide as the single
loudest frame in the deck. If slide 6 ever starts reading as a mistake rather
than as the payoff, the fix is to make slides 5 and 6 an obviously matched
pair, not to invert the cover again.

On an inverted slide the colour rule still holds: every word is one value
(`--paper`), and only annotations carry colour. Highlighted words go dark so
they stay legible on the gold swipe.

**The swipe also has to grow there, and flipping the colour alone is not
enough.** `.hl` is sized to overhang a word rather than to enclose it, so on
paper the uncovered ascenders are still ink on cream and read fine. On the
inverted ground they are dark ink on dark navy and disappear — post 4's slide 5
lost half of "cheap part" that way. The stylesheet raises and grows the swipe
on `.slide--invert` so it clears the cap height. Check any highlight that lands
on an inverted slide.

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

## Technical retrospective draft

`technical-retrospective-vendor-coi.html` is the hiring-focused retrospective,
with copy, caption and an internal evidence map in
`../technical-retrospective-carousel.md`. It is a draft, outside the original
15-post schedule. Do not publish or queue it without the owner's instruction.

Prepare the technical deck's fonts with `python scripts/prepare-carousel-fonts.py`
from the repository root, using the bundled Python with `fonttools`. This caches
official Fontshare Switzer 400-900 and Zodiak 800 italic under ignored
`tmp/carousel-fonts/`. The current CDN files carry the internal name `false`;
the helper repairs local name records to prevent PDF subset collisions. Font
binaries are not committed. The technical scope selects the cached families;
the existing posts retain their existing font declarations. Render and preview
helpers stop if this cache is missing.

Build with `node scripts/build-technical-retrospective.cjs`, then run
`scripts/generate-linkedin-carousel.ps1 -Name technical-retrospective-vendor-coi`.
Run `python scripts/verify-technical-retrospective.py` with bundled Python
(`pypdf`, `pdfplumber`, `pypdfium2`, Pillow). This checks ten pages, 810 x 1012.5
points, embedded Switzer/Zodiak without fallback, preserved text, text bounds,
privacy, absent links/attachments and one shared grain image. It renders every
page and a contact sheet under ignored `out/`. Review both views after changes.

The `.technical` scope adds connected architecture lanes, model/code columns,
schema and verification tables, numbered build/priorities, before/after issue
keys and an execution/output comparison. `rt-*` classes carry these layouts;
HTML contains content and classes only. SVG arrows avoid fallback glyph fonts.
Children do not flex-shrink because shrinking a text container can push its
painted text across the footer while its nominal box appears to fit.

For this retrospective, the owner's current direction supersedes the older
fixed-color and cover-only annotation restrictions: every annotation shape can
use blue or gold, selection boxes may appear inside the deck, and marks follow
meaning rather than a quota. `.hl--blue`, `.pen--gold`/`.pen--blue` and
`.sel--gold` are available within `.technical`, including contrast rules on
the dark page. The established posts are unchanged. Zodiak appears once on
the cover, and the single dark slide carries the intake-context failure.

Keep original fixture reports distinct from later targeted checks. The draft
labels implemented behavior, historical recorded results and proposed work
separately. Do not infer a general accuracy score or concurrency/crash safety
from these local tests.
