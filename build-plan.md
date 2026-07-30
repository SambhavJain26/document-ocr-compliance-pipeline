# Vendor COI Chasing - Staged Development Plan

Created: 2026-07-30

Source documents read:

- `01-vendor-coi-chase.md`
- `coi-demo-build-plan.md`
- `foundation-1-vendor-insurance.md`

This plan is for a demo-depth build of an automated vendor certificate-of-insurance paperwork tracker for US residential property managers. It is intentionally scoped as administrative relief: ingest certificates, extract and store date facts, surface expiring or missing paperwork, draft chase emails, and require human approval before any outbound vendor message.

The system must never claim that a vendor is compliant, verified, covered, or approved. It records what the certificate says and helps chase paperwork.

## Important Gaps, Conflicts, and Approval Gates

These must be resolved before or during the named stage. They are not blockers to having a plan, but they are blockers to implementation choices.

1. The user request said "both documents" but listed three files. I read all three and treated all three as required context.
2. `01-vendor-coi-chase.md` proposes Google Sheets and Telegram notifications. `coi-demo-build-plan.md` supersedes that with Postgres, a custom webhook HTML dashboard, Gmail approval by default, and Telegram as optional. This plan follows the newer demo build plan because it addresses reliability, licensing, and demo friction.
3. The original architecture includes OCR Bro. The later plan rejects OCR nodes entirely and uses text extraction first, then model PDF vision fallback. This plan follows the later text-first/PDF-fallback architecture.
4. Model provider for the demo is OpenAI through n8n's built-in OpenAI node V2 because current n8n supports the Responses API, PDF file message input, and JSON Schema output. Use HTTP Request only as a fallback if the installed n8n version cannot expose the required API settings.
5. Public HTTPS method is not chosen. Options include Cloudflare Tunnel, Caddy on a VPS, or another public reverse proxy. Approval needed before Stage 1 because n8n approval buttons depend on `WEBHOOK_URL`.
6. The later document mentions Telegram as a centerpiece in early research, then corrects to Gmail approval as the default. This plan uses Gmail approval as default and keeps Telegram only for optional manager alerts or prospects who already use it.
7. Production hosting has a licensing ambiguity under n8n's Sustainable Use License if one multi-tenant n8n instance is used for multiple paying clients. Demo on our own instance is fine; production should be client-hosted or clarified with n8n.
8. Fixture generation must avoid reproducing ACORD copyrighted forms. Fixtures must be layout-similar synthetic documents, visibly watermarked, with no ACORD logo or copyright notice.

## Stage 1 - Environment, Accounts, and Public n8n

Goal: establish the local/demo infrastructure and external accounts without building business logic.

In scope:

- Confirm Docker Desktop or Docker Engine works on the target machine or VPS.
- Create the local project structure for n8n/Postgres deployment files and environment notes.
- Choose and configure the public HTTPS path for n8n webhooks.
- Stand up self-hosted n8n and Postgres with persistent volumes.
- Set core n8n environment variables: `WEBHOOK_URL`, `N8N_HOST`, `GENERIC_TIMEZONE`, and `N8N_ENCRYPTION_KEY`.
- Set up the model API account and hard spend limit, recommended at `$10`.
- Set up one demo Gmail/Google Workspace account or OAuth-capable mailbox for local intake, approvals, and outbound test email. Use plus-address aliases for logical test roles if needed.
- Optionally create a Telegram bot and chat ID for manager alerts.

Out of scope:

- Database schema beyond basic connection testing.
- AI extraction prompts.
- Any dashboard, workflow, fixture, or business-rule implementation.
- Any PMS integration.
- Any SMS setup.

Verification:

- `docker compose up -d` starts n8n and Postgres.
- n8n is reachable at a public HTTPS URL.
- A simple n8n Webhook test URL opens from a phone on mobile data.
- n8n can connect to Postgres.
- n8n can make a trivial authenticated OpenAI node request.
- Gmail OAuth send/approval test succeeds. SMTP is not required for the Gmail demo path.
- If Telegram is configured, a test message reaches the intended chat.

## Stage 2 - Database Schema, Client Config, and Seed Vendors

Goal: create the persistent data model and seed a realistic empty vendor register.

In scope:

- Create tables for `vendors`, `certificates`, `coverages`, `outreach_log`, `client_config`, `holder_entities`, and `trade_requirements`.
- Seed `client_config` with minimum limits, reminder cadence, re-attestation cadence, approval channel, from mailbox, timezone, and model ID.
- Seed `holder_entities` with the demo management company and accepted owner LLC names.
- Seed `trade_requirements`, including default requirements plus distinct examples for roofing and landscaping.
- Seed around 18 demo vendors, ideally using a prospect's real vendor names if available; otherwise use synthetic names.
- Include at least one `wc_exempt = true` sole-proprietor-style vendor.

Out of scope:

- PDF processing.
- AI extraction.
- Inbound email triggers.
- Dashboard UI beyond optional database inspection.
- Chasing/reminder logic.

Verification:

- All seven tables exist.
- Seed queries return expected config values, holder entities, trade requirements, and vendor rows.
- Vendor names normalize deterministically.
- Per-trade minimum lookup works with fallback to default.
- No certificate rows exist yet; the register is seeded with vendors but empty of documents.

## Stage 3 - Synthetic Test Fixtures

Goal: build a safe, repeatable fixture set before wiring the full workflows.

In scope:

- Create a fixture specification for synthetic certificate-like PDFs.
- Generate synthetic PDFs using layout-similar but non-facsimile designs.
- Add a visible `SPECIMEN - SYNTHETIC TEST DOCUMENT` watermark.
- Avoid ACORD logo, ACORD copyright notice, or pixel-accurate ACORD replicas.
- Include fixtures for clean/current, expiring soon, expired, fake scan, inverted dates, wrong holder, low limits, multiple expiry dates, missing GL, two attachments, non-certificate, renewal/supersede, coverage gap, WC-exempt vendor, accepted owner LLC holder, near-duplicate vendor, password-protected PDF, portal-link email, and cancellation-notice wording.

Out of scope:

- n8n workflow implementation.
- Real client document processing.
- Marketing screenshots using copyrighted form layouts.

Verification:

- Fixture set regenerates from a single command or repeatable process.
- Every generated fixture is visually plausible, synthetic, and watermarked.
- Each fixture has documented expected behavior.
- The fake scanned fixture has no reliable text layer and is suitable for testing the vision fallback.
- Password-protected and non-certificate fixtures fail gracefully in isolated manual tests where possible.

## Stage 4 - Extraction and Validation Core

Goal: prove that a single certificate can become schema-valid JSON and deterministic validation flags.

In scope:

- Build the text extraction path using n8n `Extract From File`.
- Add routing based on extracted text length, using text branch when text is adequate and PDF vision branch when it is not.
- Implement model extraction using n8n's built-in OpenAI node V2 when available.
- Configure OpenAI `Generate a Model Response` with PDF File input for scanned-PDF fallback and JSON Schema output for structured extraction.
- Use HTTP Request only if the installed OpenAI node cannot express the required PDF file input, JSON Schema settings, model ID, or failure handling.
- If using OpenAI, use strict JSON Schema Structured Outputs where exposed and handle model refusals or node errors.
- If using Anthropic, use HTTP Request with prompt-based JSON extraction, defensive parse handling, and one retry.
- Implement deterministic validation and normalization logic:
  - date parse and expiration-after-effective checks
  - plausible date range check
  - general liability presence flag
  - holder matching against `holder_entities`
  - limit checks against trade-specific requirements
  - low-confidence hard route
  - not-a-certificate hard route
  - older-than-on-file prevention
  - coverage-gap detection on renewal
  - WC exemption suppression
  - near-duplicate vendor review
  - absence of cancellation-notice wording for high-risk trades, surfaced as a neutral document note
- Store raw extraction and validation flags in a testable shape.

Out of scope:

- Full Gmail intake workflow.
- Multi-attachment handling.
- Dashboard.
- Reminder/chase workflow.

Verification:

- Clean/current fixture returns schema-valid JSON with correct vendor, producer, holder, coverage, policy number, dates, limits, and checkbox assertions.
- Fake scan routes through the vision branch and returns the expected expiry with `MEDIUM` or lower confidence as appropriate.
- Hand-written validation test inputs exercise every validation flag.
- Validation never lets a hard failure silently become `ON_FILE`.
- Field names preserve honest semantics, especially `addl_insd_asserted` and `cancellation_notice_wording`.

## Stage 5 - Intake Workflow End to End

Goal: process inbound PDFs into persistent certificate and coverage records.

In scope:

- Build Workflow 1 from form upload through filtering, extraction, validation, storage, and manager notice.
- Add Gmail Trigger as a second intake path into the same processing flow.
- Add IMAP Email Trigger as a disabled fallback intake path for non-Google clients.
- Filter to PDF attachments only.
- Handle multi-attachment emails by processing each PDF independently.
- Store original PDFs to a mounted volume and record `stored_path`.
- Expose stored PDFs through a safe webhook route for dashboard links.
- Implement vendor matching, new certificate insert, `NEEDS_REVIEW`, `ON_FILE`, and `SUPERSEDED` storage behavior.
- Prevent older certificates from overwriting newer records.
- Route non-certificate inputs to a clear manager notice without creating vendor records.

Out of scope:

- Reminder/chase workflow.
- Approval-gated outbound vendor email.
- Full dashboard polish.
- Production-grade idempotency and dead-lettering unless a simple version is needed for demo reliability.

Verification:

- Uploading the clean fixture through the form creates one certificate row and expected coverage rows.
- Emailing the expiring fixture to the demo inbox produces the same result within the polling window.
- The disabled IMAP fallback path exists and can be enabled later without changing downstream processing.
- Renewal fixture supersedes the old certificate and leaves an audit trail.
- Re-uploading an older certificate does not regress current data.
- One email with two PDFs creates two independent certificate records.
- Non-certificate input creates no vendor record and sends a clear manager notice.
- Source PDF links open from the stored path route.

## Stage 6 - Daily Watch, Drafting, Approval, and Escalation

Goal: turn stored certificate facts into human-approved chase actions.

In scope:

- Build Workflow 2 with Schedule Trigger and Manual Trigger.
- Query one actionable row per vendor using the earliest expiring active coverage.
- Implement bucket ordering exactly: `NEVER_RECEIVED`, `EXPIRED`, `14d`, `30d`, `60d`, `RE_ATTEST`, then `none`.
- Suppress chase actions when `vendors.chase_paused = true`.
- Draft vendor/producer chase emails using the OpenAI node by default, or HTTP Request only if required by provider/version constraints.
- Address renewal requests to the producer where available and copy the vendor where configured.
- Add Gmail `Send and Wait for Response` approval as the default human gate.
- Keep Telegram approval as optional based on `client_config.approval_channel`.
- Set a 24-hour approval wait limit.
- On approval, send the email and log `sent_at`, recipient, draft body, and `follow_up_due`.
- On decline, log the decline and send nothing.
- Add escalation when follow-up is overdue and no newer certificate has arrived.
- After two ignored requests, alert the manager and set `chase_paused = true`.
- Add non-PDF reply handling for plain text replies and portal-link emails.
- Add manual status override support for `CANCELLED` and `NON_RENEWED` with note and attribution.

Out of scope:

- SMS escalation.
- Endorsement verification.
- Automatic portal-link fetching.
- Carrier or AMS connectivity.
- PMS write-back.

Verification:

- A vendor with no certificate enters `NEVER_RECEIVED`, not `none`.
- Expired, 14-day, 30-day, 60-day, and re-attestation buckets classify correctly against fixed test dates.
- Drafted emails are under 120 words, reference the correct vendor, policy number, and expiry date, and contain no coverage/compliance claims.
- Approval email renders working Approve/Decline buttons in an ordinary mail client.
- Approval is tested from a phone not logged into n8n.
- Approved messages send from the configured mailbox and are logged.
- Declined messages are logged and not sent.
- Backdated follow-up rows escalate and pause further automated chasing.
- Text-only and portal-link replies produce manager notices and are not silently dropped.
- Manual `CANCELLED` or `NON_RENEWED` status turns the vendor actionable and visible without pretending the system detected cancellation.

## Stage 7 - Dashboard and Demo View

Goal: build the single-screen register that makes the demo understandable.

In scope:

- Build Workflow 3: Webhook GET `/coi`, Postgres SELECT, HTML generation, Respond to Webhook.
- Render one full-width dashboard page with no app framework and no login for demo.
- Show columns: Vendor, Trade, Carrier, Policy #, GL Limit, Expires, Status, Source.
- Compute header counts dynamically.
- Sort `NEVER_RECEIVED` rows near the top.
- Render status as date facts only:
  - `Current until <date>`
  - `Expires in <n> days`
  - `Expired <n> days ago`
  - `No certificate on file`
  - `Needs review`
- Render flags as small amber notes under the vendor name.
- Give `COVERAGE_GAP` a visible header count and row note.
- Render cancellation-notice wording as a neutral note only.
- Link every row with a source document to the stored PDF.
- Auto-refresh every 5 seconds for the live demo.

Out of scope:

- Authentication or user management.
- Editable dashboard controls except any minimal manual override path needed from Stage 6.
- Generic admin-panel features such as filtering, sorting controls, exports, or charts.
- Marketing/landing-page content.

Verification:

- Dashboard renders all seeded vendors and processed certificates.
- Colors match state: green for current, amber for expiring/soft flags, red for expired or needs review, grey for no certificate.
- Source PDF links open in a new tab.
- Header counts change after processing a new fixture.
- Rendered HTML contains none of these forbidden words: `compliant`, `verified`, `covered`, `approved`.
- The page is readable on a laptop screen during screen share.

## Stage 8 - Full Fixture Run, Demo Reset, and Rehearsal

Goal: make the demo repeatable and recoverable before using it with prospects.

In scope:

- Run every fixture through the full pipeline.
- Record actual versus expected results in a results table.
- Fix only issues that affect the promised demo behavior or honesty boundary.
- Create a reset routine that clears certificates, coverages, and outreach logs while leaving vendors and config intact.
- Prepare the demo opening state: 18 vendors, several no-certificate rows, no stale execution state.
- Record a fallback screen capture of a successful run, including the approval moment.
- Rehearse the live script, including the alternate path when Gmail polling is slow.
- Test public webhook and approval links from mobile data immediately before rehearsal.

Out of scope:

- Production reliability features not required for demo.
- New product features.
- Client onboarding documents.
- SMS.

Verification:

- All fixtures either match expected behavior or have documented accepted deviations.
- Reset returns the demo to its opening state in under two seconds or with one reliable command.
- A complete demo run finishes in roughly four minutes.
- Fallback video exists and is accessible from the demo machine and phone.
- Failure recovery paths are rehearsed:
  - Gmail trigger delay -> form upload
  - approval link failure -> n8n execution approval fallback
  - model/API failure -> preprocessed row or fallback video
  - internet failure -> hotspot or fallback video

## Stage 9 - Production Readiness Plan

Goal: define what must be added before the first paying client relies on the system.

In scope:

- Decide production hosting model, preferably client-hosted or client-owned VPS.
- Add n8n Error Trigger workflows.
- Add retry with backoff around model calls and Gmail sends.
- Add a dead-letter table or visible failure queue.
- Add idempotency using message ID plus attachment hash.
- Add heartbeat workflow that alerts if expected workflows have not run.
- Add weekly canary certificate test.
- Add weekly client digest.
- Add dashboard uptime monitoring.
- Add documented Postgres backup and restore test.
- Add one-page scope document using the "what you must not claim" limitations.
- Add data processing terms and retention settings.
- Add client onboarding checklist:
  - vendor import
  - holder entities
  - trade requirements
  - mailbox approval setup
  - approver training
  - exit/export plan

Out of scope:

- Enterprise compliance verification.
- Endorsement interpretation.
- Live carrier policy status.
- Multi-tenant SaaS packaging unless n8n licensing is resolved in writing.
- SMS unless registered under the client's own entity.

Verification:

- Simulated workflow failure sends an alert with workflow name and execution link.
- Duplicate email does not create duplicate active certificate rows.
- Canary certificate processes end to end.
- A missed heartbeat alerts.
- Backup restores into a clean database.
- Scope document contains the explicit limitation that the system tracks certificate paperwork and does not verify coverage.
- Client can export workflows and database data if the engagement ends.
