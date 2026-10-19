# Technical retrospective: vendor COI chasing

Created: 2026-10-19. Status: rendered draft for review. Not published or queued.

Audience: people hiring AI engineers and applied AI engineers. This task intentionally expands COI as certificate of insurance and explains vendor paperwork for readers outside property management. It overrides the older buyer-only audience and glossary guidance for this artifact.

Document title: **I built a COI chaser. One approval wasn't enough.**

Editable source: `docs/carousels/technical-retrospective-vendor-coi.html`.
Copy + build source: `scripts/build-technical-retrospective.cjs`.
Review PDF: `docs/carousels/out/technical-retrospective-vendor-coi.pdf`.
Contact sheet: `docs/carousels/out/technical-retrospective-preview.png`.

Prepare fonts once: bundled Python, `scripts/prepare-carousel-fonts.py` (fonttools; downloads official Fontshare faces to ignored tmp/ and repairs their internal family names for reliable PDF embedding).
Build: `node scripts/build-technical-retrospective.cjs`.
Render: `.\scripts\generate-linkedin-carousel.ps1 -Name technical-retrospective-vendor-coi`.
Verify + preview: bundled Python, `scripts/verify-technical-retrospective.py`.

## LinkedIn caption

I built an AI workflow for a recurring administrative job: collecting contractor insurance certificates, recording their dates, surfacing missing or expiring paperwork, and drafting renewal reminders.

I used n8n for orchestration and Postgres for durable state. OpenAI transcribes printed facts and drafts wording. JavaScript and SQL control identity matching, validation, filing and chase eligibility. Each vendor-facing chase email requires its own human approval.

Three failures made the engineering interesting.

The batch approval step created pending rows for many vendors but sent only one real approval request. Looping through the same Wait node did not fix it. I moved approval and sending into a separate execution per vendor, then checked two independent waits, approvals and sends.

My reminder issue key included the urgency bucket. Moving from 15 days before expiry to 14 changed the key, bypassing the follow-up window and resetting the ignored-request count. I removed the bucket so the issue keeps its history as urgency changes.

My intake routing depended on a field only the manual entry path supplied. Form and Gmail uploads failed because that field was missing. I replaced the comparison with an encryption check and routed extraction errors to review. Then I checked the actual upload form, including filing, unreadable-document and non-certificate paths.

The carousel covers the architecture, output contract, reproducible exports, these defects and the evidence behind the fixes. A filed certificate is paperwork on record, not confirmation of insurance coverage. The additional-insured checkbox stays an assertion in the schema.

I checked the connected behavior through SQL checks, separate Gmail approval executions, form uploads and byte-matched PDF retrieval. I looked at stored and delivered outputs alongside execution status.

Next I would expand document evaluation and add durable message and attachment identity, bounded retries, visible failure handling, monitoring, protected public routes, and tested recovery. The engineering lesson I took from this build: define what the model may decide, preserve the state that future actions depend on, and verify the output a person actually receives.

## Slide copy and diagrams

The diagram text below is public content. Evidence references are internal notes and do not appear in the PDF. Diagrams explain implementation; none imitates a screenshot or claims to be an observed model response.

### Slide 1

**Title:** I built a COI chaser. / One approval / wasn't / enough.

**Body:** I automated certificate tracking and renewal reminders. Then a batch approval defect forced me to change the execution boundary.

**Diagram / labels:**

n8n / OpenAI / Postgres / Gmail

**Footer:** Applied AI · Vendor certificate chasing

**Evidence:** progress-notes.md: 2026-08-08 per-vendor approval architecture fix; Stage 5/6 exports.

### Slide 2

**Title:** Track the paperwork. / Keep the source.

**Body:** I built this to track contractors' certificates of insurance. n8n coordinates the steps; Postgres holds durable state for intake, reminders and the dashboard.

**Diagram / labels:**

Intake
Gmail / / upload form
→
Save PDF + / extract facts
→
Validate + / file result


↕ &nbsp; Postgres · Certificate facts + outreach history &nbsp; ↕
Daily chase
Select due / paperwork
→
Draft + / log pending
→
Human approval / then Gmail


Dashboard + original PDF links read the stored record

**Footer:** Implemented · Six runtime workflows · Paperwork tracking only

**Evidence:** All six Stage 5-7 runtime exports; db/postgres/001-schema.sql, 003-stage-5-intake.sql, 004-stage-6-watch-chase.sql, 005-stage-7-dashboard.sql; docs/how-the-system-works.md.

### Slide 3

**Title:** I give the model / a narrow job

**Body:** I kept filing and chase decisions outside the model. A confidence label is self-report; it does not establish calibrated accuracy or insurance status.

**Diagram / labels:**

Model
Transcribe printed facts
Report self-confidence
Draft reminder wording

Code + people
Match vendor identity
Check dates and limits
Approve each chase email


Deterministic identity
Normalized exact name → Link vendor
Near or unmatched → Review

**Footer:** Implemented · Incoming documents never create vendors

**Evidence:** coi-stage-4-validator.js findVendorMatch; 003-stage-5-intake.sql exact-match link and VENDOR_NOT_FOUND; Stage 6 approval workflow; extraction and drafting prompts.

### Slide 4

**Title:** Schema sets shape. / Code sets disposition.

**Body:** I preserve what the page asserts. A checked box cannot establish an endorsement. Soft flags remain visible on filed records; ON_FILE is a storage status.

**Diagram / labels:**

Extraction contract · Selected fields
Field / rule Configured constraint
additionalProperties false
extraction_confidence HIGH | MEDIUM | LOW
addl_insd_asserted boolean; checkbox assertion
Invalid dates / LOW confidence → NEEDS_REVIEW
Matched + soft flags only → ON_FILE + flags
Not a COI / older document → Notice; no filing

**Footer:** Configuration + implemented rules · No coverage judgment

**Evidence:** docs/schemas/coi-extraction.schema.json; coi-stage-4-validator.js validateExtraction/buildResult; 003-stage-5-intake.sql notice dispositions.

### Slide 5

**Title:** One validator. / Reproducible exports.

**Body:** I keep rules in source because editing embedded workflow code would fork the logic until the next rebuild. Generated exports make the deployed graph inspectable.

**Diagram / labels:**

01 Shared JavaScript + JSON Schema
One validator feeds the core harness and live intake.

02 Generators → workflow JSON
I change source, then regenerate reviewable exports.

03 Import + verify
Credentials bind in n8n. Real routes and stored outputs matter.

**Footer:** Implemented build pipeline · Credential secrets stay outside Git

**Evidence:** scripts/generate-stage-4-workflow.js and generate-stage-5-workflows.js read validatorSource/schema; Stage 5-7 generators and verify scripts; workflow credential references.

### Slide 6

**Title:** The approval gate / only paused once

**Body:** I found pending rows for everyone but only one real approval request. In this n8n setup, a Wait node could pause each execution only once.

**Diagram / labels:**

Before · One execution for the whole batch
Many vendors
→
One Gmail wait
→
Missing results / read as declined


Looping back into the same wait also failed.
Fix · One child execution per vendor
Execute Workflow / mode: each
→
Own wait
→
Own approval / then send


Recorded check: 2 waits → 2 approvals → 2 sends

**Footer:** Recorded fix · Independent approval executions

**Evidence:** progress-notes.md 2026-08-08: decoded flatted execution data, failed Split In Batches attempt, two independent waits and approvals eight seconds apart; generate-stage-6-workflows.js mode each; stage-6-vendor-approval-request.json.

### Slide 7

**Title:** A new bucket / bypassed the cooldown

**Body:** I removed the bucket from the issue key and checked equality across buckets. The seven-day follow-up window and ignored-request count now survive urgency changes.

**Diagram / labels:**

Before · Issue identity included urgency
vendor + certificate + bucket + expiry
15 days left / 30d bucket
→
14 days left / 14d bucket
→
New key / Cooldown lost

After · Stable issue identity
vendor + certificate + expiry
Checked: same key across buckets

**Footer:** Recorded fix · Key equality checked · Existing 16 SQL checks passed

**Evidence:** 004-stage-6-watch-chase.sql stage_6_vendor_issue_key; progress-notes.md 2026-07-31 fix and equality verification. Existing tests derive keys through the function, not independent literal expectations.

### Slide 8

**Title:** My intake checks used / the wrong context

**Body:** I replaced an internal-field comparison with an encryption check and an extraction-error route. Then I verified the fix through the actual upload form.

**Diagram / labels:**

Before · Unreadable PDF FAIL
After · Error output REVIEW

Form / Gmail → Missing internal field → Routing error
Fix: inspect PDF bytes + catch extraction failures
Byte checks alone miss filesystem-backed binary

Form checks: filing, review and notice routes

**Footer:** Recorded fix · Unreadable documents reach review

**Evidence:** progress-notes.md 2026-08-07 form intake fix: undefined fixture_id on form/Gmail, byte-level /Encrypt fast path, filesystem-binary limitation, continueErrorOutput guard; multipart form checks f01/f03 ON_FILE, f18 NEEDS_REVIEW, f11 notice. Current Stage 5 generator and export.

### Slide 9

**Title:** What the recorded / checks establish

**Body:** I checked stored rows, independent approvals and retrieved PDF bytes. The checks cover filing, review, notices and renewals across the connected workflows.

**Diagram / labels:**

Evidence Recorded result
Intake checks Filing, review, notice / and renewals passed
Watch + storage 18 + 8 checks passed
Approval repair 2 waits; 2 approvals; / 2 sends
October intake ON_FILE + byte-matched PDF
Unreadable PDF NEEDS_REVIEW

**Footer:** Recorded workflow, SQL and source-document checks

**Evidence:** docs/stage-8-fixture-results.md 2026-07-30 original suite; progress-notes.md 2026-08-05 18/8 checks, 2026-08-08 approval repair, 2026-10-10 fresh manual intake and byte-identical source route. No new service execution for this carousel.

### Slide 10

**Title:** What I would / improve next

**Body:** I would protect public routes and test storage and restore. Source-reference checks exist; full mailbox replay protection, retries and monitoring remain unbuilt.

**Diagram / labels:**

01 Expand document evaluation
Held-out documents; repeat runs; field and routing errors.

02 Make failures visible
Bounded backoff, dead letters, alerts, heartbeat and canary.

03 Protect state and recovery
Message + attachment identity; concurrent runs; uncertain sends.

**Footer:** Next changes · Evaluation, recovery and operational visibility

**Evidence:** 003-stage-5-intake.sql source_ref checks; docs/stage-9-production-readiness-plan.md and implementation-backlog.md; 004-stage-6-watch-chase.sql test-mode defaults; progress-notes.md current boundaries. Held-out evaluation and concurrency tests are proposed here, not recorded implemented work.

## Evidence boundaries and design review

- Stage 8's original report predates later approval, model and intake repairs. Its all-pass status is historical; this draft does not claim the full suite was rerun after those repairs.
- The third defect now covers the recorded intake-context failure and its verified form-path repair. Public copy focuses on implementation and specific checked behavior, without demo or synthetic-data framing, per the owner's 2026-10-20 revision request. This wording does not introduce a client deployment, accuracy score or customer-result claim.
- Structured output constrains shape; it does not guarantee factual correctness or deterministic model behavior. LOW confidence and date failures route to review, but NOT_A_COI and older documents take notice dispositions first. Unknown names reach review in storage even if the core validator returned store_on_file.
- Duplicate source_ref checks exist. Message-plus-attachment identity, safe concurrent processing and send crash recovery are not established by those checks.
- Two distinct approval waits and sends establish the repaired per-vendor interaction in that test. They do not establish concurrency, repeated-button safety or exactly-once delivery.
- Reference sources inspected read-only: renewal-retention technical retrospective HTML/PDF/content document; maintenance-triage carousel kit HTML/CSS and rendered post 5. Cream ruled paper, grain, Switzer, restrained Zodiak and meaning-based blue/gold annotations follow those references.
- This draft introduces shared technical layouts in the existing stylesheet. Annotation colors are independent of shape and selection boxes may appear inside the deck, per the current user direction. No per-deck style block or inline presentation styling is used.
- PDF, contact sheet and page renders are ignored build output. Sources, caption, evidence map and QA scripts are committed.

## Review verification

Final review completed 2026-10-20. Ten pages at 810 x 1012.5 points; seven embedded Switzer/Zodiak faces, no fallback families; one shared grain bitmap. All public text runs and character counts survive extraction. Text bounds and privacy checks pass, including PDF metadata, absent links and attachments. Every page was rendered at approximately 1080 x 1350 and visually reviewed along with the contact sheet; final changed pages were rechecked. No clipping, overlaps, missing marks or diagram errors remain. QA details are regenerated to ignored `docs/carousels/out/technical-retrospective-qa.json`.

This task did not rerun the live n8n fixture suite or send email. Claims use the implementation and recorded results cited above. No publishing or queue action was taken.
