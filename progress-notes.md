# Vendor COI Chasing - Progress Notes

Created: 2026-07-30

## Current Status

Stage 1 local environment scaffolding and credential smoke verification are complete on this machine. Stage 2 database schema and synthetic seed register are complete and verified. Stage 3 synthetic fixtures are generated and verified. Stage 4 extraction and validation core is complete with offline validator tests and live n8n/OpenAI fixture smoke passing locally. Rechecked `coi-demo-build-plan.md` once after the initial plan and made small planning corrections. Rechecked current n8n/OpenAI documentation on 2026-07-30 and changed the recommended model-call implementation from HTTP Request-first to built-in OpenAI node V2-first.

## Source Documents Reviewed

- `01-vendor-coi-chase.md`
- `coi-demo-build-plan.md`
- `foundation-1-vendor-insurance.md`

## Approved Build Direction

Pending user approval.

The staged plan in `build-plan.md` follows the later `coi-demo-build-plan.md` where it conflicts with the original problem document:

- Postgres over Google Sheets.
- Custom n8n webhook-served HTML dashboard over off-the-shelf admin tools.
- Gmail approval as the default human-in-the-loop gate.
- Telegram optional for alerts or prospects who already use it.
- Text-first PDF extraction with model PDF vision fallback instead of OCR community nodes.
- Zero PMS integration.
- No SMS in demo.
- No claims of vendor compliance, verification, coverage, or approval.

## Stage Progress

| Stage | Name | Status | Notes |
|---|---|---|---|
| 1 | Environment, Accounts, and Local n8n | Complete | Local Docker Compose environment verified. Public HTTPS intentionally deferred because all Stage 1 testing is same-machine only. Postgres, OpenAI, and Gmail credentials smoke-tested through n8n. |
| 2 | Database Schema, Client Config, and Seed Vendors | Complete | Seven project tables created. Synthetic Harbourline config, holder entities, trade requirements, and 18 vendors seeded. Certificate, coverage, and outreach tables remain empty. |
| 3 | Synthetic Test Fixtures | Complete | 20 fixture records generated: 17 PDFs, 2 email payloads, and 1 metadata-only no-file case. Verified watermark, text-layer behavior, scanned no-text behavior, password protection, rendered previews, and forbidden-term scan. |
| 4 | Extraction and Validation Core | Complete | Added schema, shared validator, generated n8n workflow export, fixture mount, runbook, and verification scripts. Offline validator tests pass. Live n8n/OpenAI extraction smoke passes for fixed fixtures `f01`, `f04`, `f11`, and `f18`. |
| 5 | Intake Workflow End to End | Not started | Depends on extraction core. |
| 6 | Daily Watch, Drafting, Approval, and Escalation | Not started | Depends on stored certificate records. |
| 7 | Dashboard and Demo View | Not started | Depends on populated database and status logic. |
| 8 | Full Fixture Run, Demo Reset, and Rehearsal | Not started | Depends on full demo workflow. |
| 9 | Production Readiness Plan | Not started | Should not begin until demo-depth build is proven. |

## Open Decisions

1. Exact OpenAI model ID for the demo:
   - Provider/node choice is decided: OpenAI through n8n's built-in OpenAI node V2, using Responses API, PDF File input, and JSON Schema output.
   - Current default for Stage 1 notes: `gpt-5.4-nano`.
   - Fallback if fixture quality is insufficient: `gpt-5.6-luna`.
   - Store the chosen model in `client_config.model_id` during Stage 2 rather than hardcoding workflow nodes.
   - Fallback: OpenAI via HTTP Request if the installed n8n version lacks required controls.
   - Alternative only if OpenAI is unavailable: Anthropic via HTTP Request with prompt-only JSON and defensive parsing.

2. Public HTTPS method for n8n:
   - Deferred for Stage 1 because the demo build is being built and tested locally on this machine only.
   - Current local default: `WEBHOOK_URL=http://localhost:5678`.
   - Revisit Cloudflare Tunnel, Caddy on VPS, or another public reverse proxy before testing approval links from a phone or running a live prospect demo.

3. Approval channel:
   - Recommended default: Gmail `Send and Wait for Response`.
   - One Gmail/Google Workspace mailbox is enough for local testing; use plus-address aliases to simulate vendor, producer, approval, and intake roles.
   - Optional: Telegram only when the prospect already uses it.

4. Demo vendor names:
   - Preferred: prospect's real vendor names only, no documents.
   - Fallback: synthetic 18-vendor list.

5. Production hosting model:
   - Recommended: client-hosted or client-owned VPS.
   - Avoid unverified multi-tenant n8n hosting until licensing is clarified.

## Deviations From Original Source Document

- Removed OCR Bro from the build plan because the later research rejected it as a dependency risk and found native model PDF vision sufficient.
- Replaced Google Sheets with Postgres for data ownership, query reliability, and cleaner demo positioning.
- Replaced Telegram-first approval with Gmail-first approval to avoid requiring prospects to install or use Telegram.
- Added explicit handling for vendors with no certificate on file via `NEVER_RECEIVED`.
- Added coverage-gap detection on renewal.
- Added holder entity matching beyond a single client legal name.
- Added WC exemption suppression.
- Added near-duplicate vendor review instead of automatic merging.
- Added non-PDF reply and portal-link handling.
- Added manual `CANCELLED` and `NON_RENEWED` statuses because mid-term cancellation cannot be detected from a certificate.
- Added high-risk-trade absence of cancellation-notice wording as a neutral document note in validation/dashboard planning.
- Preserved the disabled IMAP Email Trigger fallback for non-Google clients.
- Updated model-call plan after current-docs recheck: use built-in OpenAI node V2 first; HTTP Request is now fallback, not default.
- Clarified email transport: Gmail Trigger/Gmail node are enough for the Gmail demo; IMAP and SMTP are fallback paths only.

## Documentation Updates

2026-07-30:

- Added Stage 1 local-only Docker Compose scaffolding for n8n and Postgres.
- Added local environment scripts for `.env` generation, startup, verification, and shutdown.
- Added `docs/stage-1-local-runbook.md` with exact same-machine setup and credential smoke-test instructions.
- Verified `docker compose config`, local Postgres readiness/query, and n8n HTTP `200` at `http://localhost:5678`.
- Noted n8n 2.29 first-start migrations and non-blocking Python task-runner warning in `AGENTS.md`.
- Set model default to `gpt-5.4-nano`, keeping `gpt-5.6-luna` as fallback.
- Recorded that one Gmail/Google Workspace mailbox is enough for local testing, using plus-address aliases for logical roles.
- Recorded user report that requested n8n credentials were created, then completed smoke verification.
- Smoke-tested n8n credential records: `Postgres account`, `OpenAI account`, and `Gmail account`.
- Postgres smoke workflow executed through n8n and returned `ok = 1`.
- OpenAI smoke workflow executed through n8n OpenAI node V2 using `gpt-5.4-nano` and returned `ok`; token usage was 11 input and 5 output tokens.
- Gmail smoke workflow sent a same-machine test email successfully; Gmail returned message/thread ID `19fb2b6f6dec3dec`.
- Removed temporary smoke workflows from n8n after verification.
- Added Stage 2 Postgres schema and idempotent synthetic seed SQL.
- Added `scripts/apply-stage-2.ps1` and `scripts/verify-stage-2.ps1`.
- Added `docs/stage-2-database-runbook.md`.
- Verified Stage 2 after an idempotent rerun: seven project tables exist, 10 config keys exist, model defaults are `gpt-5.4-nano` and `gpt-5.6-luna`, one primary holder exists, default/Roofing/Landscaping requirements exist, 18 vendors exist, one vendor is WC-exempt, vendor normalization is deterministic and unique, and `certificates`, `coverages`, and `outreach_log` are empty.
- Added Stage 3 JSON fixture spec, ReportLab generator, generated fixture PDFs, email payloads, and expected metadata.
- Added `scripts/generate-stage-3-fixtures.ps1` and `scripts/verify-stage-3-fixtures.ps1`.
- Added `docs/stage-3-fixtures-runbook.md`.
- Verified Stage 3: 20 fixture records, 17 PDFs, 2 email payloads, fixture 14 metadata-only, normal PDFs watermarked and text-extractable, scanned fixture has zero extracted text, password PDF is encrypted and blocks unauthenticated text extraction, all PDFs render to previews, and fixture artifacts contain no forbidden terms `ACORD`, `compliant`, `verified`, or `approved`.
- Added Stage 4 strict extraction schema at `docs/schemas/coi-extraction.schema.json`.
- Added shared deterministic Stage 4 validator at `scripts/lib/coi-stage-4-validator.js`.
- Added `scripts/test-stage-4-validation.js`, `scripts/verify-stage-4-validation.ps1`, `scripts/generate-stage-4-workflow.ps1`, `scripts/generate-stage-4-workflow.js`, and `scripts/verify-stage-4-extraction.ps1`.
- Added generated Stage 4 n8n workflow export at `n8n-workflows/stage-4-extraction-validation-core.json`.
- Mounted `./fixtures` read-only into n8n at `/home/node/.n8n-files/fixtures`.
- Added `docs/stage-4-extraction-runbook.md`.
- Verified Stage 4 offline validation: hard flags route to review/ignore, soft flags preserve `ON_FILE`, note flags remain informational, holder matching accepts configured holder entities, near-duplicate vendors route to review, WC checks are suppressed for exempt vendors, and renewal context catches older-than-on-file and coverage-gap cases.
- Verified Stage 4 workflow JSON parses with `ConvertFrom-Json`.
- Updated Stage 3 fixture generation to make synthetic PDFs deterministic and to make the image-only scanned fixture readable enough for the Stage 4 vision smoke while preserving zero extractable text.
- Verified Stage 3 again after fixture readability changes: 20 fixture records, 17 PDFs, two email payloads, image-only scanned fixture has zero extracted text, and password PDF still blocks unauthenticated extraction.
- Updated the generated Stage 4 workflow for n8n 2.29 OpenAI node V2 `response` operation, strict JSON Schema output, dynamic model IDs, explicit context reattachment after file nodes, one-off CLI execution, and password-PDF short-circuit handling.
- Verified Stage 4 live n8n/OpenAI smoke with Docker running: `f01-clean-current` used text extraction and returned `ON_FILE`; `f04-scanned-clean-current` used PDF vision fallback and returned `ON_FILE`; `f11-not-a-certificate` returned `NOT_A_COI` and `ignore_not_certificate`; `f18-password-protected` returned `PDF_PASSWORD_PROTECTED` and `NEEDS_REVIEW` without crashing.
- Updated `coi-demo-build-plan.md` to make OpenAI node V2 the default model-call path.
- Updated `coi-demo-build-plan.md` to make HTTP Request a fallback only.
- Updated `coi-demo-build-plan.md` to make Gmail approval the default and Telegram optional.
- Updated `coi-demo-build-plan.md` to add IMAP as a disabled non-Google fallback and SMTP as a generic outbound fallback only.
- Updated `01-vendor-coi-chase.md` to replace the old IMAP/OCR/Sheets architecture with Gmail/OpenAI node V2/Postgres.
- Updated `build-plan.md` to clarify that SMTP is not required for the Gmail demo path.

## Outstanding Risks To Track

- n8n licensing for any hosted-for-client or multi-tenant production model remains ambiguous.
- ACORD copyright affects fixtures and marketing materials.
- Model provider pricing and model IDs are temporally unstable; verify before Stage 1.
- Gmail OAuth, public webhook URLs, and approval buttons are the most likely demo failure points.
- The system cannot detect mid-term policy cancellation, forged certificates, missing vendors never entered into the register, or actual endorsement status.

## Next Action

Begin Stage 5 intake storage: persist accepted Stage 4 storage-ready results into `certificates` and `coverages`, retain original PDFs, and prepare manager review/notice handoffs.
