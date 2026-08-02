# Product Marketing Context

**Document version:** v2
**Last updated:** 2026-08-02

Drafted from `docs/customer-language.md`, `docs/linkedin-content-plan.md`, `docs/how-the-system-works.md`, `docs/demo-script.md`, and `progress-notes.md`. Owner to correct.

## Product Overview

**One-liner:** Custom AI automation, built and implemented inside a property management company's existing business.

**What it does:** I take one repeated administrative process inside an operating business and build automation that runs it, using the mailbox, database, and steps the team already has. The client owns the result. There is nothing to log into, no seats, and no subscription.

**Product category:** Custom automation services / implementation, not software. Buyers may first encounter me while researching a software category (vendor compliance, COI tracking), so the category has to be named and then departed from in the same breath.

**Product type:** Service. Scoped build, implemented in the client's own environment.

**Business model:** Per-engagement. Not stated publicly yet. The only public offer is a free diagnostic: send ten vendor certificates, get back a one-page picture of what is current, what has lapsed, what is missing, and what needs a look. No system access required.

## Target Audience

**Target companies:** US residential property management companies, roughly 150–600 doors. Large enough that vendor paperwork is a recurring job for someone; small enough that no one has bought an enterprise compliance platform.

**Decision-makers:** Owners and operations leads. Note the split: the person who feels the pain is usually an office administrator, not the buyer.

**Primary use case:** Vendor certificate of insurance tracking and chasing, as the worked example. The general use case is any deadline-attached paperwork loop that currently lives in a spreadsheet, an inbox, and somebody's memory.

**Jobs to be done:**
- Know, today, which vendors have current paperwork on file, without spending an afternoon opening PDFs.
- Chase renewals without anyone having to remember to.
- Keep the vendor relationship intact while doing both.

**Use cases:** Certificate intake from a mailbox, extraction of printed facts, deterministic checking against per-trade requirements, a register with a source document one click away, daily watch for missing/expiring/lapsed paperwork, drafted reminder emails held for human approval, escalation after two ignored requests.

## Personas

| Persona | Cares about | Challenge | Value we promise |
|---|---|---|---|
| Owner / principal | Risk landing on the portfolio, and cost of headcount | Cannot see whether vendor paperwork is current without asking someone | A register that answers the question in one screen, and paperwork that chases itself up to the point a person has to sign off |
| Operations lead | The week not falling apart | Renewals get missed in busy months; follow-ups are invisible work | The follow-ups happen on schedule and the state is visible |
| Office administrator (user, not buyer) | Not being buried | Opening PDFs, typing dates, sending the third reminder | The typing goes away; the judgment stays with them |
| Vendor (non-buyer, affects adoption) | Getting paid, not doing admin | Portals they must register for and navigate | Nothing to adopt. They reply to an email like they already do |

## Problems & Pain Points

**Core problem:** Certificates expire quietly because nobody set up expiration tracking. The register drifts out of date, and nobody notices until someone asks a simple question.

**Why alternatives fall short:**
- Every product in the category is a portal. The category's own documented failure is that vendors find portals cumbersome, get discouraged, and stop cooperating, which sours the working relationship.
- Property management software has a field for vendor insurance. The field is not the problem; keeping it current is, and that still means someone opening PDFs and typing dates.
- Spreadsheets, shared drives, and email requests are the actual tooling in most offices at this size.

**What it costs them:** Repeated four-minute tasks that never appear on anyone's list, plus the afternoon it takes to answer "which vendors are current today."

**Emotional tension:** Property managers are not trained in insurance. They are often unsure whether a certificate actually meets requirements, and there is no comfortable way to ask.

## Competitive Landscape

**Direct:** myCOI, NetVendor, VendorAccess, BCS, SmartCompliance, ExpiryEdge, Jones, Vertikal RMS, Lula. All portals. Falls short because the vendor has to adopt something, and vendor cooperation is the failure point.

**Secondary:** The vendor insurance field inside property management software (Buildium, RealPage, AppFolio). Falls short because it stores a date nobody updates.

**Indirect:** A spreadsheet and a calendar reminder, or hiring another admin. Falls short at the third follow-up.

## Differentiation

**Key differentiators:**
- No system for anyone to adopt. It runs in the mailbox the vendor already emails.
- Built inside the client's business, on infrastructure they own, exportable and transferable.
- Reading and deciding are separate. A model transcribes what the document says; fixed rules decide what happens. Nothing consequential is decided by a model.
- Nothing leaves without a person approving that specific message.
- Refuses to make claims it cannot support. Four words are blocked from anything the system renders, enforced by a build check.

**Why customers choose us:** They get the problem handled without adding a login, a seat, or a monthly fee, and without asking their vendors to learn anything.

## Objections

| Objection | Response |
|---|---|
| Does this tell me whether a vendor is actually insured? | No, and nothing that reads a certificate can. It tracks the paperwork and the dates. Policy status belongs with the agent or carrier. |
| What if it reads a document wrong? | The row goes to review instead of getting a number typed into it, and the source PDF sits on every row so extraction is checkable. |
| We already have this in our property management software. | The field is not the problem. Keeping it current is. This is the part before the field. |
| Will it email my vendors without me knowing? | No. Every outbound message waits for a person to click approve. |
| No clients, no case studies, and you are not from this industry. | True. Which is why the offer is a diagnostic on ten of your own certificates rather than a contract. |

**Anti-persona:** Anyone who wants a tool to decide vendor eligibility, dispatch, or tenant outcomes. Anyone under ~100 doors, where the volume does not justify a build. Anyone who wants a product to resell.

## Switching Dynamics

**Push:** Missed renewals in busy months. Follow-up work nobody can see. Vendors annoyed by being asked repeatedly.
**Pull:** A register that is current without anyone maintaining it, and reminders that go out on time with a person still holding the pen.
**Habit:** The spreadsheet works well enough on a calm week, and the cost is spread across dozens of four-minute tasks that never get counted.
**Anxiety:** Emailing real vendor documents to a stranger overseas. Automation contacting vendors unsupervised. Being locked into another vendor.

## Customer Language

**How they describe the problem (from secondary sources, tonally unverified):**
- Certificates "expire quietly because no one set up expiration tracking"
- "buried in spreadsheets, emails, and follow-up work"
- "manual tracking, repeated follow ups, rework, and approval delays"
- "renewals stalling"
- "coverage gaps still slip through"
- vendors "discouraged by a cumbersome compliance process" which "sours the working relationship"

**Words to use:** COI (unexpanded), doors, lapse, the file / on file, vendor compliance, vendor credentialing, ownership groups, coverage limits.

**Words to avoid:**
- **Banned outright, in any claiming sense:** compliant, verified, covered, approved. These fail the build if rendered.
- **Worn out by the category:** streamline, centralize, seamless, end-to-end, "compliance made easy."
- **Hype:** game-changer, unlock, leverage, powerful, robust, revolutionize.
- **Never:** "units" for portfolio size.

**Glossary:**
| Term | Meaning |
|---|---|
| COI | Certificate of insurance. Never expanded in copy for this audience |
| doors | Unit of portfolio scale |
| lapse | What a certificate does at expiry |
| holder | The legal entity named as certificate holder |
| the file | Where documents conceptually live |
| chase | The act of requesting updated paperwork |

## Brand Voice

**Tone:** Incident report. The register of a well-written post-mortem: investigate, report precisely, state impact without drama, never oversell.

**Style:** Short declaratives, varied sentence length, real numbers, understated conclusions, first person singular, US spelling. At most one em dash per piece. No emoji, no broetry, no rhetorical-question openers.

**Personality:** Precise, restrained, self-correcting, plainspoken, unbothered.

## Proof Points

**Metrics:** None from clients. There are no clients. Every number in copy must trace to a repo file or a cited external source.

**Evidence available instead:**
| Theme | Proof |
|---|---|
| Reading and deciding are separate | `scripts/lib/coi-stage-4-validator.js` holds the rules; the model only transcribes |
| Honest claims are enforced, not intended | Forbidden-word check in `scripts/verify-stage-7-dashboard.ps1` plus a runtime guard that throws |
| Nothing sends unsupervised | Approval gate in the Stage 6 workflow; requests expire at 24 hours rather than sending |
| Problems get found and fixed in the open | Issue-key defect and fix, commit `0fcd62d`, `db/postgres/004-stage-6-watch-chase.sql` |
| Silent failure is the real risk | 17 of 18 vendors silently paused, found only after adding a dashboard column, `progress-notes.md` |
| Domain literacy | NY DFS certificate filing and Texas DOI certificate FAQ, cited in `docs/demo-script.md`; risk-transfer detail in `foundation-1-vendor-insurance.md` |
| AI buying literacy | The model transcribes and fixed rules decide (`docs/how-the-system-works.md`); extraction costs ~$0.002 per certificate (`01-vendor-coi-chase.md`); the approval gate and its 24-hour expiry |

## Content principles

Two rules learned the hard way on 2026-08-02, after an audit found seven of fifteen planned posts failed them.

**Recognition is not value.** A post whose payoff is that a property manager recognizes their own week teaches them nothing they don't already live. Describing the buyer's job back to them reads as proof that I understand it, which serves me rather than them. Every piece has to leave the reader holding something they didn't have.

**Teaching belongs in the high-effort formats.** Carousels and video get saved, referred and shared, so they carry the teaching. Positioning, proof of work and operating-model material go in text, where low reach costs nothing. The first content plan had this backwards.

**A corollary on audience.** Comments drive distribution and *who* comments decides who sees a post next. With a network of engineers, optimizing for engagement volume makes the audience problem worse. Six comments from property managers beat sixty from developers.

**The strongest available angle** is not "I know property management," which is unprovable and unearned. It is "I build AI systems, and these buyers are being pitched AI by everyone with no way to evaluate any of it." That asymmetry is real, current, and mine to teach into honestly.

**Testimonials:** None. Do not imply any.

## Goals

**Business goal:** First paying client from the target segment.

**Conversion action:** The diagnostic. Ten vendor certificates, one page back.

**Current metrics:** LinkedIn network is mostly engineers, not buyers. Audience shift is the near-term objective.

## Changelog

- v2 (2026-08-02) — Added a Content principles section and an AI buying literacy value theme after a content audit found that seller-centric material had been placed in the highest-reach formats. Removed the uncited 2010 ACORD revision from the domain-literacy proof row.
- v1 (2026-08-01) — Initial context, drafted from repo docs for the LinkedIn content work.
