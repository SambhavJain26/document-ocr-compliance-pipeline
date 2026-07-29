# Vendor COI Chasing

Automated tracking and chasing of vendor certificates of insurance, for US residential property management companies in the 150–600 door range.

**What it does:** reads a certificate PDF that arrives by email or upload, extracts the vendor, carrier, policy number, limits and dates, files it against the right vendor, watches the calendar, and drafts a renewal request to the insurance agent — which a human approves before anything sends.

**What it does not do:** verify coverage. A certificate is an information document; it does not amend the policy or confer rights on the holder. This system tracks dates and documents. It cannot confirm an endorsement exists or that a policy is still in force today. That limitation is stated on the dashboard itself and enforced by an automated test.

---

## Documents

| | |
|---|---|
| **[PROGRESS.md](PROGRESS.md)** | Live build tracker. Start here each session. |
| **[docs/00 — Index & conventions](docs/00-index-and-conventions.md)** | Read fully before writing code. |
| [docs/01 — Stage 0: Prerequisites](docs/01-stage-0-prerequisites.md) | Accounts, keys, spend limits, repo scaffold |
| [docs/02 — Stage 1: Infrastructure](docs/02-stage-1-infrastructure.md) | VPS, Docker, Caddy, n8n environment |
| [docs/03 — Stage 2: Data layer](docs/03-stage-2-data-layer.md) | Schema, migrations, views, seeds, queries |
| [docs/04 — Stage 3: Fixtures](docs/04-stage-3-fixture-generation.md) | 20 synthetic certificates from a JSON spec |
| [docs/05 — Stage 4: Extraction engine](docs/05-stage-4-extraction-engine.md) | OpenAI Responses API, strict schema, 13 validation rules |
| [docs/06 — Stage 5: Intake workflow](docs/06-stage-5-intake-workflow.md) | Workflow 1, node by node |
| [docs/07 — Stage 6: Watch & chase](docs/07-stage-6-watch-and-chase-workflow.md) | Workflow 2, the approval gate, escalation |
| [docs/08 — Stage 7: Dashboard](docs/08-stage-7-dashboard.md) | Workflow 3, complete HTML template |
| [docs/09 — Stage 8: Test harness](docs/09-stage-8-test-harness-and-acceptance.md) | Automated fixture runner, acceptance matrix |
| [docs/10 — Stage 9: Demo operations](docs/10-stage-9-demo-operations.md) | Pre-flight, reset, demo script, failure recovery |
| [docs/11 — Decision log](docs/11-decision-log.md) | Every choice made and why. Read before disagreeing with one. |
| [docs/12 — n8n operations cookbook](docs/12-n8n-operations-cookbook.md) | CLI authoring, credential provisioning, REST-API testing, and the traps. **Read before Stage 5.** |

### Background (strategy, not implementation)

- [`01-vendor-coi-chase.md`](01-vendor-coi-chase.md) — the opportunity, the buyer, positioning, pricing
- [`coi-demo-build-plan.md`](coi-demo-build-plan.md) — research findings, licensing, regulatory gates, sales material
- [`foundation-1-vendor-insurance.md`](foundation-1-vendor-insurance.md) — insurance and property-management domain primer

---

## Stack

n8n (self-hosted, Docker) · PostgreSQL 16 · Caddy · OpenAI Responses API (`gpt-5.4-mini-2026-03-17`) · Gmail · ReportLab

Marginal cost per client: **under $6/month.** Cost per demo: **about a cent.**

---

## Quick start

```bash
cp .env.example .env      # then fill it in
make doctor               # Stage 0 gate
make up                   # bring up the stack
make db-apply && make db-seed && make db-verify
make fixtures
make test-all
```

`make help` lists every target.

---

## The one rule

**The system reports facts about paperwork. It never draws conclusions about coverage.**

The words *compliant*, *verified*, *covered*, *approved* and *valid* do not appear in any user-facing output. Status strings are date facts: `Current until 14 Mar 2027`, `Expires in 20 days`, `Expired 34 days ago`, `No certificate on file`, `Needs review`.

This is enforced by `make test-forbidden`, which fetches the rendered dashboard and fails the build on a hit. It is not a style preference — it is the difference between an administrative product you can sell with no track record and a compliance product you cannot.
