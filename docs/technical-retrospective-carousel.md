# Build retrospective: vendor paperwork

Created: 2026-10-19. Status: rendered draft for review. Not published or queued.

Audience: property management decision-makers and buyers, plus hiring managers. Lead with the recurring paperwork problem, explain decisions in plain language, and demonstrate problem-solving through specific failures and checks. No technology-stack list, schema excerpts or internal configuration in public copy. The owner explicitly changed the earlier engineering-heavy direction on 2026-10-20.

Document title: **I built a follow-up process for vendor paperwork.**

Editable source: `docs/carousels/technical-retrospective-vendor-coi.html`.
Copy + build source: `scripts/build-technical-retrospective.cjs`.
Review PDF: `docs/carousels/out/technical-retrospective-vendor-coi.pdf`.
Contact sheet: `docs/carousels/out/technical-retrospective-preview.png`.

Prepare fonts once: bundled Python, `scripts/prepare-carousel-fonts.py` (fonttools; downloads official Fontshare faces to ignored tmp/ and repairs their internal family names for reliable PDF embedding).
Build: `node scripts/build-technical-retrospective.cjs`.
Render: `.\scripts\generate-linkedin-carousel.ps1 -Name technical-retrospective-vendor-coi`.
Verify + preview: bundled Python, `scripts/verify-technical-retrospective.py`.

## LinkedIn caption

An insurance certificate arrives in the inbox. Someone still has to record the dates, notice when an update is due and remember who needs another request.

I built a process to connect those steps for vendor paperwork.

It reads incoming certificates, keeps the original document linked to the record, surfaces missing or expiring paperwork, and drafts requests for updates. Each vendor-facing chase email waits for a person's approval.

I started with three questions: What is missing? What expires next? Who needs a follow-up?

Those questions shaped the build more than the choice of software. AI helps read the document and draft the wording. Separate checks handle dates and matching names. A person controls whether each chase email sends.

The failures taught me where the process needed more attention.

One batch created a list of pending reminders, but only one approval request reached the approver. I separated each reminder's approval process and checked that they worked independently.

Another rule treated a change in urgency as a new problem. That could restart the chase even though we had already asked for the same update. I kept the reminder history attached to the outstanding document as the deadline approached.

I also added a review route for unreadable PDFs, then checked it through the upload form. The original file stays available so the problem can be investigated.

I checked the stored records, the individual approval requests and the retrieved documents. I wanted to see what happened after each step, rather than stop at a successful run.

Next I would focus on making failed steps easier to see, recognizing repeated emails and attachments, and recovering cleanly after interruptions.

The problem I set out to solve was keeping paperwork moving: knowing what is on file, what needs attention and what should happen next.

## Slide copy and diagrams

The diagram text below is public content. Evidence references are internal notes and do not appear in the PDF. Diagrams explain implementation; none imitates a screenshot or claims to be an observed model response.

### Slide 1

**Title:** I built a follow-up / process for vendor / paperwork.

**Body:** Collecting insurance certificates is one job. Keeping track of missing documents, expiration dates and follow-ups is another. I built a process to connect them.

**Diagram / labels:**



**Footer:** Vendor paperwork · From arrival to follow-up

**Evidence:** build-plan.md scope; docs/how-the-system-works.md; Stage 5 intake, Stage 6 watch/chase and Stage 7 dashboard exports.

### Slide 2

**Title:** I started with the / questions someone / has to keep answering

**Body:** I wanted one view of the paperwork and a repeatable way to request updates, without relying on someone to remember every date.

**Diagram / labels:**

01 What is missing?
Which vendors have no certificate on file.

02 What expires next?
Which recorded dates need attention.

03 Who needs a follow-up?
Which outstanding requests are due again.

**Footer:** The problem · Keeping track after the document arrives

**Evidence:** docs/how-the-system-works.md problem statement; stage_6_actionable_vendors in 004-stage-6-watch-chase.sql; Stage 7 dashboard read model.

### Slide 3

**Title:** I connected the document / to the next action

**Body:** I connected intake, date tracking and follow-up. The register keeps the document history; each vendor-facing chase email waits for a person to approve it.

**Diagram / labels:**

When a certificate arrives
Receive the / document
→
Read + check / the details
→
Update the / record


One register · Documents, dates and request history
When an update is due
Find missing or / expiring paperwork
→
Draft a / request
→
Person reviews / before sending

**Footer:** The process · Receive, record, follow up

**Evidence:** Stage 5-7 current runtime workflows; certificate/outreach storage functions; per-vendor approval workflow and daily watch caller.

### Slide 4

**Title:** AI helps with reading. / A person decides to send.

**Body:** I used AI where reading and writing help. I kept the checks separate, and gave the person reviewing each chase email control over whether it sends.

**Diagram / labels:**

AI helps with
Reading printed details
Drafting request wording

Checks + review
Checking dates and names
Getting a person's approval


When the vendor name does not match
Keep it for review instead of guessing.

**Footer:** A design choice · Assistance with a clear approval step

**Evidence:** Extraction/drafting prompts; coi-stage-4-validator.js; 003-stage-5-intake.sql exact-match linkage and VENDOR_NOT_FOUND review; Stage 6 individual approval/send.

### Slide 5

**Title:** I kept the original / one click away

**Body:** I kept the original certificate linked to its record. Someone checking a date or a flagged detail can return to the document it came from.

**Diagram / labels:**

See a date / or flagged detail
→
Open the / original PDF
→
Check what the / document says

Saved together: document + recorded details

**Footer:** A design choice · Make the recorded details checkable

**Evidence:** Stage 5 storage-before-extraction and source route; Stage 7 certificate source links; 2026-10-10 source retrieval byte match in progress-notes.md.

### Slide 6

**Title:** Only one request / reached the approver

**Body:** I found several pending reminders but only one approval request. I gave each reminder its own approval step, then checked that each could be reviewed separately.

**Diagram / labels:**

What went wrong
Several / reminders
→
One approval / request
→
Others marked / as declined


What I changed
Each / reminder
→
Its own approval
→
Send / or hold


Checked: two separate approvals and two sends

**Footer:** A failure I fixed · Check the interaction, not just the list

**Evidence:** progress-notes.md 2026-08-08 approval defect, failed loop attempt, independent two-vendor waits/approvals/sends; current Stage 6 each-mode child workflow.

### Slide 7

**Title:** More urgent shouldn't / mean start over

**Body:** The system treated a new urgency label as a new problem. I kept the reminder history attached to the same outstanding document instead.

**Diagram / labels:**

Before · A new urgency label reset the history
15 days / until expiry
→
14 days / until expiry
→
Could ask / again


After · Keep the same outstanding request
15 days / until expiry
→
14 days / until expiry
→
Wait until due


The seven-day follow-up window stays in place.

**Footer:** A failure I fixed · Remember that we already asked

**Evidence:** 004-stage-6-watch-chase.sql issue key excludes bucket; progress-notes.md 2026-07-31 equal-key verification and 16 SQL checks. This describes possible repeated requests, not a claimed delivered duplicate.

### Slide 8

**Title:** An unreadable document / still needs a next step

**Body:** A locked PDF could stop intake. I added a route that records the problem for review, with the original document retained for investigation.

**Diagram / labels:**

Original PDF saved
↓
Try to read the document
↓
Unreadable → Review record kept

Checked through the actual upload form.

**Footer:** A failure I fixed · Give unreadable documents a review route

**Evidence:** progress-notes.md 2026-08-07 form fix; Stage 5 storage-before-reading, encryption check, extract continueErrorOutput to password review; f18 multipart form produced NEEDS_REVIEW with no matched vendor. Review is stored; no claim of a new dashboard review queue or notification.

### Slide 9

**Title:** I checked what happened / after each step

**Body:** I checked the record, the approval request and the original file, alongside whether a run finished. Each check followed a specific step in the process.

**Diagram / labels:**

Situation I checked What the record showed
A replacement arrives Earlier record replaced
Wrong document Notice instead of filing
Locked PDF Recorded for review
Two reminders Separate approval requests
Open the original Returned file matched / the stored PDF

**Footer:** Recorded checks · Documents, requests and stored results

**Evidence:** docs/stage-8-fixture-results.md replacement/non-certificate cases; progress-notes.md 2026-08-07 protected form upload, 2026-08-08 two independent approvals, 2026-10-10 byte-matched retrieval. Results are from separate recorded checks, not a fresh combined run or general benchmark.

### Slide 10

**Title:** What I would / improve next

**Body:** I would focus next on visible failures, repeat-message handling and recovery. A useful process needs a clear next step when something interrupts it.

**Diagram / labels:**

01 Show work that gets stuck
Make failed steps visible to the person responsible.

02 Avoid repeating the same work
Recognize the same email or attachment arriving again.

03 Make recovery easier
Check what happens after an interruption or a lost file.

**Footer:** Next improvements · Visibility, repeat handling and recovery

**Evidence:** docs/stage-9-production-readiness-plan.md and implementation-backlog.md: visible dead letters, alerts, message/attachment idempotency, retry/backoff, backup/restore. Proposed improvements; source_ref checks alone do not establish full replay or crash safety.

## Evidence boundaries and design review

- Stage 8's original report predates later approval, model and intake repairs. Its all-pass status is historical; this draft does not claim the full suite was rerun after those repairs.
- The unreadable-document slide covers the implemented intake error route and recorded form-path check. Public copy focuses on implementation and specific checked behavior, without demo or synthetic-data framing, per the owner's 2026-10-20 revision request. This wording does not introduce a client deployment, accuracy score or customer-result claim.
- Structured output constrains shape; it does not guarantee factual correctness or deterministic model behavior. LOW confidence and date failures route to review, but NOT_A_COI and older documents take notice dispositions first. Unknown names reach review in storage even if the core validator returned store_on_file.
- Duplicate source_ref checks exist. Message-plus-attachment identity, safe concurrent processing and send crash recovery are not established by those checks.
- Two distinct approval waits and sends establish the repaired per-vendor interaction in that test. They do not establish concurrency, repeated-button safety or exactly-once delivery.
- Reference sources inspected read-only: renewal-retention technical retrospective HTML/PDF/content document; maintenance-triage carousel kit HTML/CSS and rendered post 5. Cream ruled paper, grain, Switzer, restrained Zodiak and meaning-based blue/gold annotations follow those references.
- This draft introduces shared technical layouts in the existing stylesheet. Annotation colors are independent of shape and selection boxes may appear inside the deck, per the current user direction. No per-deck style block or inline presentation styling is used.
- PDF, contact sheet and page renders are ignored build output. Sources, caption, evidence map and QA scripts are committed.

## Review verification

Final review completed 2026-10-20. Ten pages at 810 x 1012.5 points; embedded Switzer/Zodiak faces, no fallback families; one shared grain bitmap. All public text runs and character counts survive extraction. Text bounds and privacy checks pass, including PDF metadata, absent links and attachments. Every page was rendered at approximately 1080 x 1350 and visually reviewed along with the contact sheet; final changed pages were rechecked. No clipping, overlaps, missing marks or diagram errors remain. QA details are regenerated to ignored `docs/carousels/out/technical-retrospective-qa.json`.

This task did not rerun the live n8n fixture suite or send email. Claims use the implementation and recorded results cited above. No publishing or queue action was taken.
