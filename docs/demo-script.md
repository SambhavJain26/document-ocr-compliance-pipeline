# Demo Script: Vendor COI Chasing Automation

Use this as the script for a recorded walkthrough video. The goal is to make the automation feel like a normal day inside a property management office: vendor paperwork comes in, certificate facts get read, the dashboard changes, and a human signs off before any chase email goes out.

## Recording Prep

Before recording, open these tabs:

- Dashboard: `http://localhost:5678/webhook/stage-7-dashboard-webhook/coi`
- Gmail inbox for the demo mailbox
- pgweb, optional: `http://localhost:8081/?session=coi-only`
- n8n editor, optional: `http://localhost:5678`

Run these first:

```powershell
.\scripts\start-local.ps1
.\scripts\verify-local.ps1
.\scripts\reset-demo.ps1
```

Confirm the opening dashboard shows 18 vendors and no certificate rows.

## The Recording Flow

Target length: 5 to 7 minutes.

Tone: calm, practical, and plain. This is not a software tour. It is a business workflow walkthrough.

## 1. Open On The Empty Register

**Screen:** Dashboard showing 18 vendors with no certificate on file.

**Say:**

> "Most property managers already have some version of this list. Plumbers, electricians, HVAC, landscapers, cleaners, painters. The problem is not knowing who your vendors are. The problem is keeping the insurance paperwork current after the first certificate gets filed."

Pause on the rows.

> "Right now this is the clean starting point. Eighteen vendors. No certificate on file yet. That is exactly how this starts with a new client: we load the vendor register first, then let the system fill in the paperwork facts as documents arrive."

Point to the columns.

> "The dashboard is intentionally simple. Vendor, trade, carrier, policy number, general liability limit, expiration date, status, and source document."

Point to the status column.

> "Notice the wording. It says document facts only. No certificate on file. Current until a date. Expires in a number of days. Needs review. This does not make insurance decisions. It tracks the paperwork."

## 2. Explain The Office Problem

**Screen:** Stay on dashboard.

**Say:**

> "In a normal property management office, a certificate lands in somebody's inbox. Someone opens the PDF, reads the policy dates, checks the vendor name, looks for the carrier and policy number, then types those facts somewhere. Maybe into a spreadsheet. Maybe into the vendor record in their property management software."

Short pause.

> "That works until the office gets busy. Then a renewal gets missed, an agent email sits unread, or the certificate is filed but the date never gets updated."

Point to dashboard header counts.

> "This automation is built for that gap. It does not replace the manager. It does the typing, the date tracking, and the chase draft. The human still reviews before anything goes out."

## 3. Show Certificate Intake

**Screen:** n8n manual fixture run, form upload, or prepared execution depending on recording setup.

Recommended recorded path:

```powershell
.\scripts\verify-stage-8-fixtures.ps1
```

For a shorter recording, use prepared representative rows from a completed fixture run, then explain what was processed.

**Say:**

> "Now I am going to run a set of synthetic sample documents through the intake path. In a real office, these would arrive by email or upload. For the demo, I am using repeatable test documents so the result is predictable every time."

If showing the upload/form path:

> "The vendor or office staff sends in a PDF. The system reads the certificate, extracts the date and policy facts, stores the source document, and updates the register."

If using the fixture script:

> "This run includes the cases property managers actually see: a clean current certificate, one expiring soon, one already expired, one with dates that need review, one with a low general liability limit, one with the wrong holder name, and a renewal that creates a paperwork gap."

## 4. Refresh The Dashboard

**Screen:** Dashboard after representative fixture state.

**Say:**

> "Now the dashboard has changed. This is the part that matters."

Point to a green/current row.

> "Here is a current certificate. Carrier, policy number, limit, and expiration date are filled in. The status is a date fact: current until this date."

Point to an amber/expiring row.

> "This one is coming up soon. The office does not need to remember to check a spreadsheet. It is surfaced before the date becomes a problem."

Point to a red/expired row.

> "This one has already expired. Again, the system is not deciding whether that vendor can work. It is showing that the certificate paperwork on file is past the date printed on the document."

Point to a review row.

> "This one needs review. That is deliberate. If the document has inverted dates, a password-protected PDF, a vendor name that is close but not exact, or a holder issue, the system does not guess."

## 5. Open A Source PDF

**Screen:** Click a source link from the dashboard.

**Say:**

> "Every row links back to the source document. That means the manager is not trusting a black box. The extracted facts sit next to the original certificate."

Pause on the PDF.

> "This is important because the automation is doing paperwork reading. If someone wants to check the carrier, policy number, or expiration date, the PDF is one click away."

Return to dashboard.

## 6. Show The Business Notes

**Screen:** Dashboard row with amber flag, coverage gap note, holder note, or cancellation notice wording.

**Say:**

> "The system also keeps small notes where the paperwork deserves attention. For example, a renewal might leave a fourteen-day paperwork gap. Or a document might mention cancellation notice wording. We record that as a note because it is on the document."

Short pause.

> "But we do not turn that into a legal conclusion. If a manager needs endorsement or policy-status confirmation, that still belongs with the broker, agent, or carrier."

## 7. Optional Database View

**Screen:** pgweb at `http://localhost:8081/?session=coi-only`, `coi_pgweb` views.

Keep this section under 30 seconds.

**Say:**

> "For transparency, the same facts are stored in a simple database. I would not show this to every end user, but it is useful during setup and testing."

Click `vendors`, then `certificates` or `outreach_log`.

> "Vendor list here. Certificate rows here. Outreach log here. The dashboard is the friendly view; this is the underlying record."

Return to dashboard or Gmail.

## 8. Run The Chase Email Moment

**Screen:** Terminal or n8n run for live email rehearsal.

Run:

```powershell
.\scripts\verify-stage-8-fixtures.ps1 -OnlyLiveEmail
```

**Say:**

> "Now let us look at the part that makes this safe for a small property management office. The system can draft the chase email, but it does not send it on its own."

Wait for the approval email.

> "The manager gets an email first. It shows the vendor, the reason for the request, the intended recipient, and the draft message."

## 9. Approve The Draft

**Screen:** Gmail approval email.

Open the approval email.

**Say:**

> "This is the human checkpoint. The manager reads the draft and decides whether it should go out."

Click `Approve`.

> "I am clicking Approve now. That approves the reminder email only. It is not an approval of the vendor."

Wait for send confirmation or show the outreach log.

> "Now the final chase email is sent from the configured mailbox, and the action is logged. The office has a record of who was contacted, when it happened, and why."

## 10. Show The Final Email Or Log

**Screen:** Gmail final sent message or pgweb `outreach_log`.

**Say:**

> "Here is the final email. Short, factual, and tied to the vendor record. No one had to write it from scratch, but a human still reviewed it before it left the mailbox."

If showing pgweb:

> "And here is the log row: drafted, cleared for sending, sent time, recipient, and follow-up date."

## 11. Close The Demo

**Screen:** Dashboard.

**Say:**

> "So the workflow is simple. Vendor certificate comes in. The system reads the document facts. The dashboard updates. When a renewal needs chasing, it drafts the email and waits for a human."

Short pause.

> "This is not trying to be an enterprise risk platform. It is the part of the job that usually falls into a spreadsheet, an inbox, or somebody's memory."

Close with the offer.

> "The easiest next step is simple: send me ten vendor certificates. I will run them through this and show you where the paperwork stands. You will see which rows are current by date, which are expired, which are missing, and which need review. No PMS access needed."

## Fallback Lines

Use these if something is slow during recording.

**Gmail delay**

> "Gmail can lag, so I am going to show the deterministic intake path first. The database and dashboard already prove the document flow."

**Approval link issue**

> "The approval email is a waiting step. If the link is delayed, I can show the pending outreach row and continue from a prepared approval run."

**Model/API issue**

> "The document reading step depends on the model API. If that service is delayed, the dashboard can still show the last stored state and the source documents."

**Internet issue**

> "The demo is local-first. The dashboard and stored records still work; outside services only affect new document reading or email delivery."

## What Not To Say

Avoid these lines:

- "This confirms the vendor has active insurance."
- "This confirms additional insured status."
- "This detects cancellation."
- "This decides whether a vendor can be dispatched."
- "This replaces your broker."

Use these instead:

- "This tracks certificate paperwork."
- "This reads date and document facts."
- "This keeps the source PDF one click away."
- "This flags rows that need human review."
- "This drafts reminder emails and waits for the manager."

## Research Notes

The script uses current property-management workflow context from:

- Buildium's vendor insurance tracking guidance, which describes vendor insurance expiration notices in the vendor record: https://help.buildium.com/hc/s/article/Tracking-Vendor-Insurance-1557495330433
- RealPage's vendor credentialing overview, which lists COIs, liability, workers' comp, auto, licenses, W-9s, and background checks as common credentialing items: https://www.realpage.com/vendor-credentialing/
- Atlas Global Advisors' vendor onboarding checklist, which includes business license, COI, workers' comp documents, W-9, and background checks where applicable: https://atlasglobaladvisors.com/blog/vendor-onboarding-checklist-for-property-managers/
- OxMaint's property maintenance vendor management guide, which describes centralized vendor records and alerting before credentials lapse: https://oxmaint.com/industries/property-management/vendor-management-property-maintenance-guide
- NY DFS's ACORD 25 certificate filing, which states that the certificate is informational and does not change the policy: https://www.dfs.ny.gov/apps-and-licensing/insurance-companies/certificates-approved/acord-25-2025-12-liability
- Texas Department of Insurance certificate FAQ, which explains that additional-insured and cancellation-notice wording depends on policy or endorsement language: https://www.tdi.texas.gov/certificates/faq.html
