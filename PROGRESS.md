# Progress Tracker — Vendor COI Chasing

**Started:** _____________  ·  **Target demo date:** _____________
**Blueprint:** [docs/00-index-and-conventions.md](docs/00-index-and-conventions.md)

Update this file as you go. It is what you look at when you come back after two days away.

**Status key:** ⬜ not started · 🟨 in progress · ✅ done · ⛔ blocked · ⏭️ deliberately skipped

---

## Overview

| Stage | Document | Status | Started | Finished | Gate passed |
|---|---|---|---|---|---|
| 0 · Prerequisites | [01](docs/01-stage-0-prerequisites.md) | 🟨 | 2026-07-29 | | ✅ `doctor.sh` |
| 1 · Infrastructure | [02](docs/02-stage-1-infrastructure.md) | 🟨 | 2026-07-29 | | ✅ local stack healthy |
| 2 · Data layer | [03](docs/03-stage-2-data-layer.md) | ✅ | 2026-07-30 | 2026-07-30 | ✅ `db/scripts/verify.sh` |
| 3 · Fixtures | [04](docs/04-stage-3-fixture-generation.md) | ⬜ | | | ⬜ `make fixtures` |
| 4 · Extraction engine | [05](docs/05-stage-4-extraction-engine.md) | ⬜ | | | ⬜ `make test-extract` |
| 5 · Intake workflow | [06](docs/06-stage-5-intake-workflow.md) | ⬜ | | | ⬜ 12 intake cases |
| 6 · Watch & chase | [07](docs/07-stage-6-watch-and-chase-workflow.md) | ⬜ | | | ⬜ phone approval sends |
| 7 · Dashboard | [08](docs/08-stage-7-dashboard.md) | ⬜ | | | ⬜ `make test-forbidden` |
| 8 · Test harness | [09](docs/09-stage-8-test-harness-and-acceptance.md) | ⬜ | | | ⬜ 20/20 fixtures |
| 9 · Demo operations | [10](docs/10-stage-9-demo-operations.md) | ⬜ | | | ⬜ under 4 min, twice |

**Estimated total: 5–7 working days.** Stages 4 and 5 are the long ones.

---

## Stage 0 — Prerequisites

- [ ] OpenAI project `coi-demo` created, restricted key issued
- [ ] **$10 hard budget limit set** (this is the actual budget enforcement)
- [x] `curl` against the pinned model returns 200
- [ ] Gmail label `COI-INTAKE` + filter created
- [ ] Google Cloud project created, Gmail API enabled
- [ ] **OAuth consent screen PUBLISHED** (not Testing — 7-day token expiry, see D-17)
- [x] OAuth client details added to local `.env` (redirect URI pending production deployment)
- [ ] VPS provisioned, Docker + Compose v2 installed
- [ ] `ufw` allows only 22 / 80 / 443
- [ ] DNS A record resolves to the VPS
- [ ] Telegram bot + chat ID *(optional)*
- [x] Repo scaffold, `.gitignore`, `.env.example`, `Makefile`, and `doctor.sh` created
- [x] `.env` filled for local demo mode
- [ ] **`N8N_ENCRYPTION_KEY` saved to a password manager** (not regenerable)
- [x] `doctor.sh` exits 0 in local demo mode

## Stage 1 — Infrastructure

### Local demo verification — 2026-07-29

- [x] Existing `postgres:16` and `n8nio/n8n:latest` images reused without pulling
- [x] PostgreSQL and n8n healthy in the isolated `vendor-coi-chasing` Compose project
- [x] n8n responds at `http://localhost:5678`; binding is loopback-only
- [x] Databases `coi` and `n8n` both exist
- [x] PostgreSQL publishes no host port; host connections require SCRAM
- [x] JavaScript task runner registered; Python Code nodes disabled
- [x] Owner record, databases, and three named volumes survive container recreation

### Production and credential gates

- [x] **`N8N_ENCRYPTION_KEY` pinned BEFORE the first `up`** (auto-generated otherwise, and a later env var is silently ignored)
- [ ] All three services running; postgres and n8n healthy
- [ ] Valid TLS certificate, no browser warning
- [ ] Databases `coi` and `n8n` both exist
- [ ] Postgres has **no** published port
- [x] Credentials `OpenAI Account` (n8n OpenAI API) + `Postgres — COI` available
- [x] Plaintext credential file deleted from **both** the temp path and the container
- [x] Credential: `Gmail account` — manual OAuth completed in the UI
- [ ] Credential: `Telegram — COI` *(optional)*
- [ ] Gmail credential **verified with an actual API call**
- [ ] New env vars applied with `up -d`, not `restart`
- [ ] Google OAuth redirect URI updated to the real host
- [ ] Webhook production URL shows the public HTTPS hostname
- [ ] **Webhook loads on a phone over mobile data** ← date verified: __________
- [ ] **Send-and-wait approval link starts `https://<host>/webhook-waiting/` and Approve resumes** ← date verified: __________
- [ ] Daily backup cron installed; one dump exists; restore inspected

## Stage 2 — Data layer

- [x] `db/scripts/apply.sh` applies all migrations; re-running is a no-op (GNU Make unavailable on this workstation)
- [x] `db/scripts/seed.sh` loads 18 vendors; re-running does not duplicate
- [x] `db/scripts/verify.sh` exits 0 — 9 application tables, 5 views, correct seed counts
- [x] Configuration keys and their intended workflow/query consumers are documented
- [x] `approver_email` set to a demo address
- [x] `from_mailbox` set to a demo address
- [x] `dashboard_token` matches `.env`
- [x] `v_vendor_status` → 18 rows, all `NEVER_RECEIVED`, all grey
- [x] No `CURRENT_DATE` anywhere in queries or migrations
- [x] `db/scripts/reset-demo.sh` completes in under 2 seconds — measured: 0.974 s

### Vendor list source

- [ ] Prospect's real vendor names obtained · [x] Fell back to the fictional set

> Real names are the highest-leverage step in the build. A prospect seeing their own vendors on screen is looking at a picture of their business, not a demo of your software.

## Stage 3 — Fixtures

- [ ] `make fixtures` regenerates all 20 in one command
- [ ] `manifest.json` exists with resolved dates
- [ ] `f02` expires exactly today + 20 days
- [ ] `f03` expired exactly today − 34 days
- [ ] `f13` effective exactly 14 days after `f03` expiry
- [ ] `f04` has **no selectable text**
- [ ] `f18` raises on open without a password
- [ ] `f19` exists as `.eml`
- [ ] SPECIMEN watermark on every PDF
- [ ] No ACORD logo, form number, or copyright notice anywhere

## Stage 4 — Extraction engine

- [ ] Schema is strict-valid (all `required`, `additionalProperties: false` on both objects)
- [ ] System prompt saved; CONFIDENCE block intact including "Bias toward LOW"
- [ ] Text branch correct on `f01`
- [ ] Vision branch correct on `f04` at **MEDIUM** with a specific reason
- [ ] `03_parse_response.js` handles 429 / 5xx / incomplete / refusal / missing-message without throwing
- [ ] `04_validate.js` implements all 13 rules
- [ ] `make test-extract` passes
- [ ] SQL/JS normalisation parity holds on all 30 strings

### Measured performance

| Branch | Input tok | Output tok | Latency | Cost/cert |
|---|---|---|---|---|
| Text | | | | |
| Vision | | | | |

## Stage 5 — Intake workflow

- [ ] Form Trigger public, accepts multiple PDFs
- [ ] Gmail Trigger polls `COI-INTAKE`, downloads attachments
- [ ] Error Trigger workflow wired, reading **both** payload shapes (`execution.*` and `trigger.*`)

### JSON-authoring gates (docs/12)

- [ ] Every workflow JSON has a top-level `id` (UUID), stable in git
- [ ] Every webhook-based trigger has a top-level **`webhookId`** — missing = silent 404 despite `active: true`
- [ ] All Postgres nodes use `executeQuery` + `queryReplacement` as an **array expression**, never a comma-string
- [ ] All `\n` inside workflow-JSON expressions are written `\\n`
- [ ] No bare `$json` downstream of a Postgres or gate node — context bound by node name
- [ ] `make wf-import` runs validate → import → publish → restart → wait, clean

| # | Test | ✓ | Note |
|---|---|---|---|
| 1 | `f01` via form → 1 cert, 3 coverages, HIGH | ⬜ | |
| 2 | Same file twice → 1 row, 1 notification | ⬜ | |
| 3 | `f04` → vision branch, MEDIUM | ⬜ | |
| 4 | `f05` → NEEDS_REVIEW + DATE_INVERTED | ⬜ | |
| 5 | `f11` → 0 rows, dead_letter NOT_A_COI | ⬜ | |
| 6 | `f18` → dead_letter PDF_ENCRYPTED, no crash | ⬜ | |
| 7 | `f02` by email → same result in ~60 s | ⬜ | |
| 8 | `f10a` + `f10b` one email → 2 rows | ⬜ | |
| 9 | `f19` → PORTAL_LINK, **no outbound fetch** | ⬜ | |
| 10 | `f12` after `f02` → supersede | ⬜ | |
| 11 | `f13` after `f03` → COVERAGE_GAP = 14 | ⬜ | |
| 12 | `f17` → POSSIBLE_DUPLICATE, `vendor_id` NULL | ⬜ | |

- [ ] Workflow exported; secret scan clean

## Stage 6 — Watch & chase

- [ ] `NEVER_RECEIVED` is the **first** Switch branch, with its own template
- [ ] Switch fallback wired
- [ ] Drafts under 110 words, correct policy number, no placeholders
- [ ] Forbidden-word query over `outreach_log` returns zero rows
- [ ] **Approval email received on a phone never logged into n8n** ← date: __________
- [ ] Approve sends a real email; Decline sends nothing
- [ ] `outreach_log` row written **before** the approval prompt
- [ ] Re-running the same day produces zero duplicates
- [ ] **Re-running the next day also produces zero items** — `awaiting_reply` guard, not just same-day
- [ ] Sweep runs at **07:30, before** the 08:00 chase
- [ ] Attempt 1 unanswered → `REOPEN`, no alert · attempt 2 unanswered → `ESCALATE` + pause
- [ ] Attempt-2 draft reads as a follow-up and goes through the approval gate
- [ ] A vendor who sent a certificate is **not** escalated afterwards
- [ ] Escalation pauses chasing; a new certificate clears the pause
- [ ] Changing `reminder_d30` visibly moves the amber band
- [ ] Retention purge deletes the file, keeps the row, renders `not retained`
- [ ] Missing recipient → manager notice, no model call
- [ ] Model failure → template fallback, vendor **not** skipped
- [ ] Status override form writes status + note + attribution
- [ ] Workflows exported

## Stage 7 — Dashboard

- [ ] Renders under 1 s with a valid token; 401 without
- [ ] Rows update within 5 s, **no manual refresh**
- [ ] All 18 visible; `NEVER_RECEIVED` at the top
- [ ] Colours correct
- [ ] Flags render readable notes; `COVERAGE_GAP` red with its own header count
- [ ] Cancellation wording renders **neutral grey**, never green
- [ ] Every certificate row links to a working source PDF
- [ ] `/coi/pdf` rejects non-integer IDs and missing files cleanly
- [ ] `make test-forbidden` exits 0
- [ ] Footer disclaimer present
- [ ] Readable at 375 px
- [ ] Workflow exported

## Stage 8 — Test harness

- [ ] `test/expected.json` covers all 20
- [ ] `make test-fixtures` runs unattended
- [ ] SQL/JS normalisation parity passes
- [ ] Pasted prompt + schema match their source files
- [ ] No secrets in workflow exports
- [ ] 10 concurrent uploads → 10 rows, zero drops
- [ ] Workflow 2 test-run via REST API (`pinData` + `triggerToStartFrom`) reaches the approval gate
- [ ] Any live threshold patch used for testing has been **reverted**

### Fixture results — run of __________

| # | Fixture | Expected | Actual | ✓ | Notes / `confidence_reason` |
|---|---|---|---|---|---|
| 1 | f01-clean-current | ON_FILE / HIGH / 3 lines | | ⬜ | |
| 2 | f02-expiring-20d | ON_FILE / amber / D30 | | ⬜ | |
| 3 | f03-expired-34d | ON_FILE / red / EXPIRED | | ⬜ | |
| 4 | f04-scanned | vision / MEDIUM | | ⬜ | |
| 5 | f05-inverted-dates | NEEDS_REVIEW / DATE_INVERTED | | ⬜ | |
| 6 | f06-wrong-holder | ON_FILE / HOLDER_MISMATCH | | ⬜ | |
| 7 | f07-low-limits | ON_FILE / LIMIT_BELOW_MINIMUM | | ⬜ | |
| 8 | f08-four-expiries | earliest ≠ GL | | ⬜ | |
| 9 | f09-no-gl | ON_FILE / NO_GL_LINE | | ⬜ | |
| 10 | f10a + f10b | 2 independent rows | | ⬜ | |
| 11 | f11-not-a-coi | REJECT / 0 rows | | ⬜ | |
| 12 | f12-renewal | supersede, green | | ⬜ | |
| 13 | f13-coverage-gap | COVERAGE_GAP = 14 | | ⬜ | |
| 14 | *(no fixture)* | 4 vendors NEVER_RECEIVED | | ⬜ | |
| 15 | f15-sole-prop-no-wc | **no** WC flag | | ⬜ | |
| 16 | f16-owner-llc-holder | **no** holder mismatch | | ⬜ | |
| 17 | f17-near-duplicate | review, no merge | | ⬜ | |
| 18 | f18-encrypted | dead_letter, no crash | | ⬜ | |
| 19 | f19-portal-link | notice, no fetch | | ⬜ | |
| 20 | f20-cancellation | wording verbatim | | ⬜ | |

**Result: ____ / 20 passed**

## Stage 9 — Demo operations

- [ ] `make preflight` exits 0
- [ ] Canary workflow built and verified by deliberately breaking the pipeline
- [ ] `make demo-reset` under 2 s
- [ ] Fallback video recorded, < 100 MB, linkable from phone
- [ ] Rehearsal 1 — mechanics
- [ ] Rehearsal 2 — under 4:30
- [ ] Rehearsal 3 — **wifi off at 2:15**, recovery said out loud
- [ ] Rehearsal 4 — **someone else taps Approve**
- [ ] Rehearsal 5 — no notes, under 4:00, including the close
- [ ] Four key lines said until boring
- [ ] **Eleven** rehearsed answers said out loud, including Certificial and the OpenAI litigation hold
- [ ] Can place Certificial / TrustLayer / NetVendor / myCOI without hesitating
- [ ] OpenAI privacy page bookmarked
- [ ] Free-trial procedure tested end to end

---

## Budget

**Hard ceiling: $10, enforced by the OpenAI key spend limit — not by this table.**

| Item | Budget | Actual | Date |
|---|---|---|---|
| Stage 4 — extraction iterations | ~$1.50 | | |
| Stage 5 — intake testing | ~$0.50 | | |
| Stage 6 — draft testing | ~$0.30 | | |
| Stage 8 — full acceptance runs | ~$0.30 | | |
| Rehearsals (5 × ~$0.012) | ~$0.06 | | |
| Contingency / re-work | ~$1.50 | | |
| **Total tokens** | **~$4.20** | | |
| VPS (monthly) | $5 | | |
| Domain | $0–12/yr | | |

Check actual spend at the OpenAI usage page after every stage.

---

## Model ID history

Log every change. The canary job is what tells you a snapshot died.

| Date | Model ID | Reason | In / Out per MTok |
|---|---|---|---|
| 2026-07-29 | `gpt-5.4-mini-2026-03-17` | Initial pin — cheapest current-gen mini with image input + Structured Outputs | $0.75 / $4.50 |
| | | | |

**Fallback if retired:** `gpt-5.6-luna` ($1.00 / $6.00). Verify pricing before switching. Change is one SQL statement:

```bash
docker compose -f infra/docker-compose.yml exec -T postgres psql -U coi -d coi -c "UPDATE client_config SET value='gpt-5.6-luna' WHERE key='model_id';"
```

---

## Accepted deviations

Anything that does not match the blueprint and that you have consciously accepted. **Every row needs a rehearsed line** — an accepted deviation you have not rehearsed a line for is an unaccepted deviation.

| Date | What deviates | Why accepted | What you say if asked |
|---|---|---|---|
| | | | |

---

## Open questions

| # | Question | Blocks | Owner | Status |
|---|---|---|---|---|
| O-1 | n8n Sustainable Use License on multi-tenant hosting | Multi-tenant only | | ⬜ Email `license@n8n.io` |
| O-2 | n8n Data Table node query semantics | Nothing | | ⏭️ Revisit v2 |
| O-3 | Longevity of `gpt-5.4-mini-2026-03-17` | Nothing today | | 🟨 Canary answers weekly |
| O-4 | Rentec / Rent Manager / Propertyware API tiers | Nothing | | ⏭️ Not needed — zero PMS integration |

Add new questions here rather than deciding silently. If you resolved one, move the decision into [docs/11-decision-log.md](docs/11-decision-log.md).

---

## Defect log

Anything you found and fixed. Worth keeping — several of these become sales material.

| Date | Stage | Defect | Fix | Would a prospect have found it? |
|---|---|---|---|---|
| | | | | |

---

## Session log

One line per working session. Future-you will thank present-you.

| Date | Hours | What got done | Where you stopped | Next action |
|---|---|---|---|---|
| | | | | |

---

## Pre-demo checklist

Copy this block for each scheduled demo.

**Prospect:** ____________  **Date/time:** ____________  **Doors:** ____  **Vendors:** ____

**Day before**
- [ ] Real vendor names seeded — asked when scheduling
- [ ] Their legal entity in `holder_entities`
- [ ] Approver email confirmed
- [ ] `make test-fixtures` clean run

**Morning of**
- [ ] `make preflight` → READY
- [ ] Gmail credential checked **by eye** in n8n (expired refresh tokens are silent)
- [ ] `make demo-reset`
- [ ] Dashboard open in a second tab, token not visible in a screen-share
- [ ] Fixture 2 email drafted, **not sent**
- [ ] Fixtures 3 and 13 on the desktop
- [ ] Fallback video open in a background tab
- [ ] Phone on mobile data, in frame
- [ ] Notifications silenced, bookmarks bar hidden

**After**
- [ ] Closing ask made — ten certificates
- [ ] Follow-up sent same day
- [ ] Notes below

**Outcome / notes:**

```


```
