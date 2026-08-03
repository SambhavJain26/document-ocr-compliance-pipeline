---
name: linkedin-carousel
description: Build a LinkedIn document carousel from the finished copy in docs/linkedin-post-scripts.md using this repo's fixed HTML template, and render it to an upload-ready PDF. Use this whenever the user asks to build, render, design, lay out, fix or restyle a carousel, a document post, a deck or its slides — including when they name a post number from the content plan (1, 4, 7 and 13 are the carousels), mention the cover slide, the payoff slide, the annotation marks, the grain, or the carousel template, or ask why a slide looks wrong. Use it even if they never say the word "carousel"; if the work touches docs/carousels/, this skill applies.
---

# Building a LinkedIn carousel

You are turning finished copy into an eight-ish page PDF at 1080x1350, uploaded
to LinkedIn as a document post. The writing is already done and signed off. Your
job is layout, annotation, and getting it to render cleanly.

## Read these first

Three files, in this order. Do not skip the second one — this skill deliberately
does not restate the design system, because a copy would drift out of sync with
the stylesheet that actually governs it.

| File | What it gives you |
|---|---|
| `docs/linkedin-post-scripts.md` | The copy for every post, slide by slide, plus a production note per post recording decisions already made about how that specific deck should look |
| `docs/carousels/README.md` | **The design system.** Palette and the rule governing where colour may appear, the two typefaces, the layouts, the annotation vocabulary, the baseline grid, and the standing rules. Source of truth |
| `docs/carousels/post-01-what-ai-should-touch.html` | The only built deck. Clone its structure — the head, the slide shells, the footer, and the baseline-snap script at the foot |

The production note in the script is not advisory. When post 1's note says slide 6
is the shortest by design and should get the most air, that is a decision someone
already made about the argument, and the layout has to honour it.

## The copy is final

You may **line-break** a sentence, **split a run of items** into list elements,
and **choose which phrase carries a mark**. Those are formatting decisions.

You may not change a word, reorder a sentence, add a connective, or trim to fit.
Every post has been checked against a banned-word list, an em-dash budget, an
AI-writing-tells pass and a 210-character fold. Editing to make the layout easier
silently breaks checks you cannot see.

If copy genuinely will not fit a slide, that is a layout problem. Reduce the type
step, or say plainly that the slide is overset and let the user decide.

## Workflow

1. **Read the post's slides and its production note.** Note the framework
   (Value-Stack, Problem-Proof) — it tells you what the cover promises and what
   the last slide has to deliver.
2. **Map each slide to a layout** (see below).
3. **Write the HTML.** Content and layout classes only. Never a `style`
   attribute, never a `<style>` block, never a new class the stylesheet does not
   define.
4. **Copy the baseline-snap script verbatim** from the foot of post 1 into the
   new file. Without it the centred content lands off the ruled grid.
5. **Preview and actually look at it** (see the verify loop).
6. **Fix and re-render** until it holds.
7. **Render the PDF** with `.\scripts\generate-linkedin-carousel.ps1`.
8. **Verify the PDF** — page count, dimensions, embedded fonts, image count.
9. **Update `docs/carousels/README.md`** if you added a layout or changed a rule,
   then commit.

## Mapping slides to layouts

Read a slide's copy and ask what shape it is. The layouts and their classes are
listed in `README.md`; this is how to choose between them.

| The copy looks like | Layout |
|---|---|
| Two beats, split by a blank line in the script | **Statement** — `.lead` `.divider` `.turn` |
| A statement then a run of short nouns | **Field list** — `.lead` `.tags` `.divider` `.turn` |
| Numbered conditions or checks | **Check list** — `.head` `.checks` |
| A heading and a one-word answer | **Payoff** — `.head` `.pay` `.margin-note` |
| First slide | **Cover** — `.display` `.kicker` |
| Last slide | **Close** — `.close-lead` `.divider` `.turn` `.byline` |

**When no layout fits, add one.** Post 4's arithmetic and post 7's twelve flags
split into two severity groups will both need something new. Add a named layout
to `carousel-template.css` and document it in `README.md` so the next post
inherits it. Do not solve it inline in the post HTML — the stylesheet is the only
place sizes, colours and spacing live, and a post that breaks that rule forks the
design without anyone noticing.

## Choosing the marks

This is the actual craft, and it is where a deck either reads as designed or as
decorated. The marks are the argument made visible: a reader should be able to
skim only the marked words and come away with the post.

- **Marker** (`.hl`) — the load-bearing phrase, the thing the slide turns on.
  This is the deck's most-used signal and it should mean exactly one thing
  throughout.
- **Circle** (`.pen--circle`) — a word held up for scrutiny.
- **Underline** (`.pen--under`) — affirmation.
- **Strike** (`.pen--strike`) — negation.
- **Selection box** (`.sel`) — once per deck, on the cover, on the word the whole
  post is about.

Four rules that come from real mistakes:

- **Parallel copy gets parallel marks.** Mirrored sentences take the same device.
  Give each one a slightly different hand-drawn path, though — every stroke in
  the deck should be unique, because a person drew them.
- **Every slide carries at least one mark.** In a deck whose identity is the
  annotation layer, a bare page reads as something forgotten.
- **Two marks per slide is the ceiling.** The cover can take three because it
  works hardest.
- **A device used once is an exception, not a system.** If you find yourself
  adding a mark type for a single instance, either use it again or drop it.

## The verify loop

Render, look, fix. Do not skip the looking — every defect in the first build of
this template was caught by eye and none of them by reasoning about the CSS.

```bash
.\scripts\preview-carousel.ps1
```

```bash
.\scripts\preview-carousel.ps1 -Slide 6
```

Then read the PNG it writes. **Look at both views.** A contact sheet shows
composition, rhythm and whether slides are crowded, but it hides clipping, low
contrast and misplaced marks. A full-size slide shows the marks but tells you
nothing about how the set reads. Things have repeatedly looked fine in one and
broken in the other.

Check for:

- Punctuation sitting apart from the word before it
- A mark landing on the wrong word, or floating away from its line
- Type running off an edge, or a word clipped by its own circle
- A slide noticeably fuller or emptier than its neighbours
- Text drifting off the ruled lines
- Anything crossing the footer band

## Failure modes

Each of these happened during the first build. The symptom is what you see; the
cause is rarely what you would guess from it.

**Punctuation detaches after a highlighted phrase.** `.hl` adds horizontal
padding so the swipe overhangs the glyphs; that padding must be cancelled by an
equal negative margin or it shoves the next character sideways.

**A sentence in a list tears in half.** A flex container turns an inline `.pen`
span into its own flex item. Position the numeral instead of flexing the row —
`.checks` shows how.

**A grid becomes visible across the page.** The grain tile carries large-scale
light and dark regions and they repeat. The tile must be high-passed: subtract a
heavily blurred copy so only fine noise survives.

**The PDF comes out at 20 MB or more.** The grain is an `feTurbulence` filter.
Filters are evaluated at output resolution, so Chrome bakes a full-page bitmap
into every slide. It must be a baked PNG tile, embedded once and repeated. This
is a 185x difference for identical output.

**The render writes nothing and reports no exit code.** `chrome.exe` was invoked
directly, so the command line went to an already-running Chrome. Use
`Start-Process -Wait -PassThru` with a throwaway `--user-data-dir`, as both
scripts do.

**Comment text turns to mojibake after a scripted edit.** PowerShell's
`Set-Content` rewrote the file in the wrong encoding. Read and write with
`[System.IO.File]::ReadAllText/WriteAllText` and an explicit
`UTF8Encoding($false)`.

**Type sits off the ruled lines.** A leading is no longer a multiple of the 24px
baseline unit. Changing any type size means checking its leading still divides.

**Content is stranded in the upper third with a dead page below.** The content
block is centred in a bounded band, not top-anchored. If a slide looks
top-heavy, the copy is short and the type is too small, not misaligned.

**Everything renders in a system serif.** The webfonts did not load. Both faces
come from `api.fontshare.com` at render time and a failed fetch falls back
silently rather than erroring.

## Finishing

Render the PDF, then verify it rather than assuming:

```bash
.\scripts\generate-linkedin-carousel.ps1
```

Confirm the page count matches the slide count, the MediaBox reads
`0 0 810 1013` (that is 1080x1350 at 96dpi), the font subsets are embedded, and
there is exactly **one** image object — more than that means the grain has
regressed to a filter.

Tell the user two things when you hand it over. LinkedIn asks for a **document
title** on upload and displays it in the feed, so it should be the cover line
rather than a filename. And the post copy that sits above the document is in the
script file, already checked; it is part of the deliverable.

`docs/carousels/out/` is ignored build output. The HTML and the stylesheet are
the source of truth, so commit those and leave the PDF out.
