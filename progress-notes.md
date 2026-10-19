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
- Fixed the Stage 6 issue-key defect: `stage_6_vendor_issue_key` no longer includes the bucket, so follow-up suppression and the two-strike escalation count now carry across 60d/30d/14d/EXPIRED transitions instead of resetting at each boundary. `bucket_value` is retained in the signature for existing callers. Verified that the same vendor, certificate, and expiry now produce one key across buckets, and all 16 `verify-stage-6-watch.ps1` checks still pass; the existing tests were unaffected because they compute keys through the same function rather than hardcoding strings.
- Added chase visibility to the Stage 7 dashboard: `stage_7_dashboard_rows` gained `last_chased_at`, `chase_follow_up_due`, `chase_count`, `chase_paused`, and a rendered `display_chase` string, sourced from a new per-vendor `outreach_summary` aggregate over `outreach_log`. Added a Chase column to the desktop table and mobile cards, plus a muted `.chase-cell` style. The function is now dropped before creation because `CREATE OR REPLACE` cannot change a function's OUT parameters.
- Extended `verify-stage-7-dashboard.ps1` to require the Chase column header and the `Not yet chased` state in rendered HTML.
- Verified the dashboard live: HTTP 200, Chase column renders, forbidden-word scan still clean, and the chased branch renders as `Chased today (2 requests), follow-up Aug 4` when exercised in a rolled-back transaction.
- Wording for the chase column deliberately avoids `approved`, which is a forbidden dashboard term; it reports chased counts, follow-up dates, and paused state instead.
- Added a vendor-facing upload link to Stage 6 chase emails. New `stage_6_upload_form_url` config key defaults to `http://localhost:5678/form/coi-intake` and is surfaced through `stage_6_actionable_vendors`, which is now dropped before creation because its row type changed. `Prepare Stage 6 Draft Payload` builds `drafted_body_html` by HTML-escaping the drafted text, converting newlines to `<br>`, and appending one sentence offering a reply-with-attachment or an anchor reading `certificate upload link`. The Gmail send node switched from `emailType: text` to `html`.
- Kept the link out of the model's hands: it is appended after the 120-word and forbidden-word checks, so the model cannot invent a URL and the boilerplate does not count against the drafted word limit. `drafted_body` still stores the plain text for the outreach audit trail.
- The approval email deliberately shows the raw upload URL on an `Upload link:` line, because the approver is reviewing what is about to be sent and needs to check the destination; only the vendor-facing email hides it behind anchor text.
- Verified offline that the built HTML escapes vendor names containing `&` and `<`, that the URL appears only inside the `href`, and that no URL text is visible in the rendered body. Reapplied Stage 6 SQL, confirmed the config value and `upload_form_url` output, and reran `verify-stage-6-watch.ps1` with all 16 checks passing. Reimported and republished both Stage 6 workflows and restarted n8n; all five demo-facing workflows report active.
- Found 17 of 18 vendors carrying `chase_paused = true` from earlier escalation testing, which would have made the Stage 6 watch find almost nothing actionable during a demo. `reset-demo.ps1` clears it. This was invisible before the dashboard chase column existed.
- Added `docs/how-the-system-works.md` as the plain-language reference for the full system behaviour: intake paths, storage-before-reading ordering, text versus vision reading, the hard/soft/note flag vocabulary with severities, filing outcomes, manual cancelled/non-renewed statuses, watch buckets and cadence, the approval gate and escalation, dashboard status wording, storage locations, refusals, real limits, and a troubleshooting map.

2026-08-01:

- Added `.agents/product-marketing.md` as the shared positioning/voice context that marketing and writing skills read before acting, drafted from `docs/customer-language.md`, `docs/how-the-system-works.md`, `docs/demo-script.md`, and `01-vendor-coi-chase.md`. Recorded `.agents/` in the project structure section of `CLAUDE.md` and `AGENTS.md`.
- Added `docs/linkedin-post-scripts.md` with finished copy for all 15 posts briefed in `docs/linkedin-content-plan.md`. Content work only; no build behaviour changed.
- Two documentation gaps found while sourcing claims for that copy, both still open:
  1. The 2010 ACORD revision claim at `coi-demo-build-plan.md:575`, that cancellation notice moved to the policy terms and away from the certificate holder, carries no external citation. Every neighbouring claim does. It was excluded from published copy until it can be sourced, and it should either gain a citation or be softened in the build plan.
  2. `docs/stage-9-data-processing-retention.md` covers retention for paying clients only, defaulting source PDFs to 24 months. It says nothing about the free ten-certificate diagnostic used as the sales entry point, where the intended commitment is deletion on delivery. Needs a short diagnostic-handling section so that commitment is not held only in marketing copy.
- Confirmed while writing: git history for this build runs 2026-07-31 to 2026-08-01, so no duration claim longer than that is supportable from the repo.

2026-08-02:

- Audited the 15 LinkedIn posts against "would a property manager learn something and keep this." Seven failed. Root cause was the pillar-to-format allocation: four of five pillars were seller-centric, and the only teaching pillar had been assigned almost entirely to text, so proof-of-work occupied carousels and video while teaching sat in the cheapest format.
- Rewrote `docs/linkedin-content-plan.md` around five new pillars: AI buying literacy (new, 4 posts), insurance domain literacy (5), failure lessons anyone can apply (3), proof and operating model (2), the ask (1). Format split is unchanged. Replaced the accessibility standard "a property manager should feel described", since recognition is not value.
- Rebuilt seven posts in `docs/linkedin-post-scripts.md`. Posts 1, 4 and 9 replaced outright; posts 8, 12, 13 and 14 kept their evidence and changed subject from what the build does to what the reader can check. Posts 2, 3, 5, 6, 7, 10, 11 and 15 unchanged, spliced programmatically to prevent drift.
- Corrected framework labels that did not match the slides. Posts 1 and 4 were labelled Problem-Proof without a numbered claim or a receipt artifact; relabelled rather than inventing both to satisfy the label.
- Ran the Seven Sweeps over the rebuilt seven. Four findings fixed: the word "tokens" was jargon for this buyer and appeared three times in post 4; post 1 promised more than its slides delivered; post 1 said "rates how sure it is" where the system returns high/medium/low; posts 1 and 13 closed on an identical construction, fixed by restoring post 13's approval-email receipt slide. Heightened Emotion was declined deliberately, as its techniques break the incident-report register.
- Updated `.agents/product-marketing.md` to v2 with a Content principles section, and dropped the uncited 2010 ACORD revision from its proof table. The uncited claim at `coi-demo-build-plan.md:575` remains open.

2026-08-05:

- Expanded `docs/how-the-system-works.md` from roughly 4,000 to about 9,200 words. Added an opening problem-statement section (what happens in the office, why it stays broken, what existing property management software does and does not do, the two ways the problem surfaces, and the framing that this is an attention problem rather than a judgement problem) and a closing implementation section covering what does not change for a client, what tools they already have that it uses, the five configuration pieces, the office's week afterwards, hosting and ownership, the controls still required before reliance, the responsibility split, and exit/export. Every existing section gained the reasoning behind the behaviour.
- Found that `last_attested_at` was never written by any workflow, so a vendor with good paperwork on file still satisfied the `RE_ATTEST` condition and appeared in that bucket. Confirmed empirically against the live database: a clean certificate 237 days from expiry returned bucket `RE_ATTEST`. Fixed later the same day, see below.
- Renamed the demo-facing workflow display names to drop build-stage prefixes: `COI Intake`, `Source Document Route`, `Daily Watch and Chase`, `Non-PDF Reply Notice`, `COI Dashboard`, and `Extraction and Validation Core` for the non-running harness. Workflow IDs, node names, webhook paths, and form paths are unchanged, so all CLI commands and script references still work.
- Made the renames in the `scripts/generate-stage-*` generators rather than in the JSON exports, then regenerated. Updated the name strings used for import and cleanup in `verify-stage-4-extraction.ps1`, `verify-stage-5-intake.ps1`, `verify-stage-6-workflows.ps1`, `verify-stage-7-dashboard.ps1`, and `verify-stage-8-fixtures.ps1`.
- Added canvas sticky notes to the five demo-facing workflows through a new `sticky()` helper in each generator: six on `COI Intake`, four on `Daily Watch and Chase`, one each on the other three. They explain the three intake paths, the non-PDF refusal, the manual-fixture test branch, storage before reading, the text/vision split, the validation boundary, the daily watch and bucket order, draft-then-log ordering, the approval gate and its 24-hour expiry, and the dashboard being a view rather than an application. Verified programmatically that no sticky overlaps another and that every node is fully enclosed by one.
- Updated the stale rationale paragraphs in `docs/demo-script.md` and `docs/how-the-system-works.md` that previously argued for keeping the stage prefixes, and updated the workflow-name references in `docs/demo-script.md`, `docs/how-the-system-works.md`, and `docs/linkedin-post-scripts.md`. Left the build-stage headings in `build-plan.md` and the historical log entry in this file unchanged, since neither is a workflow name.
- Verified after the change: all six workflow JSON exports parse with unique node IDs and intact connections, Stage 4 offline validator tests pass, all five workflows import and report active in n8n, the dashboard returns HTTP 200 and renders the reset register, and demo state is 18 vendors with zero certificates, coverage rows, notices, outreach rows, and paused vendors.
- Fixed the `last_attested_at` defect in `db/postgres/003-stage-5-intake.sql`. `store_stage_5_intake_result` now records an attestation date on the vendor whenever it files a certificate as `ON_FILE`. It uses the certificate's own `certificate_date` rather than the current date, so an old-but-still-current certificate does not reset the 90-day clock to today, and it wraps the assignment in `GREATEST` so the date only ever moves forward. Added an idempotent backfill in the same migration for deployments that already hold filed certificates with a NULL attestation date.
- Verified the fix empirically through the real storage function inside a rolled-back transaction: `last_attested_at` moved from NULL to `2026-07-30`, and the vendor moved from bucket `RE_ATTEST` to not actionable.
- Added two regression checks to `.\scripts\verify-stage-6-watch.ps1`, using `Northstar Snow Removal LLC` because every other seeded vendor is already claimed by an existing check: filing a certificate records the attestation date, and a freshly filed certificate is not re-attest actionable. The pre-existing `re-attest bucket exists` check still passes because it seeds certificates by direct SQL and sets `last_attested_at` explicitly, so it exercises the bucket logic rather than the storage path.
- Verified after the fix: all 18 `.\scripts\verify-stage-6-watch.ps1` checks pass, all 8 `.\scripts\verify-stage-5-storage.ps1` checks pass, and the demo was reset to 18 vendors with zero runtime rows.
- Note for onboarding: a vendor imported into the register who has never sent a certificate still has a NULL attestation date and is therefore re-attest actionable. That is correct behaviour, not the defect above, and it is why vendors that should not be chased are paused during onboarding.

2026-08-05, later session:

- Found that `gpt-5.4-nano` no longer reads the synthetic fixtures as certificates. It returns `is_certificate_of_insurance: false` with HIGH confidence and the reason "This is a synthetic vendor insurance summary, not a certificate of insurance", so every fixture became a `NOT_A_COI` notice and no certificate was filed. The runs completed successfully with no error, so the failure is silent and the board simply stays empty. This is model drift; nothing in the repo changed to cause it. `coi-demo-build-plan.md` had warned against the nano tier and recommended the mini tier.
- Sharpened rule 7 of the extraction prompt in `scripts/generate-stage-5-workflows.js` and `scripts/generate-stage-4-workflow.js`. It now says to judge the document by structure and fields rather than styling or provenance, and states that a SPECIMEN, SAMPLE, DRAFT, COPY or TEST DOCUMENT watermark describes the copy rather than the kind of document. The fixture watermark is a deliberate ACORD copyright mitigation and must not be removed, so the prompt is the correct place to fix this.
- Changed the `model_id` seed in `db/postgres/002-seed.sql` from `gpt-5.4-nano` to `gpt-5.4-mini`. The seed uses `ON CONFLICT DO UPDATE`, so it overwrites local config on every `apply-stage-2` run; leaving the seed at nano would have silently reverted the model the next time any verify script ran.
- Verified after both changes, one fixture per execution: `f01`, `f03`, `f05`, `f06`, `f07`, `f16`, and `f20` all file certificates, `f11-not-a-certificate` still produces a notice and no certificate, and `f18-password-protected` still produces a `NEEDS_REVIEW` record without erroring.
- `model_id_fallback` remains `gpt-5.6-luna`, which returns `Bad request` on this OpenAI account and is therefore not a working fallback. Left unchanged because no replacement has been tested. Outstanding.
- Batch behaviour is unreliable and single-item behaviour is not. Running several fixtures through one manual-trigger execution filed an inconsistent subset each time, with different fixtures failing on each run. Running one fixture per execution filed all of them. Demo staging must therefore be one upload at a time, which is what the demo script already instructed for other reasons.
- Rewrote `docs/demo-script.md` in a one-to-one conversational register, restructured every scene into on screen / you do / you say / why, and corrected four claims that did not match live behaviour:
  1. The board does not come up with several green rows. Only Apex Plumbing is green. Four rows are amber, almost all because a GL-only certificate raises `NO_WC_LINE` and only Mason Creek Handyman is seeded `wc_exempt`.
  2. `f18-password-protected` does not put Rapid Response Restoration into Needs review. A locked PDF yields no vendor name, so the review record attaches to no vendor, and the dashboard is one row per vendor. Nothing visible changes on the board.
  3. Executing the daily watch on the staged board produces 13 approval emails, not one: 12 `NEVER_RECEIVED` vendors plus the lapsed Circuit Square. The script now says the number out loud as part of the narration and warns not to reopen the mailbox on camera after approving.
  4. Added a model preflight as step 1 of the pre-recording checklist, since a wrong `model_id` breaks staging silently.
- Added a documented fallback to the script for recording without working Gmail OAuth: Scenes 2 to 6 and 8 to 10 do not touch Gmail, Scene 1 can open the upload form instead of the mailbox, and Scene 7 should be re-recorded rather than faked.

2026-08-05, mailbox change:

- The demo Gmail account changed to `sambhavn8n@gmail.com` because OAuth on the previous account stopped working. Updated `stage_6_approver_email` and `stage_6_test_recipient_email` in local `client_config`, and updated the example SQL in `docs/stage-6-watch-chase-runbook.md`. Earlier log entries in this file still name the old address; those are historical records of runs that happened and are left as written.
- Recorded in the runbook and the demo script that the n8n credential must be named exactly `Gmail account`. All four Gmail nodes bind to it by name: `Gmail Trigger - COI Intake`, `Gmail Trigger - Stage 6 Replies`, `Gmail Approval - Send and Wait`, and `Gmail Send Approved Stage 6 Chase`. A credential created under a different name leaves those nodes unbound, and the symptom is an approval email that never arrives rather than a visible error.
- No workflow JSON changed. Mailbox identity lives in `client_config` and in the named credential, not in the exports, so switching accounts is a SQL update plus a credential.

2026-08-05, model change and route repair:

- Switched `model_id` to `gpt-5.6-luna` as requested, with `gpt-5.4-mini` moved to `model_id_fallback`. Luna had previously looked unusable because it returned `Bad request`. The real cause was `Unsupported parameter: 'temperature' is not supported with this model`, not the model ID. Removed the hardcoded `temperature: 0` from all four OpenAI nodes across the Stage 4, 5 and 6 generators. Determinism for extraction comes from the strict JSON schema and the transcribe-only prompt, not from the sampling parameter, and the model ID is a runtime setting so hardcoding a parameter some models reject was always fragile.
- Verified on luna, one fixture per execution: all seven demo fixtures file, `f11-not-a-certificate` is still refused, and `f18-password-protected` still produces a review record.
- Fixed a regression I introduced earlier the same day. The generators assigned `webhookId` by array index (`nodes[0]`, `nodes[1]`), and the sticky notes added to the front of each nodes array shifted every index, so the IDs landed on sticky notes. `Webhook - COI Dashboard` ended up carrying the stable-URL ID, and three routes had no `webhookId` at all. The upload form at `/form/coi-intake` and the stable dashboard URL both returned 404 while all five workflows still reported active. Replaced index assignment with a `setWebhookId` helper that looks nodes up by name and throws if the name is missing.
- Also added a `webhookId` to `Form Trigger - Certificate Upload`, which never had one from the generator.
- All five local URLs now return 200: n8n editor, `/form/coi-intake`, `/webhook/coi`, `/webhook/stage-7-dashboard-webhook/coi`, and pgweb. Dashboard source links resolve to real PDF bytes through `/webhook/stage-5-source-document-webhook/coi-source/<id>`.
- Tested the new Gmail account end to end. `stage_6_actionable_vendors` resolved `actual_recipient` to `sambhavn8n@gmail.com`, the approval email sent, and the execution moved to `waiting`. The credential is present and named `Gmail account`.
- Found and fixed two defects in the chase email while testing it. `normalizeModelOutput` in `Prepare Stage 6 Draft Payload` checked `typeof value.output === "object"`, which is true for arrays, so it returned the raw Responses API array before the array branch could run; that branch then called `JSON.parse` on `content[0].text`, which arrives already parsed as an object. Every chase email therefore silently discarded a good model draft and fell back to the fixed template. `formatDate` appended `T00:00:00Z` to values that were already full ISO timestamps from Postgres, producing an invalid date and falling through to the raw value, so the email read `expires 2026-06-26T00:00:00.000Z`.
- Both rewritten and unit-tested offline against every shape: Responses array with an object payload, Responses array with a JSON string payload, a direct object, a JSON string, and null. Re-ran the live chase afterwards: `draft_source` is now `openai` and the body reads "the expiration date of June 26, 2026".
- Verified after all changes: 18 of 18 Stage 6 watch checks, 8 of 8 Stage 5 storage checks, and the Stage 4 offline validator all pass. Demo reset to 18 vendors with zero certificates, coverage rows, notices, outreach rows and paused vendors.

2026-08-07, recording blocked by dated storage path:

- A demo recording failed on the first upload. `Write Original PDF To Storage` errored with `The file or directory does not exist`, and the intake run stopped there. Nothing else was broken.
- Cause: certificates are written to `data/certificates/YYYY/MM/DD`, and the n8n write node cannot create parent directories. Confirmed against the node source in the running container: the write operation exposes only `append`, `fileName` and `dataPropertyName`, with no create-directories option. The dated path rolls over at UTC midnight, so a stack that worked on 2026-08-05 failed on 2026-08-07 with no configuration change.
- Fixed by running `.\scripts
eset-demo.ps1`, which creates the current UTC date path. Verified end to end afterwards: fixture filed, PDF present on disk at the dated path, dashboard row rendered, and the container can both read and write the directory through the bind mount.
- Separately observed that the whole `data/certificates/2026` subtree was empty at one point during this session, including previously written day folders. `reset-demo.ps1` does not delete anything under the storage root, so the cause is not the reset script and is unresolved. It is recoverable in one command, so it does not block recording, but treat a missing dated folder as expected rather than surprising and re-run the reset.
- Made the trap hard to miss: the demo script now runs the reset as step 2 of the pre-record sequence with an explanation of why, the pre-recording checklist leads with it, and the stall section carries the exact error text and the one-command fix. Sharpened the Stage 5 storage note in `AGENTS.md` and `CLAUDE.md` to say the node cannot create directories and that the path rolls over daily.

2026-08-07, form intake fix and dashboard ordering:

- `Route Password Protected PDF` failed every form and Gmail upload. Its condition compared `$json.fixture_id` against the literal `f18-password-protected` with `typeValidation: strict`. Only the manual fixture path sets `fixture_id`, so on the two paths a real certificate actually arrives on, the left side was `undefined` and strict validation failed the node rather than routing. Every one of my earlier intake tests used the manual trigger, which is why this was missed.
- The same condition also meant password protection was only ever detected by fixture name. A genuinely locked PDF sent by a vendor would have been routed as readable.
- Fixed in two layers. `Reattach PDF Context After Storage` now sets `is_password_protected` by looking for an `/Encrypt` entry in the document's own bytes, and the routing node checks that boolean with loose validation. Verified against the fixtures: only `f18` contains `/Encrypt`.
- That fast path cannot see the bytes when n8n stores binary on the filesystem rather than inline, which is the case here, so the real guard is the second layer: `Extract Text From Stored PDF` now uses `onError: continueErrorOutput`, and its error output routes to `Mark Password Protected Review Result`. Any document extraction cannot read now lands in review instead of failing the run.
- Verified through the actual form endpoint with multipart uploads, not the manual trigger: `f01` files as `ON_FILE`, `f18` returns 200 and produces a `NEEDS_REVIEW` record with no vendor attached, `f11` produces a `NOT_A_COI` notice and no certificate, and `f03` files as `ON_FILE`.
- Reversed the dashboard ordering for recording. `stage_7_dashboard_rows` previously ranked worst first, so clean rows sat at the bottom. Ranks are now inverted: clean, then note-carrying, then coverage gap, expiring, expired, review, and vendors with nothing on file last. The tie-break moved from `days_to_expiry NULLS FIRST` to `days_to_expiry DESC NULLS LAST` to match. To go back to worst-first, invert the seven values in both the `sort_rank` column and the `ORDER BY`.
- Note the tradeoff: worst-first surfaced the vendors most easily forgotten, which is the behaviour `docs/how-the-system-works.md` describes as deliberate. Best-first reads better on camera but buries the rows that need attention. Revisit before any client relies on the board.
- Hit the known PowerShell BOM gotcha again while running `.\scriptserify-stage-7-dashboard.ps1`: the import failed with `Unexpected token`, and because the verifier deletes before importing, it left `Source Document Route` missing from n8n entirely. Restored by piping the export through the Bash tool, reactivating, and restarting. Worth remembering that a failed verify run can remove a demo-facing workflow.
- Final state verified: storage folder present, all five URLs 200, all five workflows active, model `gpt-5.6-luna`, and the board reset to 18 vendors with zero runtime rows. A live form upload files correctly and its dashboard source link returns real PDF bytes.

2026-08-08, per-vendor approval architecture fix:

- User reported: running the daily watch against many actionable vendors produced only one Gmail approval email, not one per vendor as documented.
- Investigated live rather than from memory. First hypothesis (stated to the user and later corrected): approving one vendor causes the Send-and-Wait node to advance and send the next vendor's request. Disproved by decoding the actual execution data with n8n's own `flatted` library run inside the container (`docker compose exec n8n node -e "require('flatted').parse(...)"`, the only way to read `execution_data.data`, which is not plain JSON). The real mechanism: `Gmail Approval - Send and Wait` given N items sends a real message and pauses for item 0 only; resuming it resolves the *entire array* in the same instant. Every item after the first came back with no approval data, read as `approved: false`, and was logged with `declined_at` a few dozen milliseconds after the real click, without ever generating a message. Confirmed the one mercy: `send_response` was empty for the falsely-declined rows, so no unauthorized email had gone out; the damage was bookkeeping, not delivery.
- First fix attempt (`Split In Batches`, batch size 1, looped back into the same Gmail node) also failed, and this was verified rather than assumed: item 2 was declined 39ms after item 1's real approval, same signature as the original bug. Root cause: an n8n Wait node can only pause a given execution once, ever. A second pass through the same node in the same execution resolves near-instantly with stale state rather than creating a fresh pause.
- Real fix: split the approval-through-send-or-decline segment into its own workflow, `n8n-workflows/stage-6-vendor-approval-request.json` (id `stage-6-vendor-approval-request`, display name `Vendor Approval Request`), triggered by an `Execute Workflow Trigger` set to `inputSource: passthrough`. `Daily Watch and Chase` now ends its per-vendor chain at `Prepare Approval Email Payload`, then calls the new workflow once per actionable vendor through `Call Stage 6 Vendor Approval` (`n8n-nodes-base.executeWorkflow`, typeVersion 1.1, `mode: each`, `workflowId` as a `workflowSelector` resource-locator object with `.value` set to the target ID). Confirmed by reading the installed node's own source in the container (`ExecuteWorkflow.node.js`) that at typeVersion 1.1 the `workflowId` parameter only needs a `.value` field and no `workflowInputs` resource-mapper is required, since that field only applies at typeVersion >= 1.2.
- Verified conclusively with a real 2-vendor test: decoded both sub-executions' data and found each independently reached `Gmail Approval - Send and Wait` with its own `waitTill` roughly 24h out, for two different vendor names. Then the user accidentally approved both from Gmail in one sitting; server-side state showed two distinct Gmail message IDs, two independent `approved_at` timestamps 8 seconds apart, and zero cross-contamination.
- Fixed a related indexing bug in `buildSentLogPayloadCode` while there: it built sent-log context by joining `sendItems` (the real Gmail Send output) against `$items("Recover Approval Result Context")`, which returns every item that node ever produced regardless of which IF branch it later took, so declined items could be paired with the wrong `send_response` by index. Sourced context from `$items("Route Approved Stage 6 Email", 0, 0)` instead, the IF node's own true-branch output, which only ever contains items that actually took that path.
- Updated `scripts/verify-stage-6-workflows.ps1` and `scripts/verify-stage-8-fixtures.ps1` to import and activate `stage-6-vendor-approval-request` before executing `stage-6-daily-watch-chase`; the parent's Execute Workflow call fails outright if the target is not yet importable and active.
- Hit the documented PowerShell BOM import failure once during this work, on the newly three-workflow Stage 6 import sequence; it deleted `Vendor Approval Request` before the import failed and left it missing from n8n. Recovered via the documented Bash-pipe workaround. Not a regression, the existing gotcha note already covers it, but it is worth knowing the exposure now spans three sequential imports instead of two.
- Updated `docs/how-the-system-works.md` (six workflows now, not five; rewrote "The Chase, And The Approval Gate" to describe the split and explain why it exists; added a troubleshooting line for partial batches), `docs/demo-script.md` (Scene 7 rewritten: approval emails now arrive together rather than one at a time, prep steps updated to have the presenter pick one vendor's email in advance, watch-out-for bullets corrected), and `AGENTS.md`/`CLAUDE.md` (new gotcha paragraph on the Wait-node-pauses-once constraint and the Execute Workflow "each" pattern as the only real fix; workflow display-name list and demo-facing-workflow-ID note both extended to include `Vendor Approval Request`).
- Verified after all changes: all six workflows import, activate, and report Active; all local URLs return 200; a live two-vendor test produces two independent waits, two independent approvals, two independent Gmail sends, and zero declined-by-accident rows.

## Open Behaviour Findings

Recorded 2026-07-31 from a read-only review of Stage 6 and Stage 7 behaviour prompted by demo-rehearsal questions. Items 1 and 2 were implemented and verified later the same day; item 3 remains blocked. Item 4 was found and fixed on 2026-08-05. Status is marked on each.

1. RESOLVED 2026-07-31. Bucket transitions bypass follow-up suppression and reset the escalation counter. `stage_6_vendor_issue_key` in `db/postgres/004-stage-6-watch-chase.sql` composes the key from vendor, certificate, bucket, and expiration date. All suppression and counting in `stage_6_actionable_vendors` is scoped to that key: `has_pending_approval`, `has_active_follow_up`, and `ignored_request_count`. Because the bucket is part of the key, a vendor crossing a boundary becomes a new issue, so the `stage_6_follow_up_days` interval of 7 does not apply and the `HAVING count(*) >= 2` escalation threshold in `stage_6_escalate_overdue` starts again. A certificate expiring in 15 days therefore chases on day 0 in the `30d` bucket and again on day 1 in the `14d` bucket, and `chase_paused` takes longer to engage than the stated "after two ignored requests". Candidate fixes: drop `bucket` from the issue key so a vendor's expiry is one continuous issue, or add a per-vendor cooldown that outranks bucket transitions. Either changes Stage 6 behaviour and the Stage 6 verification expectations, so it needs an explicit decision first. Treated as the most likely real defect of the three.

2. RESOLVED 2026-07-31. No outreach or chase data reaches the dashboard. `stage_7_dashboard_rows` in `db/postgres/005-stage-7-dashboard.sql` returns vendor, trade, certificate, carrier, policy number, GL limit, expiry, display status and tone, source path, flags, coverage-gap marker, cancellation wording, and manual status fields. It returns no outreach columns at all: no last-chased date, no `follow_up_due`, no request count, and no bucket. Chase history is visible only through `outreach_log` in pgweb, so the demo's main screen shows none of the chasing half of the product.

3. PARTIALLY RESOLVED 2026-07-31, still blocked for non-local use. Chase emails now carry a `stage_6_upload_form_url` link, defaulting to the local form at `http://localhost:5678/form/coi-intake`, rendered as the anchor text `certificate upload link` in an HTML email. This is usable for local testing only; a vendor off this machine cannot reach it, so the public HTTPS decision in Open Decisions item 2 still gates real use. Original finding follows. Chase emails contain no vendor-facing upload link, and cannot yet. Neither the OpenAI draft prompt nor the `fallbackDraft` templates in the Stage 6 workflow include a link, so a vendor's only routes are replying with an attachment or sending a separate email. The Stage 5 upload form exists only at `http://localhost:5678/form/coi-intake`, so no linkable URL exists until the public HTTPS method in Open Decisions item 2 is chosen.

4. RESOLVED 2026-08-05. Every vendor with current paperwork was permanently re-attest actionable. `store_stage_5_intake_result` in `db/postgres/003-stage-5-intake.sql` never wrote `last_attested_at`, the column has no default, and no workflow or UI path set it. The `RE_ATTEST` branch in `stage_6_actionable_vendors` treats `last_attested_at IS NULL` as "never confirmed", so a vendor stayed in that bucket no matter how recently they had filed a good certificate. Proven against the live database before the fix: a clean certificate 237 days from expiry returned bucket `RE_ATTEST`. This was not visible in normal demo staging because `NEVER_RECEIVED` is evaluated first and the demo is usually reset to a state with no certificates at all, so it only surfaced once certificates were filed and the watch was run. Fixed by recording the certificate's own date on the vendor at filing time, with a backfill for existing rows and two regression checks in `.\scripts\verify-stage-6-watch.ps1`.

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

## Work Sample

2026-09-28 work sample revision: Expanded `output/pdf/vendor-coi-automation-work-sample.pdf` to a nine-page Upwork case study after the two-page version proved too thin. It now covers all six demo-facing workflows, the architecture, intake stages, fixture evidence, and production scope limits. Direct local n8n editor captures for all six workflows are stored in `docs/work-sample-assets/` so the PDF can be rebuilt with `scripts/render-upwork-work-sample.py`. The wide intake canvas appears in full and as enlarged sections; screenshots were checked for visible nodes, clean routing, and no overlaps. The register image is rendered by the actual dashboard workflow with illustrative synthetic rows. PDF QA: nine pages, rendered and visually inspected; extracted text and metadata have no email addresses, URLs or phone-like contact details. The local demo is not described as a client or production deployment.

2026-09-29 readability revision: User found the nine-page PDF's copy too light. Root cause was the embedded Manrope variable font's default weight 200. The renderer now instantiates static Manrope 550/700 and Geist 650 weights before embedding, uses darker ink/green colors, white page background, and larger body, label, caption, and footer type. Re-rendered all nine pages and visually reviewed them at normal size; content, synthetic labeling, and direct n8n screenshots remain intact.

2026-09-29 prospect copy revision: Removed inaccessible repository file paths, internal stage references in captions, and production caveat blocks from the nine-page Upwork sample. The architecture and verification pages now explain the connected behavior and passed synthetic tests in client-facing language. The local-demo/synthetic-data label remains on every page so the sample does not imply a client deployment. Re-rendered pages 2, 5, and 9 for layout review.

2026-09-29 workflow explanation revision: Gave Daily Watch and Chase and Vendor Approval Request separate screenshot pages with explicit trigger, processing, decision, and output explanations. The work sample is now ten pages; synthetic labeling and contact-free copy remain in place. Re-rendered and reviewed the revised workflow pages at normal viewing size.


2026-10-10 execution-evidence revision: Rebuilt the Upwork work sample as 24 pages covering all six main workflows with actual in-app n8n captures after using Tidy Up, readable branch views, client-facing explanations and connected execution/output proof. The public PDF no longer uses the illustrative dashboard image. Inspected existing state and backed up business tables before any demo; no reset was run. Restored UI visibility for selected retained executions (4091, 4288, 4376, 4397, 4403, 4407, 4420, 4450) by clearing their retention deletion markers; execution data and original dates were preserved. August evidence includes three form certificates, 17 pending outreach rows, Northstar outreach 10 approved/sent, Vista outreach 15 declined, and 10 no-PDF notices from approval messages in the test mailbox. Do not describe those notice messages as vendor replies or portal submissions.

Fresh manual intake execution 4606 on 2026-10-10 processed the single clean Apex fixture using real OpenAI, stored certificate 6 as ON_FILE, and left its original PDF on disk. Created only today's storage folder and temporarily selected the one fixture; restored the fixture selector afterward. The live register showed Apex current through 2027-03-30. Its source route returned HTTP 200/application-pdf and exactly matched the stored PDF bytes; source execution 4614 succeeded. No fresh Gmail send was performed. The signed-in demo Gmail mailbox no longer returned the historical COI emails in All Mail/Trash searches, so the public sample uses the genuine preserved Gmail approval and send-node responses, with original dates disclosed.

Rebuild: `python scripts/render-upwork-work-sample.py` (ReportLab, Pillow, fonttools); fonts and flattened approved assets are now self-contained under `docs/work-sample-assets/`. `scripts/prepare-work-sample-images.py` uses private originals under ignored `tmp/work-sample-evidence/`, and `python scripts/verify-work-sample-pdf.py` checks text privacy, metadata, absent links/attachments, footer coverage, text bounds and pixel-exact provenance of embedded crops. QA passed: 24 pages rendered at 120 dpi and visually reviewed, plus revised pages rechecked; 27 embedded image uses matched approved flattened PNGs. No contacts, repository paths, video thumbnails, personal identifiers or sensitive message IDs remain in the final artifact. Fonttools was installed into the bundled Python runtime; static font weights remain 550/700 Manrope and 650 Geist.

## Next Action

2026-10-20 technical retrospective draft:

- Added a ten-slide hiring-focused LinkedIn carousel and complete caption in `docs/technical-retrospective-carousel.md`, with slide-level evidence references and explicit implemented/recorded/proposed boundaries. Source is generated by `scripts/build-technical-retrospective.cjs` into `docs/carousels/technical-retrospective-vendor-coi.html` using shared technical layouts in `carousel-template.css`.
- Read current workflow generators/exports, validator, extraction schema, SQL, runbooks and recorded checks against the older plans. The story covers durable state, model/code/human responsibility, structured extraction and dispositions, reproducible exports, per-vendor approval execution repair, the bucket-dependent issue-key defect and model rejection of synthetic fixtures. The historical Stage 8 pass is kept separate from later targeted repairs and the October intake/source check. No general accuracy, concurrency/crash-safety, client result or fresh full-suite claim is made.
- Inspected renewal-retention's completed retrospective source/content/PDF and maintenance-triage's annotation source and rendered post 5 without editing those repositories. Added meaning-based blue/gold technical annotations and interior selection boxes per the current user direction; prior published-deck layouts remain unchanged.
- Font QA found official CDN faces whose internal family names were `false`, producing colliding subsets and fallback glyph fonts. `scripts/prepare-carousel-fonts.py` caches the official faces under ignored `tmp/carousel-fonts/` and repairs local name records. Diagram arrows are SVG so they do not pull in Arial. Both rendering helpers guard the cache prerequisite; preview also rebases its stylesheet URL. Added the workaround to AGENTS/CLAUDE and the carousel README.
- Rendered review PDF and contact sheet under ignored `docs/carousels/out/`. `scripts/verify-technical-retrospective.py` passed: 10 pages, 810 x 1012.5 pt, seven embedded Switzer/Zodiak faces, no fallback fonts, one shared grain bitmap, all text runs/counts preserved, text bounds and privacy including metadata, no PDF links or attachments. Visually inspected all ten page renders at readable resolution and the final contact sheet; revised crowded pages and rechecked final changed pages. PDF is approximately 197 KB.
- Rebuild: prepare fonts once with bundled Python plus fonttools; `node scripts/build-technical-retrospective.cjs`; `.\scripts\generate-linkedin-carousel.ps1 -Name technical-retrospective-vendor-coi`; bundled Python `scripts/verify-technical-retrospective.py`. This task did not change automation behavior, rerun live services, send email, publish the carousel or add it to a queue. It remains a draft for the owner's review.

Run the full end-to-end demo rehearsal sequence, then complete pre-live external checks before any prospect demo.

2026-10-20 retrospective copy revision:

- At the owner's request, removed demo/synthetic-data framing and deployment/result disclaimers from the public carousel and LinkedIn caption. Public wording now focuses on implemented mechanisms, recorded behavior checks and proposed next improvements without adding deployment or customer-result claims. Evidence provenance remains in internal notes.
- Replaced the watermark/model-configuration defect slide with the recorded intake-context defect: form/Gmail routing depended on a manual-path-only field; the fix inspects PDF encryption and routes extraction errors to review, verified through the actual form endpoint. Updated the caption's third failure and evidence map accordingly.
- Regenerated the ten-page PDF and contact sheet. Font embedding, text preservation, bounds and privacy checks passed. Checked that the public HTML and caption contain none of demo/synthetic/fixture; visually reviewed the contact sheet and all changed pages. Agent-guidance checkpoint found no new technical gotcha requiring another guidance change. No publishing or queue action taken.

2026-10-20 problem-solving rewrite:

- Owner changed the audience and editorial direction to property management buyers plus hiring managers. Rewrote all ten slides and the caption around the recurring paperwork problem, the connected process, design choices, concrete failures and observable checks. Removed the public technology list, schema/configuration excerpts, internal workflow terminology and test-count table. The public title is now `I built a follow-up process for vendor paperwork.`; stable source/output filenames remain unchanged.
- The story now explains missing/expiring paperwork and due follow-ups; individual approval before chase emails; original documents linked to records; the one-request approval defect; urgency changes restarting follow-up; unreadable-document review; and next improvements in plain language. Recorded checks remain attributed internally, with no deployment, accuracy or customer-result claim added. Proposed visibility/repeat-handling/recovery work is still explicitly next work.
- Added a shared vertical story-route layout and spacing between process lanes. The unreadable-document diagram follows the real ordering: save the original before attempting extraction, then keep a review record on failure. Reviewed the caption for flow and sourced meaning; approximately 1,860 characters. Public-copy check excludes stack names, schema/SQL/JSON terminology and demo/synthetic/fixture wording.
- Rebuilt and checked the PDF: ten 810 x 1012.5 pt pages, embedded Switzer/Zodiak without fallback, one shared grain bitmap, preserved text runs/counts, safe text bounds and privacy checks. Visually reviewed all ten pages and the contact sheet, then rechecked the revised responsibility-column alignment. No live service run, send, publishing or queue action. Added the durable mixed-audience writing direction to `.agents/product-marketing.md` and referenced it consistently from AGENTS/CLAUDE.
