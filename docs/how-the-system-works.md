# How The System Works

A plain-language explanation of what this system actually does, end to end, and which workflow is responsible for each part of it. Written for understanding the behaviour, not for editing the code.

Every section below names the workflow doing the work, and where it helps, the specific node. If you are ever looking at the dashboard wondering "what put that there", the answer is in here.

## The One-Paragraph Version

Vendor insurance certificates arrive as PDFs. The system saves each one, reads the facts printed on it, checks those facts against what you require, and files the result against the right vendor. It keeps a register showing which vendors have current paperwork and which do not. Every day it looks for paperwork that is missing, expiring, or expired, writes a reminder email for each one, and holds that email until a person approves it. Nothing is sent without that approval.

The distinction that governs the whole design: it reports what a document says. It never reports what is true.

## The Five Workflows

Everything the system does is one of these five. Nothing runs outside them.

| Workflow, as named in n8n | What it owns | What starts it |
|---|---|---|
| **Stage 5 - COI Intake Workflow** | Everything that happens to an arriving certificate: storing the original, reading it, checking it, filing the result | `Gmail Trigger - COI Intake`, `Form Trigger - Certificate Upload`, or `Manual Trigger - Run Stage 5 Smoke` |
| **Stage 5 - Source Document Route** | Handing the original PDF back when someone clicks the link on a dashboard row | `Webhook - Source PDF` |
| **Stage 6 - Daily Watch Chase** | Finding paperwork that is missing or running out, drafting the reminder, holding it for a person, sending it, logging it, and escalating when a vendor ignores you | `Schedule Trigger - Daily Watch 08:00`, or `Manual Trigger - Run Stage 6 Watch` |
| **Stage 6 - Non PDF Reply Notice** | Vendor replies that are not certificates, so a plain text answer or a portal link becomes a manager notice instead of nothing | `Gmail Trigger - Stage 6 Replies` |
| **Stage 7 - Dashboard Demo View** | Turning the current state of the database into the register web page | `Webhook - COI Dashboard` |

**A sixth export exists and does not run.** `Stage 4 - COI Extraction and Validation Core` is the harness the checking rules were built and tested in. The rules themselves live in `scripts/lib/coi-stage-4-validator.js` and are copied into the intake workflow by a generator script, which is why the checks behave identically wherever they run. If you ever need to change a rule, you change that file and regenerate. You do not edit the workflow.

## The Parts Underneath

Distinct from the five workflows above. These are the components the workflows use.

**n8n** runs the workflows and keeps the record of what happened. Its execution history is the audit trail: every run, what it did, and when.

**Postgres** is the memory, and more of the logic than you might expect. Vendors, certificates, coverage lines, reminder history and your settings live here, but so do several functions that make real decisions. See "What Lives In Postgres Rather Than n8n" below. This is the actual asset, and the client owns it.

**The AI model** does one narrow job: read a certificate and return the facts printed on it. It is instructed to transcribe rather than interpret, and to return nothing rather than guess. It makes no decisions about whether a certificate is acceptable. It is called in exactly three places: `OpenAI Extract Stage 5 Text`, `OpenAI Extract Stage 5 PDF File`, and `OpenAI Draft Stage 6 Chase Email`.

**Gmail** is both doors. Certificates come in through it, and approved reminders go out through it.

**Disk storage** holds every original PDF under a dated folder, `/home/node/.n8n-files/certificates/YYYY/MM/DD/`, mounted from `./data/certificates`.

**The dashboard** is a web page rendered on request by a workflow. It has no accounts and stores nothing of its own.

## The Journey Of One Certificate

**Workflow: Stage 5 - COI Intake Workflow.** All of it. Six steps, in order, with the nodes that do them.

**1. It arrives.** Three ways in, and each has its own short entry path that normalizes the document and loads your settings:

- Gmail: `Gmail Trigger - COI Intake` then `Mark Gmail Intake Source`, `Normalize Gmail Intake Items`, `Load Stage 5 Gmail Context`, `Attach Context To Gmail Items`
- The upload form: `Form Trigger - Certificate Upload` then the matching four form nodes
- A manual test run: `Manual Trigger - Run Stage 5 Smoke` then `Load Stage 5 Manual Context`, `Build Manual Smoke Items`

All three converge at `Route Intake Item Type`, so behaviour is identical from that point regardless of how a document came in. An email with two PDFs becomes two independent certificates handled separately.

`Route Intake Item Type` is also the first refusal. Anything that is not a PDF goes to `Build Direct Intake Notice Payload` and becomes a manager notice rather than a certificate.

**2. It gets saved first.** `Prepare Stored PDF Metadata` works out the dated path, `Write Original PDF To Storage` writes the file, and `Reattach PDF Context After Storage` puts the record back together, because the file node drops everything else.

This ordering is deliberate. The original survives even if every later step fails, and every dashboard row can link back to the document it came from.

**3. It gets read.** `Route Password Protected PDF` runs first, because a locked file would otherwise break extraction and take the whole run with it. Locked files skip straight to `Mark Password Protected Review Result`.

Everything else goes to `Extract Text From Stored PDF`, then `Route By Extracted Text Length` decides which way to read it:

- Enough text: `Mark Text Extraction Method` then `OpenAI Extract Stage 5 Text`
- Too little, meaning a scan or a photo: `Mark Vision Extraction Method` then `OpenAI Extract Stage 5 PDF File`, which sends the PDF itself to be read visually

Either way the output is the same shape: vendor, carrier, policy number, coverage lines, limits, effective and expiration dates, certificate holder, and the model's own confidence rating of HIGH, MEDIUM, or LOW.

**4. It gets checked.** `Normalize Validate Stage 5 Result`. This is the part that is not AI. A fixed set of rules, the same every time with no judgment involved, compares the extracted facts against your requirements. Are the dates in a sensible order? Is the expiration plausible? Is there a general liability line? Does the certificate holder match one of your accepted legal names? Do the limits meet your minimum for that trade? Is this vendor suspiciously similar to one already on file? Each problem found becomes a flag with a severity.

All three branches converge here: the password-protected branch, the text branch, and the vision branch.

**5. It gets filed.** `Store Stage 5 Intake Result`. The flags decide what happens, covered below.

**6. The register updates.** Nothing pushes. The next time anyone loads the dashboard, Stage 7 reads the current state, and the page auto-refreshes every five seconds.

## Why The Reading And The Checking Are Separate

The most important design decision in the system, and it is visible in the node list.

`OpenAI Extract Stage 5 Text` reads. `Normalize Validate Stage 5 Result` decides. The model is never asked whether a certificate is good enough, only what the document says. Everything consequential is decided by fixed logic that behaves identically every single time.

This matters because it confines the parts that could produce a wrong answer to transcription, and transcription is checkable against the PDF sitting one click away on the same row.

## What The Checks Look For

All evaluated in `Normalize Validate Stage 5 Result`, from the rules in `scripts/lib/coi-stage-4-validator.js`. Flags come in three severities, and the severity determines the outcome.

**Hard. The certificate goes to review and is never filed as current.**

| Flag | Plain meaning |
|---|---|
| `DATE_INVERTED` | The expiration date falls before the effective date |
| `DATE_IMPLAUSIBLE` | A date is far outside any believable range |
| `LOW_CONFIDENCE` | The model itself said it was unsure |
| `NOT_A_COI` | This document is not a certificate of insurance |
| `OLDER_THAN_ON_FILE` | This is older than the certificate already on file for this vendor |
| `POSSIBLE_DUPLICATE_VENDOR` | The vendor name is close to an existing one but not an exact match |
| `PDF_PASSWORD_PROTECTED` | The file is locked and cannot be read. Set by `Mark Password Protected Review Result` before extraction is attempted |
| `MODEL_REFUSED` | The model declined to process the document |
| `MODEL_OUTPUT_INVALID` | The model returned something malformed |

**Soft. The certificate is filed, with a visible amber note.**

| Flag | Plain meaning |
|---|---|
| `HOLDER_MISMATCH` | The certificate holder is not one of your accepted legal names |
| `LIMIT_BELOW_MINIMUM` | A limit is under your requirement for that trade |
| `NO_GL_LINE` | No general liability coverage line is present |
| `NO_WC_LINE` | No workers' compensation line is present, suppressed for vendors marked exempt |
| `COVERAGE_GAP` | A renewal starts later than the previous policy ended, leaving a gap. This one compares the new certificate against the one it replaces rather than reading it alone |

**Note. Recorded as neutral information only.**

| Flag | Plain meaning |
|---|---|
| `NO_CANCELLATION_NOTICE_WORDING` | A high-risk trade's certificate does not mention notice of cancellation |

The rule underneath all of this: a hard flag can never quietly become a filed, current certificate. If something is wrong, a person sees it.

## How A Certificate Gets Filed

**Node: `Store Stage 5 Intake Result`.** Four outcomes:

- **Filed as current.** Clean, or carrying only soft and note flags. It becomes the vendor's active paperwork.
- **Sent to review.** Any hard flag. It is stored and visible, but it does not count as current paperwork.
- **Superseded.** A newer certificate arrived for a vendor who already had one. The old record is kept as history rather than deleted, so there is an audit trail.
- **No record at all.** The document was not a certificate. The manager gets a notice and no vendor record is invented.

Uploading an older certificate over a newer one does not regress the register. The same document arriving twice does not create two rows.

Two statuses can only ever be set by a human: **cancelled** and **non-renewed**. No workflow sets these. The system cannot detect either from a certificate, because a certificate says nothing about what happened after it was issued, so a manager sets them manually with a note and their name attached. The vendor then becomes actionable without the system pretending it discovered anything.

## The Source Document Link

**Workflow: Stage 5 - Source Document Route.** Six nodes, and the smallest thing here that matters most.

Every dashboard row carries a link to the certificate it came from. Clicking it hits `Webhook - Source PDF`, which passes the certificate id to `Load Certificate Source Path`. `Route Safe Stored PDF` checks the stored path is inside the allowed area before anything is read, then `Read Stored Source PDF` and `Respond With Stored PDF` hand the original back. If the file is missing or the path fails the check, `Respond Source PDF Not Found` answers instead of erroring.

Locally the route is reached as `/webhook/stage-5-source-document-webhook/coi-source/<certificate_id>`.

This is what makes the extraction checkable rather than final. Nobody has to take the system's word for a date.

## What Happens When Nothing Arrives

**Workflow: Stage 6 - Daily Watch Chase.** The other half of the system. Once a day it goes looking for paperwork that needs chasing.

`Schedule Trigger - Daily Watch 08:00` starts it. The first thing that runs is `Escalate Stage 6 Overdue Outreach`, a pre-pass that deals with vendors who have already ignored enough requests, before any new chasing is considered.

Then `Load Stage 6 Actionable Vendors` does the sorting. For each vendor it takes the earliest-expiring active coverage and puts them in a bucket, in this order:

1. **Never received.** This vendor has no certificate at all
2. **Expired.** Past the printed date
3. **14 days.** Expiring within two weeks
4. **30 days**
5. **60 days**
6. **Re-attestation.** Nothing wrong, but it has been 90 days since the vendor last confirmed their details
7. **None.** Nothing to do

Vendors with no certificate come first deliberately. They are the ones most easily forgotten, precisely because they have no date attached to remind anyone.

The cadence is a setting rather than a hardcoded rule. Currently reminders at 60, 30, 14 and 0 days out, and re-attestation every 90 days. Note that the industry convention quoted most often is 60, 30 and 7, so this schedule is deliberately different and worth explaining if anyone asks.

Chasing is skipped when a vendor is paused, when a reminder is already awaiting approval, or when a recent reminder has not yet come due for follow-up. The system does not pile on.

## The Chase, And The Approval Gate

**Workflow: Stage 6 - Daily Watch Chase**, continuing from above. This is the longest path in the system, so here it is node by node.

`OpenAI Draft Stage 6 Chase Email` writes a short email, under 120 words, naming the vendor, the policy number and the expiry date, requesting updated paperwork, and making no claims about coverage. Where a producer or agent is on file, the request is addressed to them.

`Prepare Stage 6 Draft Payload` then builds the version that will actually be sent. It appends the vendor-facing link as an anchor reading "certificate upload link", after the word-count and forbidden-word checks have run, so the model cannot invent a destination and the boilerplate does not count against the 120 words.

`Record Pending Outreach` writes the pending row before anything is sent, so a reminder can never go out without a record of it existing.

`Prepare Approval Email Payload` and `Route Email Approval Configured` then check that an approver address is actually set. If it is not, the run goes to `Store Stage 6 Config Notice` instead of emailing anyone. This is a deliberate refusal rather than a fallback.

`Gmail Approval - Send and Wait` sends the approval request to the manager and then holds the execution open. The manager sees the vendor, the reason, the intended recipient and the exact draft, with two buttons. The approval email shows the raw upload URL on its own line, because the approver is reviewing what is about to be sent and needs to see the destination. Only the vendor-facing email hides it behind anchor text.

Then `Recover Approval Result Context` and `Route Approved Stage 6 Email` decide what happens next:

- **Approved.** `Gmail Send Approved Stage 6 Chase` sends from the office's own mailbox, then `Build Sent Outreach Log Payload` and `Mark Outreach Sent` record the send time, recipient, message body and follow-up date.
- **Declined.** `Build Declined Outreach Log Payload` and `Mark Outreach Declined` log it and nothing is sent.
- **No response in 24 hours.** The request expires rather than sending. This is the default, not a setting someone has to remember.

If a follow-up comes due and no newer certificate has arrived, a second request goes out. After two ignored requests, the `Escalate Stage 6 Overdue Outreach` pre-pass on a later day escalates to the manager and pauses automated chasing for that vendor. It will not email a vendor indefinitely.

**One setting to know about.** `stage_6_outbound_test_mode` defaults to true, which redirects approved sends to a test address rather than the real producer or vendor. That is correct during setup and must be switched off deliberately before any real use.

## Replies That Are Not Certificates

**Workflow: Stage 6 - Non PDF Reply Notice.** Three nodes, and easy to forget it exists.

`Gmail Trigger - Stage 6 Replies` watches for vendor replies. `Normalize Stage 6 Reply Notice` and `Store Stage 6 Reply Notice` turn anything that is not a certificate, a plain text answer or a link to an insurance portal, into a manager notice rather than letting it disappear.

A reply that does carry a PDF is picked up by the intake workflow instead, through its own Gmail trigger, and goes through the normal journey.

**Worth knowing:** vendor replies are never linked back to the outreach row that prompted them. Matching runs on the vendor name extracted from the certificate. Chasing stops because a newer filed certificate makes the vendor non-actionable, not because the system detected a reply. The outcome is right. The mechanism is not reply detection.

## The Dashboard

**Workflow: Stage 7 - Dashboard Demo View.** Five nodes and no storage of its own.

`Webhook - COI Dashboard` receives the request. `Load Stage 7 Dashboard Rows` pulls the current state from Postgres. `Build Stage 7 Dashboard HTML` renders the page. `Respond With Stage 7 Dashboard` returns it. That is the whole workflow. There is a second webhook node for a stable URL, feeding the same three nodes.

One row per vendor: name, trade, carrier, policy number, general liability limit, expiration date, status, chase, and a link to the source document.

The chase column answers "has anyone asked for this yet, and when": `Not yet chased`, `Chased 3 days ago (2 requests), follow-up Aug 12`, `follow-up overdue`, or `Chasing paused` once a vendor has ignored enough requests to be handed back to a person.

Status is always phrased as a date fact:

- Current until *(date)*
- Expires in *(n)* days
- Expired *(n)* days ago
- No certificate on file
- Needs review

Soft flags appear as small amber notes under the vendor name. Header counts update as documents are processed. Rows with no certificate sort near the top.

The words *compliant*, *verified*, *covered* and *approved* are forbidden anywhere in this page. `Build Stage 7 Dashboard HTML` throws rather than render one, and `scripts/verify-stage-7-dashboard.ps1` fails the build if any appear. This is enforced twice rather than merely intended.

## What Lives In Postgres Rather Than n8n

Worth knowing, because reading the workflows alone will not show you where several decisions are made. The n8n nodes call these.

| Function | What it decides | Called by |
|---|---|---|
| `stage_6_actionable_vendors` | Which vendors need chasing, which bucket each falls into, and all the suppression rules | `Load Stage 6 Actionable Vendors` |
| `stage_6_vendor_issue_key` | What counts as "the same problem I already asked about". Deliberately excludes the bucket, so a vendor's expiry is one continuous issue across boundaries | Used inside the function above |
| `stage_6_escalate_overdue` | The two-strike rule, `HAVING count(*) >= 2` | `Escalate Stage 6 Overdue Outreach` |
| `stage_7_dashboard_rows` | Every value the dashboard renders, including the chase summary aggregated from `outreach_log` | `Load Stage 7 Dashboard Rows` |

If chasing behaves in a way the workflow diagram does not explain, the answer is almost always in `db/postgres/004-stage-6-watch-chase.sql`.

## Where Everything Lives

- **Vendor register, certificates, coverage lines, reminder history and settings.** The Postgres database
- **Original PDFs.** A dated folder on disk, one folder per day, linked from every row through Stage 5 - Source Document Route
- **Your requirements.** Minimum limits per trade, accepted certificate holder legal names, reminder cadence, approver address and which AI model to use are all settings in the database, not values buried in the workflows
- **What ran and when.** n8n's execution history
- **API keys and mailbox access.** Stored inside n8n only, never in the project files

## What It Deliberately Refuses To Do

These are not gaps. They are the design.

It does not say a vendor is insured, compliant, verified or approved. It does not decide whether a vendor may work on a property. It does not guess at an unclear document, it asks a person. It does not send a vendor email without human approval. It does not interpret the additional-insured or subrogation checkboxes, recording only whether a mark is present, which is why those fields are named "asserted". It does not turn cancellation-notice wording into a promise that notice will be given.

## What It Genuinely Cannot Do

Worth being blunt about, because these are the limits of certificates themselves, not of the build:

- It cannot confirm a policy is active with the carrier. A certificate is a snapshot of the day it was issued.
- It cannot detect mid-term cancellation. Nothing in a certificate reveals that.
- It cannot verify additional-insured status or interpret endorsements. That requires the policy, not the certificate.
- It cannot spot a forged certificate.
- It cannot know about a vendor nobody entered into the register.
- It does not write back to property management software.
- It does not process certificate images sent as JPG or PNG. Intake filters to PDFs, so those become `NON_PDF_ATTACHMENT` notices.

Anything in this list belongs with the agent, broker, carrier or legal advisor.

## Resetting

`reset-demo.ps1` returns everything to the opening state: 18 vendors, no certificates, no coverage rows, no notices, no reminder history, and no vendors left paused from earlier testing. Settings, credentials and email configuration survive. It takes about a second and is safe to run repeatedly.

## When Something Looks Wrong

Each symptom, and which workflow to open first.

- **A row shows "Needs review" unexpectedly.** Open the source PDF from the row. The document usually explains it: an inverted date, a holder name that does not match, an unusually poor scan. If you want the detail, the run is in Stage 5 - COI Intake Workflow executions.
- **A certificate arrived but no row changed.** Check it was a PDF, then check Stage 5 - COI Intake Workflow executions for that time. A clean run that creates no certificate is the correct result for a non-certificate document.
- **A Gmail certificate was missed entirely.** The intake trigger filters on unread with an attachment. A reply opened in Gmail before the trigger polls can be skipped.
- **No reminder email appeared.** Confirm Stage 6 - Daily Watch Chase is published and active, and confirm the approver address is set. An inactive workflow has been the cause before, and an unset approver sends the run to `Store Stage 6 Config Notice` instead.
- **A vendor is never chased.** Check `chase_paused` for that vendor. Earlier escalation testing has left every vendor but one paused before now, and it is invisible outside the dashboard chase column.
- **A source PDF link returns not found.** Stage 5 - Source Document Route answered with `Respond Source PDF Not Found`. The stored path is either missing or outside the allowed area.
- **The dashboard will not load after a restart.** n8n registers its web routes a little after the editor comes up. Wait, then retry.
- **The database browser shows unfamiliar internal tables.** Run `apply-pgweb-viewer.ps1` and hard-refresh.

## Technical Pointers

For when you need to go a level deeper:

- **The workflows themselves.** `n8n-workflows/`, one file per workflow, named to match the table at the top of this document. These are generated by the `scripts/generate-stage-*` scripts rather than hand-edited
- **The checking rules, in full.** `scripts/lib/coi-stage-4-validator.js`. This is the single source, embedded into the workflow exports by the generator scripts
- **The chasing logic.** `db/postgres/004-stage-6-watch-chase.sql`
- **The dashboard query.** `db/postgres/005-stage-7-dashboard.sql`
- **What the AI is asked to return.** `docs/schemas/coi-extraction.schema.json`
- **Database structure and settings.** `db/postgres/001-schema.sql` and the numbered files after it
- **Stage-by-stage build detail.** The `docs/stage-*-runbook.md` files
- **Current status, decisions and deviations.** `progress-notes.md`
- **Production gaps still outstanding.** `docs/stage-9-*.md`
