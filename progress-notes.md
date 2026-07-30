# Vendor COI Chasing - Progress Notes

Created: 2026-07-30

## Current Status

Stage 1 local environment scaffolding has been implemented and verified on this machine. Rechecked `coi-demo-build-plan.md` once after the initial plan and made small planning corrections. Rechecked current n8n/OpenAI documentation on 2026-07-30 and changed the recommended model-call implementation from HTTP Request-first to built-in OpenAI node V2-first.

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
| 1 | Environment, Accounts, and Local n8n | In progress | Local Docker Compose environment verified. Public HTTPS intentionally deferred because all Stage 1 testing is same-machine only. Manual OpenAI and Gmail credential smoke tests remain. |
| 2 | Database Schema, Client Config, and Seed Vendors | Not started | Depends on Stage 1 Postgres access. |
| 3 | Synthetic Test Fixtures | Not started | Must avoid ACORD form/logo/copyright reproduction. |
| 4 | Extraction and Validation Core | Not started | Depends on fixture set and OpenAI node V2 availability. |
| 5 | Intake Workflow End to End | Not started | Depends on extraction core. |
| 6 | Daily Watch, Drafting, Approval, and Escalation | Not started | Depends on stored certificate records. |
| 7 | Dashboard and Demo View | Not started | Depends on populated database and status logic. |
| 8 | Full Fixture Run, Demo Reset, and Rehearsal | Not started | Depends on full demo workflow. |
| 9 | Production Readiness Plan | Not started | Should not begin until demo-depth build is proven. |

## Open Decisions

1. Exact OpenAI model ID for the demo:
   - Provider/node choice is decided: OpenAI through n8n's built-in OpenAI node V2, using Responses API, PDF File input, and JSON Schema output.
   - Current balanced default for Stage 1 notes: `gpt-5.6-luna`, because it is the cost-sensitive GPT-5.6 model while avoiding the lowest-cost nano tier for demo-critical extraction.
   - Fallback if fixture quality is insufficient: `gpt-5.6-terra`.
   - Store the chosen model in `client_config.model_id` during Stage 2 rather than hardcoding workflow nodes.
   - Fallback: OpenAI via HTTP Request if the installed n8n version lacks required controls.
   - Alternative only if OpenAI is unavailable: Anthropic via HTTP Request with prompt-only JSON and defensive parsing.

2. Public HTTPS method for n8n:
   - Deferred for Stage 1 because the demo build is being built and tested locally on this machine only.
   - Current local default: `WEBHOOK_URL=http://localhost:5678`.
   - Revisit Cloudflare Tunnel, Caddy on VPS, or another public reverse proxy before testing approval links from a phone or running a live prospect demo.

3. Approval channel:
   - Recommended default: Gmail `Send and Wait for Response`.
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
- Confirmed model default as balanced `gpt-5.6-luna`, keeping `gpt-5.6-terra` as fallback and avoiding nano as the default.
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

Complete the remaining Stage 1 manual checks in n8n: create the local owner account, add/test the Postgres credential, add/test the OpenAI credential with a `$10` spend limit, and add/test the Gmail OAuth credential from this machine. Do not begin Stage 2 schema work until those checks are recorded.
