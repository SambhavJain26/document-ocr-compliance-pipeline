# Demo Script: Vendor COI Chasing Automation

Script for a recorded screen walkthrough aimed at US residential property managers.

Target length: 6 minutes. A 4-minute cut is marked at each scene.

The arc is deliberate: show the problem, show what it costs, show the system doing the boring part, then show the human still holding the pen. It is a business workflow walkthrough, not a software tour.

**Tone:** calm, plain, unhurried. You are describing office work, not selling software.

## Before You Hit Record

The board must already have data on it before you record. All of this is done through the same screens you use in the demo — no terminal at any point.

**1. Start the stack.** In Docker Desktop, start the `vendor-coi-chasing` containers. Wait until n8n, postgres, and pgweb all show as running.

**2. Check the workflows.** Open n8n at `http://localhost:5678` → Workflows. All five must show **Active**:

- Stage 5 - COI Intake Workflow
- Stage 5 - Source Document Route
- Stage 6 - Daily Watch Chase
- Stage 6 - Non PDF Reply Notice
- Stage 7 - Dashboard Demo View

An inactive Stage 6 watch is the single most likely reason no approval email shows up in Scene 6. If anything is inactive, toggle it on and restart n8n from Docker Desktop.

**3. Stage the board.** Open the upload form at `http://localhost:5678/form/coi-intake` and upload these seven PDFs from `fixtures/pdfs/`, one submission at a time. Each belongs to a different vendor, so none of them overwrite each other:

| File | Lands as |
|---|---|
| `f01-clean-current.pdf` | Apex Plumbing Services LLC — green, current |
| `f03-expired-34-days.pdf` | Circuit Square Electric LLC — red, expired |
| `f05-inverted-dates.pdf` | Summit Shield Roofing Inc. — needs review |
| `f06-wrong-holder.pdf` | Greenline Groundskeeping LLC — filed, holder note |
| `f07-low-limits.pdf` | Clearway Pest Control LLC — filed, low-limit note |
| `f16-owner-llc-holder.pdf` | Evergreen Appliance Repair LLC — green, accepted owner LLC |
| `f20-cancellation-notice-wording.pdf` | Cedar Path Janitorial Services LLC — green, neutral note |

Do not upload `f13-renewal-coverage-gap.pdf` or `f12-renewal-supersede.pdf`. They are renewals for vendors already in that list — `f13` supersedes the expired Circuit Square row, `f12` supersedes Blue Ridge — and you lose states the story depends on.

Hold back `fixtures/pdfs/f02-expiring-20-days.pdf`. That is the one you upload live in Scene 3. Its vendor, Blue Ridge HVAC Co., is untouched by everything above, so it lands as a clean new amber row on camera.

**4. Confirm the board.** Open the dashboard and check those seven rows look right before you record anything.

**On resetting:** clearing the register back to 18 blank rows is the one thing that cannot be done from these screens — it needs a script from a terminal. You do not need it. Re-uploading a fixture through the form simply supersedes the earlier copy, so staging works from whatever state the board is currently in.

Tabs to have open, in this order:

1. Dashboard: `http://localhost:5678/webhook/coi`
2. The Stage 5 upload form: `http://localhost:5678/form/coi-intake`
3. Gmail for the demo mailbox
4. File Explorer at `fixtures/pdfs/`
5. Optional, only if you plan to use Scene 7: pgweb at `http://localhost:8081/?session=coi-only`

Close everything else. Silence notifications.

---

## Scene 1 — The Register (0:00–0:45)

**Screen:** Dashboard, scrolled to the top.

> "Most property managers already have this list. Plumbers, electricians, HVAC, landscapers, cleaners, painters. Knowing who your vendors are was never the hard part."

Let the rows sit on screen for a beat.

> "The hard part is what happens after the first certificate gets filed. This is a live register of vendor insurance paperwork. Vendor, trade, carrier, policy number, general liability limit, expiration date, status, and a link to the document itself."

Point at the status column.

> "Read the status wording carefully, because it is the whole design. Current until a date. Expires in a number of days. Expired a number of days ago. No certificate on file. Needs review. Every one of those is a fact printed on a document. None of them is a judgment about insurance."

*4-minute cut: keep this scene whole. It sets up everything.*

---

## Scene 2 — What It Costs Today (0:45–1:30)

**Screen:** Stay on the dashboard. Scroll slowly.

> "Here is how this works in most offices right now. A certificate lands in somebody's inbox. Someone opens the PDF, finds the policy dates, checks the vendor name, copies the carrier and policy number, and types it into a spreadsheet or a vendor record."

Short pause.

> "That holds up fine until March, when a building floods and everyone is busy. Then a renewal gets missed. An agent's email sits unread for three weeks. A certificate gets filed but the date never gets updated anywhere."

Point at the header counts.

> "Nobody notices any of it until someone asks a simple question — which vendors have current paperwork on file today — and answering it takes an afternoon of opening PDFs."

> "That afternoon is what this is built to remove."

*4-minute cut: trim to the first and last lines.*

---

## Scene 3 — A Certificate Arrives (1:30–2:45)

**Screen:** Switch to the upload form tab. Have File Explorer ready.

> "So let us put a certificate through it. In a real office this arrives as an email attachment from the vendor or their agent. I am going to upload it directly, because it is the same path and it is easier to watch."

Drag the held-back PDF onto the form. Submit.

> "That is a normal certificate PDF. Nobody has typed anything."

While it processes:

> "Behind that, it is reading the document, pulling out the vendor, the carrier, the policy number, the limits, and the dates, and filing the original PDF so it can be opened again later."

Switch to the dashboard tab. It refreshes every five seconds.

> "And there it is."

Point at the row that just changed.

> "Carrier, policy number, general liability limit, expiration date. The status now names the exact day it runs out, and counts down to it. That row went from a blank line to a tracked date without anyone opening the file."

**Do not quote a specific day count anywhere in the narration.** The fixture dates are fixed, so the countdown shifts by one every day that passes since the fixtures were generated. Describe the behaviour and let the screen show the number.

*4-minute cut: keep the upload and the result. Drop the middle explanation.*

---

## Scene 4 — The Four States That Matter (2:45–3:45)

**Screen:** Dashboard. Move down the rows deliberately.

> "Now look at the rest of the board, because this is really four situations."

Point at a current row.

> "Current, with a date attached. Nothing to do."

Point at the expiring row.

> "Expiring soon. This is the one that used to depend on somebody remembering. It surfaces before it becomes a phone call."

Point at an expired row.

> "Already past the date printed on the document. Notice what the system is not doing — it is not telling you this vendor cannot work. It is telling you the paperwork on file has run out."

Point at a review row.

> "And this one needs a human. The dates were inverted on the document. It could have guessed. It does not guess. Wrong holder name, a password-protected file, a vendor name that is close but not exact — all of it goes to review instead of quietly becoming a number in a column."

Point at the amber note under a vendor name.

> "Smaller things become notes rather than alarms. This one came in under the general liability limit we ask for on that trade. This one lists a holder name that is not one of ours. Both are filed, both are visible, neither is treated as a crisis."

*4-minute cut: keep current, expired, and review. Drop the notes line.*

---

## Scene 5 — The Document Is One Click Away (3:45–4:15)

**Screen:** Click a source link. Let the PDF open.

> "Every row links to the certificate it came from."

Pause on the open PDF.

> "This matters more than it looks. The system read this document and put facts in a table. If anyone wants to check the carrier, the policy number, or the expiration date against the original, it is one click, not a search through an inbox. Nobody has to take the software's word for anything."

Close the tab. Return to the dashboard.

*4-minute cut: keep. It is thirty seconds and it answers the trust objection before it gets asked.*

---

## Scene 6 — The Human Checkpoint (4:15–5:30)

**Screen:** Gmail.

**Set this up a minute before you record the scene.** In n8n, open **Stage 6 - Daily Watch Chase** and click **Execute workflow**. The run pauses at the Gmail approval step and one approval email lands in the demo mailbox. Do this off camera so the email is already waiting when the scene starts — or show the click on camera if you would rather the trigger be visible.

> "Last piece, and it is the one that decides whether something like this belongs in a small office."

> "When paperwork is missing or expiring, the system writes the chase email. It does not send it. Normally this runs on its own first thing in the morning."

Open the approval email.

> "The manager gets this first. The vendor, the reason, who it would go to, and the exact message that would be sent. Short, factual, no claims about coverage."

Click **Approve**.

> "I am approving the email. To be precise about what that means — I am approving that a reminder gets sent. I am not approving the vendor for anything."

Show the sent message or the outreach log.

> "Now it sends, from the office's own mailbox, and it is logged. Who was contacted, when, about which certificate, and when to follow up if nothing comes back. If a vendor ignores two requests, it stops chasing and tells the manager instead of emailing them forever."

*4-minute cut: this scene survives intact. If the email is slow, use the Gmail fallback line below and show a pre-approved run.*

---

## Scene 7 — Optional: The Record Underneath (skip unless asked)

**Screen:** pgweb, `coi_pgweb` views.

Thirty seconds, hard stop. Only include this for a technical viewer.

> "For transparency — the same facts sit in an ordinary database that the client owns. Vendors, certificates, outreach log. The dashboard is the readable view of this."

*4-minute cut: cut entirely.*

---

## Scene 8 — Close (5:30–6:00)

**Screen:** Dashboard.

> "So the loop is: the certificate arrives, the document gets read, the register updates, anything unclear waits for a person, and when a renewal needs chasing the email gets drafted and held for approval."

Short pause.

> "This is not an enterprise risk platform and it is not trying to be. It is the specific part of the job that currently lives in a spreadsheet, an inbox, and somebody's memory."

Close on the offer.

> "Easiest way to find out if it is useful: send me ten vendor certificates. I will run them and show you where your paperwork actually stands — what is current, what has expired, what is missing, and what needs a look. No access to your property management system, no setup on your side."

---

## If They Ask

Short answers to what comes back most often after this video.

**"Does this tell me if a vendor is actually insured?"**
No, and nothing that reads a certificate can. A certificate is a snapshot of what was on file the day it was issued. This tracks the paperwork and the dates. Policy status belongs with the agent or carrier.

**"What if it reads the document wrong?"**
Then it flags the row for review rather than filing a number. That is why the source PDF is on every row — the extraction is checkable, not final. Low-confidence documents are routed to a person by design.

**"We already have this in our property management software."**
Good — most of them have a field for it. The field is not the problem. Keeping the field current is the problem, and that still means someone opening PDFs and typing dates. This is the part before the field.

**"Will it email my vendors without me knowing?"**
No. Nothing goes out without a human clicking approve on the specific message. That is the gate demonstrated in Scene 6.

**"How long to set up?"**
Load the vendor list and confirm the legal names that should appear as certificate holder, connect the mailbox, then batch through the certificates you already have. The first useful output is the register.

---

## Fallback Lines

If something stalls mid-recording, say one of these and keep moving. Do not apologize or troubleshoot on camera.

**Gmail is slow**

> "Gmail delivery can lag by a minute. The intake and the register are already updated, so let me show that first and come back to the email."

**Approval link does not resume**

> "The approval is a waiting step held open in the background. Let me show the pending row, and I will pick up from a run I approved earlier."

**Model or API delay**

> "Reading the document depends on an outside API. The register still shows everything stored so far, and the source PDFs are all here."

**Internet drops**

> "This runs locally, so the register and the documents stay up. Only new document reading and email delivery need the outside connection."

---

## Language Rules

These are not stylistic preferences. The product's honesty boundary depends on them, and the same words are blocked in the dashboard itself.

Never say:

- "This confirms the vendor has active insurance."
- "This confirms additional insured status."
- "This detects cancellation."
- "This decides whether a vendor can be dispatched."
- "This replaces your broker."
- Any use of *compliant*, *verified*, *covered*, or *approved* to describe a vendor.

Say instead:

- "This tracks certificate paperwork."
- "This reads date and document facts."
- "This keeps the source PDF one click away."
- "This flags rows that need human review."
- "This drafts reminder emails and waits for the manager."

The distinction to keep in your head: the system reports what a document says. It never reports what is true.

---

## Pre-Recording Checklist

- [ ] Containers running in Docker Desktop
- [ ] All five workflows showing Active in n8n
- [ ] Dashboard loads and auto-refreshes
- [ ] Seven fixtures uploaded and the board checked
- [ ] `f02-expiring-20-days.pdf` held back for the Scene 3 upload
- [ ] Stage 6 watch executed so the approval email is waiting
- [ ] Approval email actually arrived in the demo mailbox
- [ ] No day counts quoted in the narration
- [ ] Notifications silenced, unrelated tabs closed
- [ ] Screen readable at the resolution you are recording

---

## Research Notes

Office-workflow context in this script reflects:

- Buildium's vendor insurance tracking guidance, which describes vendor insurance expiration notices in the vendor record: https://help.buildium.com/hc/s/article/Tracking-Vendor-Insurance-1557495330433
- RealPage's vendor credentialing overview, which lists COIs, liability, workers' comp, auto, licenses, W-9s, and background checks as common credentialing items: https://www.realpage.com/vendor-credentialing/
- Atlas Global Advisors' vendor onboarding checklist, which includes business license, COI, workers' comp documents, W-9, and background checks where applicable: https://atlasglobaladvisors.com/blog/vendor-onboarding-checklist-for-property-managers/
- OxMaint's property maintenance vendor management guide, which describes centralized vendor records and alerting before credentials lapse: https://oxmaint.com/industries/property-management/vendor-management-property-maintenance-guide
- NY DFS's ACORD 25 certificate filing, which states that the certificate is informational and does not change the policy: https://www.dfs.ny.gov/apps-and-licensing/insurance-companies/certificates-approved/acord-25-2025-12-liability
- Texas Department of Insurance certificate FAQ, which explains that additional-insured and cancellation-notice wording depends on policy or endorsement language: https://www.tdi.texas.gov/certificates/faq.html
