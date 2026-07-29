# Decision Log

**Document 11 · Every choice this blueprint closed, and why**

The build plan left several things open. This document closes them so no developer has to re-derive an architectural decision mid-build. Each entry states the decision, the alternatives rejected, the reason, and what would make it worth revisiting.

**If you disagree with one of these, change it here first, then in the stage document.** A decision changed in code but not here becomes folklore within a month.

---

## D-01 · Provider: OpenAI only

**Decision.** Every model call goes to OpenAI. No Anthropic, no fallback provider, no abstraction layer.

**Rejected:** Anthropic; a provider-switching abstraction.

**Why.** Directed by the project owner, and independently the better fit here. Strict Structured Outputs (`text.format` with `strict: true`) constrains generation at decode time — output that violates the schema is not merely unlikely, it cannot be produced. For a demo that must not break in front of a prospect, a hard guarantee beats a strong tendency, and it lets you delete defensive parsing and shorten the system prompt.

A provider abstraction is production scope at best and probably never. Two providers means two sets of payload shapes, two response parsers, and two things that can be subtly wrong. Build one, well.

**Revisit if:** OpenAI retires the mini tier entirely, or a client contractually requires a specific vendor.

---

## D-02 · Responses API, not Chat Completions

**Decision.** `POST /v1/responses`.

**Rejected:** `POST /v1/chat/completions` (which the build plan sketched).

**Why.** Three things Responses gives you that Chat Completions does not, all of which matter to this build:

1. **`detail` control on PDF file inputs.** The vision branch reads skewed phone photos — that is the whole job on that branch. Chat Completions gives you no control and picks for you.
2. **`reasoning: { effort }` as a first-class parameter**, so the text branch can run fast and the vision branch can run careful.
3. **Refusals as a typed `refusal` content part**, detectable without string matching.

**Cost.** Parsing requires walking an `output[]` array rather than reading `choices[0].message.content`. Paid once, in `03_parse_response.js`.

---

## D-03 · Pinned dated snapshot in the database

**Decision.** `gpt-5.4-mini-2026-03-17`, stored in `client_config.model_id`, never in a node.

**Rejected:** the floating `gpt-5.4-mini` alias; hardcoding the ID in workflow JSON.

**Why.** OpenAI's lineup moves fast — GPT-5.4, 5.5, and the 5.6 family shipped inside roughly four months, and several older IDs came off the pricing page in that window. A floating alias will move under you, and you will find out when a client's certificates stop processing.

Putting the ID in `client_config` makes a retirement a one-row `UPDATE` rather than an edit across four workflows. Combined with the canary job, a dead model ID becomes a Monday-morning alert instead of a mid-call surprise.

**Fallback if the snapshot is retired:** `gpt-5.6-luna` ($1.00 / $6.00 per MTok). Re-verify pricing before switching.

---

## D-04 · Email approval by default, Telegram as a bonus

**Decision.** Gmail's `Send and Wait for Response` is the default gate. Telegram is a parallel branch selected by `client_config.approval_channel`.

**Rejected:** Telegram as the primary gate.

**Why.** Telegram is more theatrical; email is more reliable. Telegram has low US business penetration, and asking a property manager to install an app before a sales call is real friction that some will simply decline — killing the demo's best moment. Email approval renders the same Approve/Decline buttons in any mail client with no install and no account, and it is what a real client would actually use day to day, so it survives into production rather than being a demo gimmick.

**Never make the emotional peak of your demo depend on a prospect installing software.**

---

## D-05 · Two branches, not one

**Decision.** Text branch when the extracted text layer exceeds 200 characters; vision branch otherwise.

**Rejected:** always sending the PDF as a file (simpler, one code path).

**Why.** OpenAI extracts both the text layer and page images from any PDF input and sends both — roughly doubling input tokens for a document that already has clean text. The money is irrelevant at this volume; **latency is not.** The text branch returns in about a third of the time, and during a demo that is the gap between "there it is" and an awkward pause.

**The 200-character threshold** is comfortably below a real certificate's 1,500–2,500 characters and comfortably above the stray filename or date stamp some scanners bake into an otherwise image-only PDF. A `> 0` check routes those to the text branch and extracts garbage.

---

## D-06 · Bucketing in SQL views, not in a Code node

**Decision.** `v_vendor_status` computes bucket, colour, and days-to-expiry. Both Workflow 2 and Workflow 3 read it.

**Rejected:** computing buckets in JavaScript in each workflow.

**Why.** Two consumers with two implementations eventually disagree about what "expiring" means, and the disagreement surfaces as a vendor who is amber on the dashboard but never enters the chase queue. One definition, one place.

It also puts date arithmetic in the system best at date arithmetic. `expiration_date - today` in Postgres is a `DATE` subtraction; the same thing in JavaScript is a `Date` object, a timezone, and a rounding decision.

---

## D-07 · `&` folds to a space, not to "and"

**Decision.** `normaliseName` replaces every non-alphanumeric character with a space. `Heating & Air` → `heating air`.

**Rejected:** expanding `&` to `and`.

**Why.** Both `Heating & Air` and `Heating and Air` are common on real certificates. Folding `&` to nothing makes them score ~0.87 on token-set ratio — landing in the **review band** rather than either silently merging or silently splitting. That is the correct outcome: a human decides.

Expanding to `and` would make them match exactly, which is right about half the time and silently wrong the other half.

---

## D-08 · No `UNIQUE` constraint on `vendors.normalised_name`

**Decision.** An index, not a unique constraint. Near-duplicates (0.80–0.94) are a hard flag routed to human review.

**Rejected:** a unique constraint with auto-merge on conflict.

**Why.** "Mercer Plumbing" and "Mercer Plumbing & Heating" may be two different companies. A unique constraint turns that ambiguity into either a crash or a silent wrong merge — and a silent wrong merge files one company's certificate against another company's record, which the dashboard renders as a perfectly normal green row.

The failure is invisible and it is exactly the kind of thing a client discovers at the worst moment.

---

## D-09 · New vendors default to trade `DEFAULT`

**Decision.** A vendor created from an extraction gets `trade = 'DEFAULT'` and default limits. Trade assignment is a human task.

**Rejected:** inferring the trade from the company name.

**Why.** "Vaughn Electric" → Electrical works until "Bright Electric Cleaning Services" arrives and gets held to electrical limits. Trade assignment is a 30-second onboarding task; getting it silently wrong generates confident false flags.

**Nothing destroys trust in an automated system faster than confident wrong alerts.** The same reasoning is why rule 10 suppresses workers-comp checks for exempt sole proprietors.

---

## D-10 · Content-addressed PDF storage with a unique hash index

**Decision.** `/data/certs/YYYY/MM/<sha256>.pdf`, with `UNIQUE` on `certificates.content_sha256`.

**Rejected:** sequential filenames; idempotency deferred to production.

**Why.** The build plan deferred idempotency, which is defensible for a demo and wrong in practice: you run the same fixtures dozens of times in Stage 8, and a duplicate-row bug costs an afternoon. Content addressing gives idempotency, deduplication, and integrity verification in four lines.

The `xmax = 0` return value distinguishes an insert from an update, so a re-delivered email updates the row silently instead of announcing a "new certificate" that is not new.

---

## D-11 · `dead_letter` table, added to the schema

**Decision.** Every rejected document writes a row.

**Rejected:** notifying the manager and moving on (the build plan's implicit behaviour).

**Why.** The rule is that nothing is ever silently dropped. Without a table, a rejected document produces a Telegram message and no record — and a Telegram message is not a record, it is a notification that scrolls away.

It also makes the Stage 8 harness able to assert on rejection outcomes rather than just on absence, which is the difference between "no certificate was created" and "the right thing happened".

---

## D-12 · Log the outreach row *before* the approval prompt

**Decision.** `INSERT INTO outreach_log` runs before `Send and Wait`, not after approval.

**Rejected:** logging after a successful send.

**Why.** Two reasons. The `ux_outreach_daily` unique index only prevents a duplicate if a row exists when the second run reaches that node — logging after approval leaves a 24-hour window in which the same draft generates twice. And a declined or abandoned draft is a fact worth keeping: *"we drafted this and the manager declined it on 14 March"* is exactly what a client asks about six weeks later.

---

## D-13 · Never fetch a link that arrived by email

**Decision.** Portal-link emails are detected, labelled, and handed to a human. No HTTP request is ever made to the URL.

**Rejected:** fetching the certificate from the agency portal automatically.

**Why.** This is a security boundary, not a feature gap. Fetching it means an unauthenticated request to an attacker-controllable URL, from inside the client's network perimeter, triggered by anyone who can email the intake address. That is a server-side request forgery primitive handed out for free.

It would also usually fail — those portals require a login — so the risk buys nothing.

---

## D-14 · Hand-built HTML dashboard

**Decision.** One HTML document generated by a Code node, served through a Webhook.

**Rejected:** NocoDB, Metabase, Appsmith, EspoCRM, Retool, n8n's Data Table node.

**Why.** Each alternative gives you filtering and sorting you do not need for a four-minute demo, and takes away the thing you do need: a screen that looks like a product built for property managers. One page has no licence question, no extra container to keep alive on stage, and no chance of an unfamiliar admin UI surprising you mid-call.

**In a demo, controlling every pixel is worth more than any feature these give you.** It is also ~200 lines, which is less than the time spent configuring any of them.

The forbidden-word constraint is the deciding factor. A third-party admin panel renders whatever column names you give it, and eventually someone adds a "Status: Valid" badge because the tool makes it easy. A hand-built template can be tested.

---

## D-15 · Postgres over Google Sheets or n8n Data Table

**Decision.** PostgreSQL 16 in Docker, two databases on one server.

**Rejected:** Google Sheets; n8n's native Data Table node.

**Why.** Sheets adds a Google OAuth dependency and makes *"where does my data live?"* a worse answer. The Data Table node is genuinely appealing — native storage, no external service — but its query semantics were not verifiable well enough to commit a live demo to, and real SQL is what makes `v_vendor_status` possible in the first place.

**Two databases, one server** matters: `make demo-reset` truncates COI tables, and a mistyped database name should not be able to wipe your workflows mid-call.

---

## D-16 · Both `WEBHOOK_URL` and `N8N_EDITOR_BASE_URL`

**Decision.** Set both, to the same public HTTPS root, with a trailing slash.

**Why.** The build plan named `WEBHOOK_URL` and `N8N_HOST`. Community reports of send-and-wait approval links containing `localhost` trace to `N8N_EDITOR_BASE_URL` being unset — send-and-wait builds its resume URL from a different code path than the Webhook node's displayed URL.

**This single line is the difference between the approval button working and 404ing on the call.** It is also why Stage 1's gate tests the send-and-wait link specifically, not just webhook reachability.

---

## D-17 · Google OAuth app published, not left in Testing

**Decision.** Publish the consent screen.

**Why.** An app in Testing status issues refresh tokens that expire after **7 days**. The Gmail Trigger works perfectly for a week, then silently stops polling. No error surfaces until you open an execution.

That is the exact silent failure this product exists to prevent, arriving in your own infrastructure. Publishing costs two minutes and one "unverified app" interstitial you click through.

---

## D-18 · Postgres in UTC, day counts from `client_config.timezone`

**Decision.** Three clocks, each with one job. `v_today` converts `now()` to the client's calendar date once; every other view joins to it.

**Rejected:** `CURRENT_DATE` in queries.

**Why.** `CURRENT_DATE` is the server's date. At 21:00 in New York the server is already on tomorrow, and every day count on the dashboard is off by one — a bug that appears only in the evening and vanishes overnight. `verify.sh` greps for `CURRENT_DATE` and fails on a hit, because that is a bug you would otherwise chase for hours.

---

## D-19 · Fixtures are date-relative and generated from a spec

**Decision.** Offsets from generation day, not absolute dates. Regenerated by one command.

**Rejected:** hand-made PDFs with fixed dates.

**Why.** "Expires in 20 days" must be true whether you demo tomorrow or in September. Absolute dates go stale silently and you find out when the amber row renders green in front of a prospect.

The `manifest.json` recording **resolved** dates is what lets the Stage 8 harness assert against a value rather than re-deriving it from offsets — otherwise you are testing your test.

---

## D-20 · Layout-similar fixtures, never facsimile

**Decision.** Same field names and tabular structure, own visual design, `SPECIMEN` watermark, fictional carriers, `.example` domains. No ACORD logo, form number, or copyright notice. Written marketing says "standard certificate of liability insurance forms".

**Why.** ACORD forms are copyrighted and licensed rather than sold. Reading a certificate a vendor sent your client is not a licensed activity. **Manufacturing replicas of the blank form is a different thing**, and committing them to a repo or shipping them in a proposal deck is where it bites.

The mitigation costs nothing, so take it. Saying "ACORD 25" verbally on a call is ordinary industry shorthand and is fine.

---

## D-21 · Vendor emails send from the client's mailbox, always

**Decision.** `from_mailbox` is the client's address. Never yours.

**Why.** Three reasons that all point the same way:

- **CAN-SPAM.** A renewal request to an existing vendor is transactional relationship content, which is why it lands in the exempt category — and that exemption depends on the message not carrying misleading routing information.
- **Deliverability.** You have no SPF/DKIM relationship with the vendor's mail server. Mail from an unrelated domain about a policy held by a plumber for a property manager will be filtered.
- **It is their relationship.** A vendor receiving mail from a name they do not recognise, about their insurance, will call the client to ask what is going on.

---

## D-22 · Two attempts, then a human — enforced by `awaiting_reply`

**Decision.** A vendor receives at most `max_chase_attempts` (default 2) requests per bucket, each through the approval gate. A 07:30 sweep runs **before** the 08:00 chase and either releases the vendor for their next attempt or escalates and sets `chase_paused = true`.

**Rejected:** escalating after the first unanswered request; increasing reminder frequency; escalating to SMS.

**Why.** Two separate reasons, and the second one was a genuine defect.

**① The claim has to be true.** The source document specifies escalation "when a vendor ignores two requests", and it is a line you say out loud at 3:20 in the demo. An earlier design escalated after one. In a product whose entire positioning is honesty about its own limits, a sales line the code does not honour is not a corner worth cutting.

**② Without `awaiting_reply`, the chase queue re-emailed daily.** The original guard excluded only vendors contacted *today*, so an expired vendor would have been emailed **every single morning** until they replied. A daily email to the same insurance agent, sent in your client's name, is the fastest possible way to make your client look incompetent to their own vendor — the precise opposite of what they are paying for. The `awaiting_reply` flag holds a vendor out of the queue for the whole reply window.

**Two ignored requests escalate to a human. They do not escalate to more automation.** And a vendor who *has* sent their certificate is closed out on intake, so they can never be escalated for ignoring a request they answered.

---

## D-28 · Every config key must be read by something

**Decision.** `reminder_days = '60,30,14,0'` is replaced by `reminder_d60` / `reminder_d30` / `reminder_d14`, read by `v_thresholds` and joined into `v_vendor_status`. `pdf_retention_months` is enforced by a monthly purge workflow. `max_chase_attempts` drives the chase and sweep queries.

**Rejected:** parsing the comma string in SQL; leaving the keys as documentation.

**Why.** All three were seeded and read by nothing. The bucket thresholds were hardcoded in the view's CASE, and the retention window was a promise with no implementation.

**A config key nothing reads is worse than no key at all** — it is a setting you will describe to a client in a config interview, that they will believe they can change, and that does nothing. You would find out when they ask why the cadence did not change.

Three explicit integer keys beat parsing `'60,30,14,0'` inside a view: readable, individually tunable, and type-checked by `value::int`.

The retention job **keeps the certificate row and deletes only the PDF.** The register, extracted data and outreach history remain — the audit trail is the product — while the one thing you promised to delete is deleted. The dashboard renders those rows as `not retained` rather than a broken link, because a broken link reads as *the system lost my document* and `not retained` reads as *the system did what it said*.

---

## D-23 · The drafting model receives a curated fact set

**Decision.** `06 Bucket Context` builds a small explicit object. The model never sees the raw row.

**Why.** Anything absent from that object cannot appear in the email. It is a structural constraint rather than a prompt instruction, and structural constraints do not drift.

Combined with the draft prompt's rule 3 and the SQL forbidden-word check over `outreach_log`, that is three independent layers stopping a coverage claim reaching a vendor's inbox — which is where an overclaim would do the most damage, because it lands in a third party's records over your client's name.

---

## D-24 · The footer disclaimer lives in the template

**Decision.** The "records what the certificates say" paragraph renders on the dashboard itself.

**Rejected:** stating it only in the proposal and on the call.

**Why.** The dashboard is the artefact a prospect screenshots and forwards to their business partner. That screenshot travels without you, without your scope document, and without the sentence you said about endorsements. Putting the limitation on the page means the caveat travels with the claim.

It costs nothing in the demo — nobody reads a footer during a four-minute call — and it is the single most useful thing on the page if the screenshot ever ends up in a dispute.

---

## D-25 · SQL and JavaScript normalisation duplicated, guarded by a test

**Decision.** The same normalisation exists twice — in `seed-vendors.sh` and in `normalise.js` — with a test that runs 30 strings through both and fails on divergence.

**Rejected:** a Postgres function called from n8n; normalising only in one place.

**Why.** Seeding happens in SQL and matching happens in a Code node, and neither can call the other without adding a round trip on the hot path. Duplication with a test is the honest resolution.

If they drift, a seeded vendor stops matching the certificate that names them, a duplicate vendor is created, and the dashboard shows one vendor twice with half the data on each. Invisible until you look at the register — which is what you do during a demo.

---

## D-26 · Workflows authored as JSON, imported by CLI

**Decision.** Workflows live as JSON in `n8n/workflows/`, are validated, imported with `n8n import:workflow`, published with `n8n publish:workflow`, and take effect after a container restart. The editor UI is for inspection and for the OAuth consent flow only.

**Rejected:** building in the UI and exporting afterwards as the system of record.

**Why.** The UI is a fine sketchpad and a bad system of record. You cannot diff it, you cannot review a change, and *"I clicked something and now it works"* does not survive a rebuild on a new box. JSON in git gives you all three, and `make wf-import` makes a rebuild a single command.

**Round-trip after any UI edit** (`n8n export:workflow --all --pretty --separate`) and read the diff. It is how you catch the parameter you changed on a whim at 1am.

**Cost.** Hand-authored JSON has three fields that fail badly if omitted — a top-level `id`, a `webhookId` on webhook-based triggers, and `\\n` double-escaping in expressions. All three are in [§12.2](12-n8n-operations-cookbook.md), and the `webhookId` one silently 404s while the UI shows the workflow as active.

---

## D-27 · Script only the PostgreSQL credential

**Decision.** Only the `postgres` credential is generated from `.env` into a **temp path outside the repo**, copied into the container, imported, and deleted from both sides. OpenAI uses the owner's existing n8n-native `openAiApi` credential; Gmail OAuth2 is completed by hand in the UI.

**Why.** n8n encrypts on import using `N8N_ENCRYPTION_KEY`, so plaintext credential JSON is a legitimate input format — but there is no `.gitignore` entry that makes an accidentally-committed API key un-leaked. The file never exists inside the repo.

**OpenAI and Gmail credentials are user-managed.** The native OpenAI credential works with HTTP Request's predefined authentication, so a duplicate generic header credential adds a second place to maintain the same key. Gmail has no plaintext token to pre-author: its browser consent flow remains a human step.

The importer assigns the generated PostgreSQL credential to the owner's personal project with `--projectId`. On Git Bash, container-path commands opt out of MSYS path conversion; the cleanup trap removes the root-owned copied file as root. `make credentials-verify` checks encrypted PostgreSQL storage, owner-visible native credentials, and temporary-file removal without reading credential values.

---

## D-29 · The demo runs locally before production TLS

**Decision.** The first demo build runs n8n at `http://localhost:5678` with `DEPLOYMENT_MODE=local`. Public DNS, Caddy, and ACME are deferred until production deployment. `N8N_SECURE_COOKIE=false` is permitted only in local HTTP mode and must return to `true` behind production HTTPS.

**Why.** Localhost removes VPS and certificate work from the implementation loop while workflows, database behavior, and fixtures are still changing. It does limit phone testing and public approval/webhook links; those remain production gates rather than being falsely marked complete.

n8n 1.0 and later use the built-in owner account and no longer support the old `N8N_BASIC_AUTH_*` variables. The owner account is created in the UI on first launch. `DASHBOARD_TOKEN` is separate application-level protection for the dashboard and source-PDF webhook URLs; it is not an n8n login credential.

---

## Corrections this document set has already absorbed

Three defects found and fixed before any code was written. Recorded because the reasoning generalises.

| Defect | Why it mattered | Fix |
|---|---|---|
| Postgres parameters written as a comma-separated string | Splits on commas **inside values**. Certificate holder names and addresses are full of them. Would pass on tidy fixtures and fail on real client data — the worst possible failure profile. | `options.queryReplacement` as an array expression ([§12.7](12-n8n-operations-cookbook.md)) |
| Error Trigger read only `$json.execution.*` | A **workflow-activation** failure emits `{ trigger: { error } }` with no `execution` key. The alert telling you a workflow failed to come up would itself have been blank. | Read both shapes defensively ([§12.8](12-n8n-operations-cookbook.md)) |
| Bare `$json` downstream of Postgres and gate nodes | A Postgres node replaces the item's json with its query result; `Send and Wait` returns only `{ data: { approved } }`. The vendor email would have gone out with a blank Reply-To and signature — visibly broken, in the client's name, in a third party's inbox. | Bind context by node name: `const c = $('06 Bucket Context').item.json` |

The common thread: **all three pass on clean fixtures and fail on real data or real failure modes.** That is the class of defect a click-through demo rehearsal cannot find, and the reason Stage 8 exists.

---

## Open questions

Carried from the build plan's "could not verify" section. None blocks the demo; each matters before a paying client.

| # | Question | Blocks | Next step |
|---|---|---|---|
| O-1 | Does n8n's Sustainable Use License permit hosting several clients' pipelines on one instance you own? | Multi-tenant hosting only | Email `license@n8n.io`. Costs one email. **Mitigation already chosen:** host on the client's infrastructure — safer licence position *and* better sales position. |
| O-2 | n8n Data Table node query semantics | Nothing | Revisit for v2. Postgres is the known quantity. |
| O-3 | Will `gpt-5.4-mini-2026-03-17` still exist in six months? | Nothing today | The canary job answers it weekly. Fallback is `gpt-5.6-luna`. |
| O-4 | Rentec Direct / Rent Manager / Propertyware API tiers | Nothing | Deliberately not researched — the design needs zero PMS integration, so their terms cannot block a sale. Ask the qualifying question anyway; it tells you what you can sell them next. |

---

## Things deliberately left out of the demo

Each is a reason for a second conversation, which is exactly what you want.

| Capability | Why not now |
|---|---|
| Vendor self-service upload portal | Adds auth and a public surface. Zero demo value — the prospect is not the vendor. |
| W-9 and licence tracking | Obvious upsell. Adds document types and dilutes a demo that works because it is narrow. |
| Endorsement request workflow | Moves toward real verification. **Deliberately excluded** — it edges into the compliance-assurance positioning you must avoid until you have a track record. |
| PMS sync (read-only) | Requires Buildium Premium at $400/mo. Never make this a precondition. |
| SMS escalation | Requires A2P 10DLC registration, which needs a **US EIN** you do not have. Must be registered and billed under the client's entity. Production only. |
| Owner-facing compliance report | Strong retention feature and good phase-2 revenue. Not a demo feature. |
| Automatic carrier verification | Not buildable by you at all. Live policy status flows carrier → agency over rails like IVANS into agency management systems. Your client has no seat on that rail. The moat is not code — it is having signed up 25,000 insurance agencies. |
