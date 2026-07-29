# Vendor COI Chasing — Implementation Blueprint

**Document 00 — Index, conventions, and the rules that govern every other document**

---

## What this document set is

`coi-demo-build-plan.md` is the **strategy and research document**. It decides *what* to build and *why*, and it contains the sales material, the honesty constraints, and the demo script. It remains authoritative on all of that. Do not delete it, do not contradict it.

This document set is the **implementation blueprint**. It decides *how*, at the level of exact file contents, exact node parameters, exact SQL, exact JSON payloads, and exact acceptance criteria. Everywhere the build plan left a choice open, this set closes it and records the reasoning in [Document 11 — Decision Log](11-decision-log.md).

**A developer should be able to work from Stage 0 to Stage 9 in order and never need to invent an architectural decision.** If you find yourself deciding something, that is a defect in these documents — log it in `PROGRESS.md` under *Open Questions* and pick the option the Decision Log's stated principles imply.

---

## The one constraint that overrides everything

Read this before you write a line of code. It is not a style preference; it is the product.

> **The system reports facts about paperwork. It never draws conclusions about coverage.**

Concretely, and enforced by an automated test in Stage 8:

- The strings `compliant`, `verified`, `covered`, `approved`, `insured` (as a status), and `valid` must not appear in any user-facing output — dashboard HTML, Telegram messages, drafted emails, or status enums.
- Database columns that record checkbox state are named `*_asserted`. Never `additional_insured`.
- Database columns that record form wording are named `*_wording`. Never `notice_guaranteed_days`.
- Status values are date facts: `Current until 14 Mar 2027`, `Expires in 20 days`, `Expired 34 days ago`, `No certificate on file`, `Needs review`.

The word `approved` is permitted in exactly one place: `outreach_log.approved`, which records whether a **human approved sending an email**. That is a fact about an action a person took, not a statement about a vendor. It never renders to a screen a client sees.

---

## Document map

Work these in order. Each stage has a hard gate; do not start stage *N+1* until stage *N*'s gate passes.

| # | Document | What you build | Gate |
|---|---|---|---|
| 01 | [Stage 0 — Prerequisites](01-stage-0-prerequisites.md) | Accounts, keys, spend limits, local toolchain, repo skeleton | `make doctor` passes |
| 02 | [Stage 1 — Infrastructure](02-stage-1-infrastructure.md) | VPS, Docker Compose, Caddy TLS, n8n environment | Public HTTPS webhook resolves from a phone on mobile data |
| 03 | [Stage 2 — Data layer](03-stage-2-data-layer.md) | Postgres schema, migrations, seeds, all queries | `make db-verify` reports 9 application tables, 5 views, correct seed counts |
| 04 | [Stage 3 — Fixtures](04-stage-3-fixture-generation.md) | 20 synthetic certificates from a JSON spec | `make fixtures` regenerates the whole set in one command |
| 05 | [Stage 4 — Extraction engine](05-stage-4-extraction-engine.md) | OpenAI Responses API calls, strict schema, prompts, validation module | `make test-extract` passes on fixtures 1–4 |
| 06 | [Stage 5 — Intake workflow](06-stage-5-intake-workflow.md) | Workflow 1, node by node | Fixture 1 through the form URL produces a correct DB state |
| 07 | [Stage 6 — Watch & chase workflow](07-stage-6-watch-and-chase-workflow.md) | Workflow 2, node by node, approval gate | Approve on a phone sends a real email |
| 08 | [Stage 7 — Dashboard](08-stage-7-dashboard.md) | Workflow 3, complete HTML template, PDF serving | Forbidden-word scan returns zero hits |
| 09 | [Stage 8 — Test harness](09-stage-8-test-harness-and-acceptance.md) | Automated fixture runner, 20-row acceptance matrix | All 20 fixtures produce their expected outcome |
| 10 | [Stage 9 — Demo operations](10-stage-9-demo-operations.md) | Reset script, rehearsal protocol, failure recovery, runbook | Full demo in under 4 minutes, twice, without notes |
| 11 | [Decision Log](11-decision-log.md) | Every choice made here and why | — |
| 12 | [n8n Operations Cookbook](12-n8n-operations-cookbook.md) | CLI authoring, credential provisioning, REST-API testing, and the traps | — |

> **Read [Document 12](12-n8n-operations-cookbook.md) before Stage 5.** It changes how you author every workflow from that point on — JSON in git, imported by CLI, rather than clicks you cannot repeat — and it lists the failure modes that cost the most time: a missing `webhookId` that 404s silently, Postgres parameters that corrupt any value containing a comma, and an encryption key that must be pinned before the very first `up`.

`PROGRESS.md` at the repo root is the live tracker. Update it as you go; it is the thing you look at when you come back after two days away.

---

## Repository layout

Everything in this blueprint assumes this structure. Create it in Stage 0.

```
vendor-coi-chasing/
├── PROGRESS.md                      # live progress tracker
├── Makefile                         # every operational command
├── .env.example                     # committed
├── .env                             # NEVER committed
├── .gitignore
├── README.md
│
├── docs/                            # this blueprint
│   └── 00..11-*.md
│
├── infra/
│   ├── docker-compose.yml
│   ├── Caddyfile
│   └── n8n-env.md                   # generated reference of env vars in use
│
├── db/
│   ├── migrations/
│   │   ├── 001_schema.sql
│   │   ├── 002_indexes.sql
│   │   ├── 003_views.sql
│   │   └── 004_seed_config.sql
│   ├── seeds/
│   │   ├── vendors.csv              # per-client; demo default committed
│   │   ├── holder_entities.csv
│   │   └── trade_requirements.csv
│   ├── queries/
│   │   ├── q_expiry_buckets.sql
│   │   ├── q_dashboard.sql
│   │   └── q_followups_due.sql
│   └── scripts/
│       ├── apply.sh
│       ├── verify.sh
│       └── reset-demo.sh
│
├── extraction/
│   ├── schema/coi_extraction.schema.json
│   ├── prompts/
│   │   ├── extract.system.md
│   │   └── draft_email.system.md
│   └── payloads/
│       ├── text_branch.request.json     # template with {{}} placeholders
│       └── vision_branch.request.json
│
├── n8n/
│   ├── scripts/                     # provisioning, see docs/12
│   │   ├── import-credentials.sh    # NEVER commit a plaintext credential file
│   │   ├── fetch-credential-ids.sh  # after the manual Gmail OAuth step
│   │   ├── publish-all.sh
│   │   └── wait-for-webhooks.sh
│   ├── code/                        # Code-node sources, one file per node
│   │   ├── 01_preflight.js
│   │   ├── 02_build_request.js
│   │   ├── 03_parse_response.js
│   │   ├── 04_validate.js
│   │   ├── 05_persist_shape.js
│   │   ├── 06_bucket_rows.js
│   │   ├── 07_draft_request.js
│   │   ├── 08_render_dashboard.js
│   │   └── lib/                     # shared, inlined at paste time
│   │       ├── normalise.js
│   │       ├── fuzzy.js
│   │       └── dates.js
│   └── workflows/                   # exported JSON, one per workflow
│       ├── wf1-intake.json
│       ├── wf2-watch-chase.json
│       ├── wf3-dashboard.json
│       └── wf4-escalation.json
│
├── fixtures/
│   ├── spec/fixtures.json
│   ├── generate.py
│   ├── requirements.txt
│   └── out/                         # generated PDFs, gitignored
│
└── test/
    ├── run_fixtures.py
    ├── expected.json
    ├── forbidden_words.py
    └── unit/
        ├── test_validate.js
        └── test_normalise.js
```

---

## Conventions

### Naming

| Thing | Convention | Example |
|---|---|---|
| SQL tables | `snake_case`, plural | `outreach_log` |
| SQL columns | `snake_case` | `expiration_date` |
| Status / enum values | `SCREAMING_SNAKE` | `NEEDS_REVIEW` |
| Validation flag codes | `SCREAMING_SNAKE` | `DATE_INVERTED` |
| n8n node names | `Title Case — Purpose` | `Postgres — Upsert Certificate` |
| n8n workflow names | `COI · <n> · <Name>` | `COI · 1 · Intake` |
| Code node files | `NN_purpose.js` | `04_validate.js` |
| Make targets | `kebab-case` | `make test-extract` |

n8n node names appear in error alerts. Make them describe the operation, not the node type, so a 3am Telegram alert is readable.

### Dates and time

- **Postgres runs in UTC.** `TZ=UTC` on the container. Never change this.
- **All certificate dates are `DATE`, not `TIMESTAMPTZ`.** A policy expiration is a calendar day, not an instant. Storing it with a timezone invites an off-by-one that surfaces as "expires in 20 days" reading "19" for a client in a different zone.
- **"Today" is computed in the client's timezone**, read from `client_config.timezone` (demo: `America/New_York`), and passed into SQL explicitly. Never rely on `CURRENT_DATE` in a query that produces a user-facing day count. Stage 3 gives the exact pattern.
- **n8n's `GENERIC_TIMEZONE`** matches `client_config.timezone` so schedule triggers fire at 08:00 local.
- Display format is `14 Mar 2027` — unambiguous to both US and non-US readers. Never `03/14/27`.

### Money

- Limits are stored as `NUMERIC(14,2)`, never floats, never text.
- The model returns integers with no separators or symbols (`1000000`). The validation layer coerces and rejects anything else.
- Display is abbreviated: `$1M`, `$2M`, `$300k`. Rendering logic is in `08_render_dashboard.js`, single source.

### Secrets

- Everything sensitive lives in `.env`, loaded by Docker Compose. `.env` is gitignored. `.env.example` lists every key with a dummy value and is committed.
- The OpenAI key exists in exactly two places: `.env` on the VPS, and an n8n **OpenAI API** credential. It is never in a workflow JSON export, never in a Code node, never in a Postgres row.
- Before exporting any workflow to `n8n/workflows/`, confirm the export contains no credential *values* — n8n exports credential *references* by ID, which is correct and safe. Stage 8 has a check for this.

### Error handling philosophy

Three tiers, applied consistently:

| Tier | When | Behaviour |
|---|---|---|
| **Reject** | Input is structurally not processable (not a PDF, encrypted, zero bytes) | Write a `dead_letter` row, notify the manager, stop. Never create a vendor or certificate row. |
| **Quarantine** | Processable but untrustworthy (LOW confidence, hard validation flag, model refusal) | Write the certificate with `status = NEEDS_REVIEW` and the full `raw_extraction`. Surface on dashboard. Never enters chase logic as fact. |
| **Accept** | Clean extraction, no hard flags | `status = ON_FILE`. Soft flags render as notes. |

**Nothing is ever silently dropped.** If a document enters the system and produces no row anywhere, that is a bug, and Stage 8 tests for it explicitly.

---

## Provider decision — locked

**OpenAI only. `POST https://api.openai.com/v1/responses`.**

This is a directive from the project owner and it is also the better engineering choice for this build (Decision Log D-01). Anthropic is not used anywhere. If a future requirement genuinely cannot be met on OpenAI, it gets raised as an Open Question in `PROGRESS.md` before any second provider is added.

| Setting | Value | Where it lives |
|---|---|---|
| Endpoint | `https://api.openai.com/v1/responses` | `client_config.openai_endpoint` |
| Extraction model | `gpt-5.4-mini-2026-03-17` | `client_config.model_id` |
| Escalation model | `gpt-5.6-terra` | `client_config.model_id_escalation` |
| Auth | n8n OpenAI API credential via HTTP Request predefined authentication | n8n credential store |
| Schema enforcement | `text.format` → `json_schema`, `strict: true` | `extraction/schema/` |
| Key spend limit | **$10 hard cap** in the OpenAI console | OpenAI dashboard |

**Pin the dated snapshot.** `gpt-5.4-mini` is a floating alias and will move under you. `gpt-5.4-mini-2026-03-17` will not. The model ID lives in `client_config` so changing it is one SQL `UPDATE`, not an edit across four workflows. The Stage 9 canary job is what tells you the ID died.

Verified current as of 2026-07-29:
- `gpt-5.4-mini` — $0.75 / $4.50 per MTok, 400K context, 128K max output, text + image input, Structured Outputs supported, snapshot `gpt-5.4-mini-2026-03-17`
- `gpt-5.6-terra` — $2.50 / $15.00 per MTok (escalation tier)
- `gpt-5.6-luna` — $1.00 / $6.00 per MTok (the fallback if 5.4-mini is retired)

Re-verify before any client go-live. OpenAI's lineup moves fast enough that a four-month-old pricing table is a liability.

---

## Why the Responses API and not Chat Completions

The build plan sketched Chat Completions. This blueprint uses the **Responses API** instead. Three concrete reasons, all of which matter to this specific build:

1. **PDF `detail` control exists only on Responses.** `input_file` accepts `"detail": "low" | "auto" | "high"`. The vision branch is reading a skewed phone photo of a certificate — that is the entire job on that branch — so it runs at `"high"`. Chat Completions gives you no control and silently picks for you.
2. **Reasoning effort is a first-class parameter.** `reasoning: { "effort": "low" }` on the text branch cuts latency, which is the demo's real currency.
3. **Structured Outputs lands at `text.format`**, a cleaner shape than `response_format` nesting, and refusals surface as a typed `refusal` content part you can detect without string matching.

The cost is one thing: parsing the response requires walking an `output[]` array rather than reading `choices[0].message.content`. Stage 4 gives you that parser, written and tested, so the cost is paid once.

---

## The four human gates — where they sit and what each prevents

These are load-bearing. Removing any one of them changes what you are allowed to say to a prospect.

| # | Gate | Implemented in | Prevents |
|---|---|---|---|
| 1 | Email approval before any vendor email sends | Stage 6, `Gmail — Send and Wait` | The system contacting a third party on its own |
| 2 | LOW confidence or hard flag → `NEEDS_REVIEW` | Stage 4, `04_validate.js` | A bad extraction becoming a silent wrong answer |
| 3 | No PMS credentials exist anywhere | Architecture — nothing to implement | Any write to the client's system of record. Structural, not policy |
| 4 | Dashboard states date facts only | Stage 7, enforced by test | Drift into compliance language |

Gate 3 is worth stating precisely in sales conversations: it is not that the system chooses not to write to Buildium, it is that it holds no credential and has no code path. That distinction is the difference between a promise and a fact.

---

## Reading order for a developer joining cold

1. This document, fully.
2. `foundation-1-vendor-insurance.md` Parts 2 and 4 — enough insurance domain to not make a claim you shouldn't.
3. `coi-demo-build-plan.md` Sections 11 (what you must not claim) and 9 (the demo script) — these tell you what the software is *for*.
4. [Document 11 — Decision Log](11-decision-log.md) — so you don't relitigate settled choices.
5. Then Stage 0 and go.

Budget half a day for reading. It is cheaper than a week spent building something that has to be renamed.
