# Vendor COI Chasing - Progress Notes

Created: 2026-07-30

## Current Status

Stage 1 local environment scaffolding and credential smoke verification are complete on this machine. Stage 2 database schema and synthetic seed register are complete and verified. Stage 3 synthetic fixtures are generated and verified. Stage 4 extraction and validation core is complete with offline validator tests and live n8n/OpenAI fixture smoke passing locally. Stage 5 intake workflow and persistent storage are complete with deterministic SQL checks and live n8n/OpenAI fixture smoke passing locally. Stage 6 daily watch, drafting, approval-gate workflow, non-PDF reply notices, manual overrides, and escalation are implemented with deterministic SQL checks plus live same-email Gmail approval/send smoke passing locally. Stage 7 dashboard and demo view are implemented with the Postgres read model, generated n8n dashboard webhook, rendered HTML checks, and source-PDF link verification passing locally. Stage 8 demo reset, full fixture rehearsal verification, committed fixture results, and local demo runbook are complete; the verifier passed locally and left the demo reset. Stage 9 production-readiness planning is complete with hosting, controls, scope, retention, onboarding, backlog, and verification artifacts. Research-grounded demo and prospect documents are now added for recorded sales walkthroughs and non-technical prospect review. Rechecked `coi-demo-build-plan.md` once after the initial plan and made small planning corrections. Rechecked current n8n/OpenAI documentation on 2026-07-30 and changed the recommended model-call implementation from HTTP Request-first to built-in OpenAI node V2-first.

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
| 5 | Intake Workflow End to End | Complete | Added Stage 5 SQL storage function, intake notices, generated intake/source workflows, local PDF storage mount, form/Gmail/manual intake normalization, source-PDF route, and storage/intake verification scripts. Live fixture smoke passed locally. |
| 6 | Daily Watch, Drafting, Approval, and Escalation | Complete | SQL bucket/suppression/escalation/manual override logic verified. Stage 6 workflows import and publish in n8n. OpenAI draft, Gmail Send-and-Wait approval, and approved Gmail send passed locally using `worksambhav26@gmail.com` as both approver and test recipient. |
| 7 | Dashboard and Demo View | Complete | Dashboard read model, generated n8n webhook, responsive HTML register, dynamic counts, source PDF links, and forbidden-language guard verified locally. |
| 8 | Full Fixture Run, Demo Reset, and Rehearsal | Complete | Added fast local reset, full fixture verifier, committed fixture results table, and rehearsal runbook. Live Stage 8 verifier passed locally with no accepted deviations and reset final state to 18 vendors with zero runtime rows. |
| 9 | Production Readiness Plan | Complete | Added production hosting decision, required control plan, scope/limitations document, data processing and retention terms, onboarding checklist, implementation backlog, and verifier. This is a planning gate; production controls still need implementation before client reliance. |

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
   - Stage 9 decision: default to one client per client-owned VPS or cloud account.
   - Avoid shared multi-tenant n8n hosting unless licensing is clarified in writing for that exact model.

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
- Added Stage 5 intake SQL migration with `intake_notices`, source-ref uniqueness, config defaults, and `store_stage_5_intake_result(payload jsonb)`.
- Added writable local certificate storage at `./data/certificates` mounted into n8n under `/home/node/.n8n-files/certificates`.
- Added generated Stage 5 intake workflow with manual fixture, form upload, Gmail attachment, and disabled IMAP fallback paths.
- Added generated Stage 5 source-document route with safe-path checks and binary PDF response.
- Added `scripts/generate-stage-5-workflows.ps1`, `scripts/apply-stage-5.ps1`, `scripts/verify-stage-5-storage.ps1`, and `scripts/verify-stage-5-intake.ps1`.
- Added `docs/stage-5-intake-runbook.md`.
- Updated shared validation source so storage source references prefer `context.source_ref` before fixture IDs, preserving multi-attachment idempotency.
- Updated fixture `f13-renewal-coverage-gap` so it starts 14 days after `f03-expired-34-days` ends, matching the coverage-gap expectation.
- Verified Stage 5 storage checks: clean insert, coverage insert, duplicate source skip, review preservation, non-certificate notice, older-than-current notice, unknown-vendor review downgrade, and no vendor creation.
- Verified Stage 5 live n8n/OpenAI intake smoke: clean fixture storage, source PDF route, two-attachment fixture, renewal supersede, older-upload prevention, coverage-gap renewal, non-certificate notice, password-protected review row, and portal-link notice.
- Added Stage 6 SQL migration with outreach audit columns, config defaults, `stage_6_actionable_vendors(as_of_date)`, pending/sent/declined outreach logging, overdue escalation, no-PDF reply notices, config notices, and manual `CANCELLED`/`NON_RENEWED` override support.
- Added generated Stage 6 daily watch/chase workflow and non-PDF reply notice workflow exports.
- Added `scripts/generate-stage-6-workflows.ps1`, `scripts/apply-stage-6.ps1`, `scripts/verify-stage-6-watch.ps1`, and `scripts/verify-stage-6-workflows.ps1`.
- Added `docs/stage-6-watch-chase-runbook.md`.
- Verified Stage 6 deterministic SQL behavior: never-received, expired, 14-day, 30-day, 60-day, and re-attestation buckets; earliest active coverage selection; paused vendor suppression; pending approval suppression; active follow-up suppression; one-overdue second request; two-overdue escalation and chase pause; newer-certificate stale escalation suppression; text reply and portal-link notice storage; and manual cancelled/non-renewed actionability.
- Verified Stage 6 workflow JSON parses, imports into n8n 2.29.10, publishes the two demo-facing workflows, runs an OpenAI draft smoke, and stores a config notice when approval/send addresses are blank.
- Found and fixed a Stage 6 n8n continuation issue: the escalation pre-pass can return zero rows, so its Postgres node must use `alwaysOutputData` to continue into actionable-vendor loading.
- Configured `stage_6_approver_email` and `stage_6_test_recipient_email` to `worksambhav26@gmail.com` for local same-email testing.
- Verified full Stage 6 Gmail approval/send smoke manually: one `NEVER_RECEIVED` vendor generated an approval email, the Approve button resumed n8n execution, Gmail sent the approved chase email to `worksambhav26@gmail.com`, and `outreach_log` recorded `approved = true`, `sent_at`, `actual_recipient`, `follow_up_due`, and Gmail message ID `19fb3cad4f544380`.
- Fixed Stage 6 config defaults so reapplying `.\scripts\apply-stage-6.ps1` preserves existing local approval/test email settings instead of blanking them.
- Updated `.\scripts\verify-stage-6-workflows.ps1` so configured approval/test emails trigger a live Gmail approval/send smoke; blank emails still exercise the safe config-notice path.
- Verified `.\scripts\verify-stage-6-workflows.ps1` live same-email path after the fix.
- Added Stage 7 dashboard SQL read model with one row per seeded vendor, latest manual/review/current certificate selection, earliest-expiry display facts, GL limit, source-PDF path, flag codes, coverage-gap marker, and manual status note fields.
- Added generated Stage 7 dashboard workflow export served through `/webhook/coi` and `/webhook/stage-7-dashboard-webhook/coi`.
- Added `scripts/generate-stage-7-dashboard-workflow.ps1`, `scripts/apply-stage-7.ps1`, and `scripts/verify-stage-7-dashboard.ps1`.
- Added `docs/stage-7-dashboard-runbook.md`.
- Verified Stage 7 locally: workflow JSON and Docker Compose parse, SQL applies, dashboard workflow imports and publishes, all 18 vendors render, current/expiring/expired/review/coverage-gap/manual-status/no-certificate states display correctly, rendered HTML contains none of the forbidden terms, and a dashboard source link returns PDF bytes through the Stage 5 source-document route.
- Recorded the Stage 7 n8n webhook timing gotcha in `AGENTS.md`: wait for active workflow registration after restart before probing the dashboard route.
- Added `scripts/reset-demo.ps1` to apply Stage 7 if needed, clear local runtime rows, reset vendor chase state, clear Stage 6/7 date overrides, preserve local credential/email config, and create the current UTC certificate storage path.
- Extended Stage 5 manual fixture support to the full Stage 8 PDF fixture set: `f01`-`f09`, `f11`, `f12`, `f13`, `f15`-`f18`, and `f20`; kept `f10` as two attachment-specific PDF items, `f19` as a portal-link notice, and `f14` as metadata-only reset/no-file behavior.
- Marked the generated Stage 5 IMAP fallback trigger disabled so publishing the demo intake workflow does not require unused IMAP credentials.
- Added `scripts/verify-stage-8-fixtures.ps1` to regenerate, import, and publish demo workflows; run fixture scenarios through the Stage 5 manual trigger; verify Stage 6 no-file watch behavior; verify Stage 7 dashboard/source-link behavior; write raw output under ignored `tmp/`; update `docs/stage-8-fixture-results.md`; and leave the demo reset.
- Added `docs/stage-8-demo-rehearsal-runbook.md` with reset/preflight commands, local URLs, four-minute local demo sequence, fallback lines, and manual pre-live-demo reminders for fallback video and public mobile-data validation.
- Added cancellation-notice label cleanup in the shared Stage 4 validator so `Certificate states:` is treated as a fixture label and the stored neutral notice wording remains the factual sentence.
- Verified Stage 4 validator tests after the cleanup, including the new cancellation-label assertion.
- Verified `.\scripts\reset-demo.ps1`: 18 vendors, zero certificate/coverage/notice/outreach rows, 18 dashboard rows, and 18 no-certificate dashboard rows.
- Verified `.\scripts\verify-stage-8-fixtures.ps1` live locally: all Stage 8 fixture scenarios passed, workflows imported/published, dashboard source PDF links returned PDF bytes, dashboard forbidden-word scan passed, Stage 6 no-file watch behavior passed, and final demo state was reset.
- Added opt-in Stage 8 live Gmail rehearsal switches: `.\scripts\verify-stage-8-fixtures.ps1 -IncludeLiveEmail` runs the approval/send rehearsal after the full fixture suite, and `.\scripts\verify-stage-8-fixtures.ps1 -OnlyLiveEmail` runs only the Stage 6 approval/send path.
- Investigated a missing-email report on 2026-07-31: `stage-6-daily-watch-chase` was marked inactive in `workflow_entity`, so it was republished with `docker compose run --rm --no-deps n8n update:workflow --id=stage-6-daily-watch-chase --active=true` and n8n was restarted; all five demo-facing workflows then reported active.
- Confirmed the approved Stage 6 run did complete: `outreach_log` recorded `approved = true`, `sent_at = 2026-07-30 18:26:38.925994+00`, `actual_recipient = worksambhav26@gmail.com`, and Gmail send response ID `19fb44746f7bb40e`.
- Confirmed Gmail could read final message `19fb44746f7bb40e` by ID with subject `Certificate request for Vista Glass and Door LLC`, labels `UNREAD`, `SENT`, and `INBOX`, and both sender/recipient as `worksambhav26@gmail.com`; added verifier readback so future live-email rehearsals record the final Gmail message labels.
- Added read-only pgweb to the local Docker Compose stack at `http://localhost:8081` for visual Postgres table inspection during demo rehearsal, and extended `.\scripts\verify-local.ps1` to check pgweb HTTP availability.
- Restricted pgweb navigation to COI-only read views by adding `.\scripts\apply-pgweb-viewer.ps1`, which creates/updates `coi_readonly`, exposes only the eight COI objects in schema `coi_pgweb`, locks pgweb to that connection, and restarts pgweb. Verified pgweb HTTP `200`, API schema list of only `coi_pgweb`, and readonly visibility of only the eight COI views.
- Added Stage 9 production-readiness artifacts: `docs/stage-9-production-readiness-plan.md`, `docs/stage-9-scope-limitations.md`, `docs/stage-9-data-processing-retention.md`, `docs/stage-9-client-onboarding-checklist.md`, and `docs/stage-9-implementation-backlog.md`.
- Added `scripts/verify-stage-9-production-readiness.ps1` and verified the Stage 9 artifact set covers hosting, n8n licensing, error alerts, retry/backoff, dead letters, idempotency, heartbeat, canary, digest, uptime, backup/restore, scope limits, data retention, onboarding, and exit/export.
- Added `docs/demo-script.md` with a recorded-video presentation path, exact narration, screen order, fallback lines, and certificate-paperwork honesty language for property-management prospects.
- Added `docs/prospect-overview.md` with a non-technical business explanation of the system, office-day flow, value, limits, and first implementation steps.
- Grounded the sales docs in current vendor-insurance tracking and credentialing research from Buildium, RealPage, property-manager onboarding guidance, ACORD 25 certificate language, and Texas Department of Insurance COI guidance; kept the language away from vendor-status claims such as compliant, verified, covered, or approved.

2026-07-31:

- Added `CLAUDE.md` as the Claude Code copy of the repository guidance; it mirrors `AGENTS.md` section for section, and both files now state that they must be kept in sync.
- Changed the maintenance checkpoint in both files from an `AGENTS.md`-only update to a paired update of `AGENTS.md` and `CLAUDE.md`.
- Removed stale pre-implementation wording from both guidance files: the project structure section no longer says the repo is documentation-only or offers `workflows/` as an alternative to `n8n-workflows/`, and the commands section no longer says there is no runnable app or qualifies Docker/workflow commands with "once ... exists".
- Relabelled the script list in both files from "Stage 1 local environment commands" to stage scripts run from the repo root with Docker running, since the list covers Stages 1 through 9.
- Rewrote `docs/demo-script.md` as a timed eight-scene recorded walkthrough with a marked four-minute cut, an objection section, and a pre-recording checklist.
- Fixed a recording-breaking instruction in the old demo script: it told the presenter to run `.\scripts\verify-stage-8-fixtures.ps1` on camera during the intake scene, but that verifier resets the demo when it finishes, so the recording would have ended on an empty dashboard. Fixture staging now happens before recording, and the on-camera intake moment uses the Stage 5 upload form at `http://localhost:5678/form/coi-intake`.
- Documented the pre-recording staging path in the demo script: set `client_config.stage_5_smoke_fixture_set` to a comma-separated fixture list, then run `docker compose run --rm --no-deps n8n execute --id stage-5-intake-workflow --rawOutput`. The list is processed in order, so `f03-expired-34-days` must precede `f13-renewal-coverage-gap`. This sequence is documented from the workflow and verifier source and still needs one live rehearsal run to confirm the resulting board.
- Deleted `docs/prospect-overview.md`. Its research links are preserved in `docs/demo-script.md`.
- Converted `docs/demo-script.md` to a fully UI-driven runbook with no terminal steps: staging is now seven form uploads at `http://localhost:5678/form/coi-intake`, the stack starts from Docker Desktop, workflow-active checks happen in the n8n workflow list, and Scene 6 triggers the chase by clicking Execute workflow on `Stage 6 - Daily Watch Chase` instead of running the Stage 8 verifier on camera.
- Recorded that form uploads build `source_ref` from the submission timestamp, so re-uploading the same PDF is not treated as a duplicate; it processes again and supersedes the earlier copy. This is what makes UI-only staging repeatable without a reset.
- Noted in the demo script that clearing the register to 18 blank rows is the only step with no UI path, and that it is not required for staging.
- Removed hardcoded day counts from the demo narration. Fixture dates are fixed, so countdowns drift by one per day since generation; as of 2026-07-31 `f02` reads 19 days rather than 20 and `f03` reads 35 days rather than 34.
- Reviewed Stage 6 chase cadence, reply handling, and Stage 7 dashboard coverage against demo-rehearsal questions; recorded the results under Open Behaviour Findings without changing code.
- Added `docs/how-the-system-works.md` as the plain-language reference for the full system behaviour: intake paths, storage-before-reading ordering, text versus vision reading, the hard/soft/note flag vocabulary with severities, filing outcomes, manual cancelled/non-renewed statuses, watch buckets and cadence, the approval gate and escalation, dashboard status wording, storage locations, refusals, real limits, and a troubleshooting map.

## Open Behaviour Findings

Recorded 2026-07-31 from a read-only review of Stage 6 and Stage 7 behaviour prompted by demo-rehearsal questions. No code was changed. None of these are actioned yet.

1. Bucket transitions bypass follow-up suppression and reset the escalation counter. `stage_6_vendor_issue_key` in `db/postgres/004-stage-6-watch-chase.sql` composes the key from vendor, certificate, bucket, and expiration date. All suppression and counting in `stage_6_actionable_vendors` is scoped to that key: `has_pending_approval`, `has_active_follow_up`, and `ignored_request_count`. Because the bucket is part of the key, a vendor crossing a boundary becomes a new issue, so the `stage_6_follow_up_days` interval of 7 does not apply and the `HAVING count(*) >= 2` escalation threshold in `stage_6_escalate_overdue` starts again. A certificate expiring in 15 days therefore chases on day 0 in the `30d` bucket and again on day 1 in the `14d` bucket, and `chase_paused` takes longer to engage than the stated "after two ignored requests". Candidate fixes: drop `bucket` from the issue key so a vendor's expiry is one continuous issue, or add a per-vendor cooldown that outranks bucket transitions. Either changes Stage 6 behaviour and the Stage 6 verification expectations, so it needs an explicit decision first. Treated as the most likely real defect of the three.

2. No outreach or chase data reaches the dashboard. `stage_7_dashboard_rows` in `db/postgres/005-stage-7-dashboard.sql` returns vendor, trade, certificate, carrier, policy number, GL limit, expiry, display status and tone, source path, flags, coverage-gap marker, cancellation wording, and manual status fields. It returns no outreach columns at all: no last-chased date, no `follow_up_due`, no request count, and no bucket. Chase history is visible only through `outreach_log` in pgweb, so the demo's main screen shows none of the chasing half of the product.

3. Chase emails contain no vendor-facing upload link, and cannot yet. Neither the OpenAI draft prompt nor the `fallbackDraft` templates in the Stage 6 workflow include a link, so a vendor's only routes are replying with an attachment or sending a separate email. The Stage 5 upload form exists only at `http://localhost:5678/form/coi-intake`, so no linkable URL exists until the public HTTPS method in Open Decisions item 2 is chosen.

Smaller observations from the same review, recorded but not prioritised:

- The Stage 5 Gmail Trigger filters on `readStatus: unread` with `q: has:attachment`. A vendor reply opened in Gmail before the trigger polls can be missed.
- Certificate images sent as JPG or PNG are not processed. They become `NON_PDF_ATTACHMENT` notices, since intake filters to PDFs only.
- Vendor replies are never linked to the outreach row that prompted them. Matching runs on the vendor name extracted from the certificate, and chasing stops only because a newer `ON_FILE` certificate makes the vendor non-actionable and suppresses stale escalation. The outcome is correct; the mechanism is not reply detection.
- `stage_6_outbound_test_mode` defaults to `true`, so approved sends are redirected to `stage_6_test_recipient_email` rather than the producer or vendor address. Confirm this is deliberately switched off before any client use.

## Outstanding Risks To Track

- n8n licensing for any hosted-for-client or multi-tenant production model remains ambiguous.
- ACORD copyright affects fixtures and marketing materials.
- Model provider pricing and model IDs are temporally unstable; verify before Stage 1.
- Gmail OAuth, public webhook URLs, and approval buttons are the most likely demo failure points.
- The system cannot detect mid-term policy cancellation, forged certificates, missing vendors never entered into the register, or actual endorsement status.
- Public HTTPS/mobile-data validation and fallback video recording remain manual pre-live-demo blockers.

## Next Action

Run the full end-to-end demo rehearsal sequence, then complete pre-live external checks before any prospect demo.
