# How The System Works

A plain-language explanation of what this system actually does, end to end. Written for understanding the behaviour, not for editing the code. Technical pointers are collected at the bottom.

## The One-Paragraph Version

Vendor insurance certificates arrive as PDFs. The system saves each one, reads the facts printed on it, checks those facts against what you require, and files the result against the right vendor. It keeps a register showing which vendors have current paperwork and which do not. Every day it looks for paperwork that is missing, expiring, or expired, writes a reminder email for each one, and holds that email until a person approves it. Nothing is sent without that approval.

The distinction that governs the whole design: it reports what a document says. It never reports what is true.

## The Five Moving Parts

**n8n** is the conductor. It watches for incoming certificates, moves each one through the steps in order, and runs the daily check. If you want to see what happened and when, n8n's execution history is the record.

**Postgres** is the memory. Vendors, certificates, coverage lines, reminder history, and your settings all live here. This is the part that matters — n8n can be rebuilt, but this is the actual asset, and the client owns it.

**The AI model** does one narrow job: read a certificate and return the facts printed on it. It is instructed to transcribe rather than interpret, and to return nothing rather than guess. It makes no decisions about whether a certificate is acceptable.

**Gmail** is both doors. Certificates come in through it, and approved reminders go out through it.

**The dashboard** is a single web page served by n8n. One row per vendor, colour-coded, auto-refreshing every five seconds. It is the only screen anyone in the office needs.

## The Journey Of One Certificate

This is the spine of the system. Six steps, in order.

**1. It arrives.** Three ways in: as a Gmail attachment, uploaded through a web form, or run manually from a test fixture. All three converge into the same processing path immediately, so behaviour is identical regardless of how a document came in. Only PDFs proceed. An email with two PDFs becomes two independent certificates, handled separately.

**2. It gets saved first.** Before anything reads it, the original PDF is written to a dated folder on disk and its location recorded. This ordering is deliberate — the original survives even if every later step fails, and every dashboard row can link back to the document it came from.

**3. It gets read.** The system first tries to pull the text layer straight out of the PDF, which is fast and exact. If a PDF turns out to be a scan or a photo with no real text in it, the system sends the PDF itself to the AI model to be read visually instead. Either way the output is the same shape: vendor, carrier, policy number, coverage lines, limits, effective and expiration dates, certificate holder, and the model's own confidence rating of HIGH, MEDIUM, or LOW.

A password-protected PDF is caught before this step and routed straight to review, because attempting to extract from it would otherwise break the run.

**4. It gets checked.** This is the part that is not AI. A fixed set of rules — the same every time, no judgment involved — compares the extracted facts against your requirements. Are the dates in a sensible order? Is the expiration plausible? Is there a general liability line? Does the certificate holder match one of your accepted legal names? Do the limits meet your minimum for that trade? Is this vendor suspiciously similar to one already on file? Each problem found becomes a flag with a severity.

**5. It gets filed.** The flags decide what happens, covered in the next section.

**6. The register updates.** The dashboard reflects the new state within five seconds.

## Why The Reading And The Checking Are Separate

Worth understanding, because it is the most important design decision in the system.

The AI reads. The rules decide. The model is never asked whether a certificate is good enough — only what the document says. Everything consequential is decided by fixed logic that behaves identically every single time.

This matters because it means the parts of the system that could produce a wrong answer are confined to transcription, and transcription is checkable against the PDF sitting one click away on the same row.

## What The Checks Look For

Flags come in three severities, and the severity determines the outcome.

**Hard — the certificate goes to review and is never filed as current.**

| Flag | Plain meaning |
|---|---|
| `DATE_INVERTED` | The expiration date falls before the effective date |
| `DATE_IMPLAUSIBLE` | A date is far outside any believable range |
| `LOW_CONFIDENCE` | The model itself said it was unsure |
| `NOT_A_COI` | This document is not a certificate of insurance |
| `OLDER_THAN_ON_FILE` | This is older than the certificate already on file for this vendor |
| `POSSIBLE_DUPLICATE_VENDOR` | The vendor name is close to an existing one but not an exact match |
| `PDF_PASSWORD_PROTECTED` | The file is locked and cannot be read |
| `MODEL_REFUSED` | The model declined to process the document |
| `MODEL_OUTPUT_INVALID` | The model returned something malformed |

**Soft — the certificate is filed, with a visible amber note.**

| Flag | Plain meaning |
|---|---|
| `HOLDER_MISMATCH` | The certificate holder is not one of your accepted legal names |
| `LIMIT_BELOW_MINIMUM` | A limit is under your requirement for that trade |
| `NO_GL_LINE` | No general liability coverage line is present |
| `NO_WC_LINE` | No workers' compensation line is present (suppressed for vendors marked exempt) |
| `COVERAGE_GAP` | A renewal starts later than the previous policy ended, leaving a gap |

**Note — recorded as neutral information only.**

| Flag | Plain meaning |
|---|---|
| `NO_CANCELLATION_NOTICE_WORDING` | A high-risk trade's certificate does not mention notice of cancellation |

The rule underneath all of this: a hard flag can never quietly become a filed, current certificate. If something is wrong, a person sees it.

## How A Certificate Gets Filed

Four outcomes:

- **Filed as current** — clean, or carrying only soft and note flags. It becomes the vendor's active paperwork.
- **Sent to review** — any hard flag. It is stored and visible, but it does not count as current paperwork.
- **Superseded** — a newer certificate arrived for a vendor who already had one. The old record is kept as history rather than deleted, so there is an audit trail.
- **No record at all** — the document was not a certificate. The manager gets a notice, and no vendor record is invented.

Uploading an older certificate over a newer one does not regress the register. The same document arriving twice does not create two rows.

Two statuses can only ever be set by a human: **cancelled** and **non-renewed**. The system cannot detect either from a certificate — a certificate says nothing about what happened after it was issued — so a manager sets them manually with a note and their name attached. The vendor then becomes actionable without the system pretending it discovered anything.

## What Happens When Nothing Arrives

The other half of the system. Once a day it goes looking for paperwork that needs chasing.

For each vendor it takes the earliest-expiring active coverage and sorts them into buckets, in this order:

1. **Never received** — this vendor has no certificate at all
2. **Expired** — past the printed date
3. **14 days** — expiring within two weeks
4. **30 days**
5. **60 days**
6. **Re-attestation** — nothing wrong, but it has been 90 days since the vendor last confirmed their details
7. **None** — nothing to do

Vendors with no certificate come first deliberately. They are the ones most easily forgotten, precisely because they have no date attached to remind anyone.

The cadence is a setting, not a hardcoded rule — currently reminders at 60, 30, 14, and 0 days out, and re-attestation every 90 days.

Chasing is skipped when a vendor is paused, when a reminder is already awaiting approval, or when a recent reminder has not yet come due for follow-up. The system does not pile on.

## The Chase, And The Approval Gate

For each vendor that needs chasing, the system drafts a short email — under 120 words, naming the vendor, the policy number, and the expiry date, requesting updated paperwork, and making no claims about coverage. Where a producer or agent is on file, the request is addressed to them.

The email closes by offering two ways to respond: reply with the PDF attached, or use a link shown as "certificate upload link" that points at the upload form. The URL itself never appears in the visible text, and it is a setting rather than something the model writes, so the model cannot invent a destination. It currently points at the local machine, which is fine while testing and must be repointed at a public address before real vendors are asked to use it.

Then it stops.

The manager receives an approval email showing the vendor, the reason, the intended recipient, and the exact draft. Two buttons: approve or decline. The request waits up to 24 hours.

- **Approved** — the email sends from the office's own mailbox, and the send time, recipient, message body, and follow-up date are logged.
- **Declined** — the decline is logged and nothing is sent.
- **No response in 24 hours** — the request expires rather than sending by default.

If a follow-up comes due and no newer certificate has arrived, a second request goes out. After two ignored requests the system escalates to the manager and pauses automated chasing for that vendor. It will not email a vendor indefinitely.

Replies that are not certificates — a plain text response, or a link to an insurance portal — are turned into manager notices rather than being silently dropped.

## The Dashboard

One row per vendor: name, trade, carrier, policy number, general liability limit, expiration date, status, chase, and a link to the source document.

The chase column answers "has anyone asked for this yet, and when": `Not yet chased`, `Chased 3 days ago (2 requests), follow-up Aug 12`, `follow-up overdue`, or `Chasing paused` once a vendor has ignored enough requests to be handed back to a person.

Status is always phrased as a date fact:

- Current until *(date)*
- Expires in *(n)* days
- Expired *(n)* days ago
- No certificate on file
- Needs review

Soft flags appear as small amber notes under the vendor name. Header counts update as documents are processed. Rows with no certificate sort near the top.

The words *compliant*, *verified*, *covered*, and *approved* are forbidden anywhere in this page, and a verification script fails the build if any of them appear. This is enforced rather than merely intended.

## Where Everything Lives

- **Vendor register, certificates, coverage lines, reminder history, and settings** — the Postgres database
- **Original PDFs** — a dated folder on disk, one folder per day, linked from every row
- **Your requirements** — minimum limits per trade, accepted certificate holder legal names, reminder cadence, approver address, and which AI model to use are all settings in the database, not values buried in the workflows
- **What ran and when** — n8n's execution history
- **API keys and mailbox access** — stored inside n8n only, never in the project files

## What It Deliberately Refuses To Do

These are not gaps. They are the design.

It does not say a vendor is insured, compliant, verified, or approved. It does not decide whether a vendor may work on a property. It does not guess at an unclear document — it asks a person. It does not send a vendor email without human approval. It does not interpret the additional-insured or subrogation checkboxes; it records only whether a mark is present, which is why those fields are named "asserted". It does not turn cancellation-notice wording into a promise that notice will be given.

## What It Genuinely Cannot Do

Worth being blunt about, because these are the limits of certificates themselves, not of the build:

- It cannot confirm a policy is active with the carrier. A certificate is a snapshot of the day it was issued.
- It cannot detect mid-term cancellation. Nothing in a certificate reveals that.
- It cannot verify additional-insured status or interpret endorsements. That requires the policy, not the certificate.
- It cannot spot a forged certificate.
- It cannot know about a vendor nobody entered into the register.
- It does not write back to property management software.

Anything in this list belongs with the agent, broker, carrier, or legal advisor.

## Resetting

`reset-demo.ps1` returns everything to the opening state: 18 vendors, no certificates, no coverage rows, no notices, no reminder history. Settings, credentials, and email configuration survive. It takes about a second and is safe to run repeatedly.

## When Something Looks Wrong

- **A row shows "Needs review" unexpectedly** — open the source PDF from the row. The document usually explains it: an inverted date, a holder name that does not match, an unusually poor scan.
- **A certificate arrived but no row changed** — check whether it was a PDF, and check n8n's execution history for that time.
- **No reminder email appeared** — confirm the daily watch workflow is published and active in n8n, and confirm the approver address is set. An inactive workflow has been the cause before.
- **The dashboard will not load after a restart** — n8n registers its web routes a little after the editor comes up. Wait, then retry.
- **The database browser shows unfamiliar internal tables** — run `apply-pgweb-viewer.ps1` and hard-refresh.

## Technical Pointers

For when you need to go a level deeper:

- Stage-by-stage build detail: the `docs/stage-*-runbook.md` files
- The checking rules, in full: `scripts/lib/coi-stage-4-validator.js` — this is the single source, and it is embedded into the workflow exports by the generator scripts rather than edited inside them
- What the AI is asked to return: `docs/schemas/coi-extraction.schema.json`
- Database structure and settings: `db/postgres/001-schema.sql` and the numbered files after it
- Current status, decisions, and deviations: `progress-notes.md`
- Production gaps still outstanding: `docs/stage-9-*.md`
