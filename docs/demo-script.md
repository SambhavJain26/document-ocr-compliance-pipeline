# Demo Script: Vendor COI Chasing Automation

Script for a recorded screen walkthrough, published to YouTube, aimed at US residential property management owners and operations leads.

Target length: 10:06. That is 1173 words of narration at an unhurried 130 words a minute, plus twelve percent for pauses and screen actions.

**Every scene timing below is computed from its own narration, not estimated.** If a scene gets longer, its slot and the chapter list have to be recomputed with it. A 6-minute cut is marked at each scene.

**Tone:** calm, plain, unhurried. Incident-report register. You are describing how a piece of office work was automated, not selling software.

---

## The framing this script exists to protect

**I do not sell software. I build automation inside a business that already exists.**

Every screen in this video is a surface that the automation renders so a human can see what it did. None of them is a product. There is no login to sell, no seats, no subscription, and no second customer for the same instance. It runs on the client's own server, reads their own mailbox, writes to their own database, and they own all of it when the work is finished.

That distinction is easy to lose on camera, because a dashboard looks like a product. Three rules keep it honest:

1. **Lead with the workflows, not the dashboard.** Scene 1 opens on the n8n workflow list. The viewer should understand that the automations are the deliverable before they ever see a nice-looking page.
2. **Name the responsible workflow every time something happens.** This is the spine of the video and the thing that makes it a build walkthrough rather than a product tour.
3. **Never say "the system does X" without saying which part.** Say "the intake workflow does X." A named workflow is a component someone can own. A "system" is a product someone rents.

Never say **my platform**, **my tool**, **my product**, **the app**, **users**, **sign up**, **onboard onto**, or **subscribers**.

Say **the intake workflow**, **the daily watch**, **your mailbox**, **your database**, **the office**, **the manager**.

---

## The five workflows, and what each one is responsible for

This table is the reference for the whole video. Every scene below names its workflow, and the recording carries an on-screen label so the viewer never has to guess.

| Workflow name in n8n | Responsible for | Triggered by |
|---|---|---|
| **Stage 5 - COI Intake Workflow** | Everything that happens to an arriving certificate: storing the original, reading it, checking it against the rules, filing the result | `Gmail Trigger - COI Intake`, `Form Trigger - Certificate Upload`, or a manual run |
| **Stage 5 - Source Document Route** | Serving the original PDF back when someone clicks the link on a row | `Webhook - Source PDF` |
| **Stage 6 - Daily Watch Chase** | Finding paperwork that is missing, lapsing or lapsed, drafting the reminder, holding it for a person, sending and logging it | `Schedule Trigger - Daily Watch 08:00` |
| **Stage 6 - Non PDF Reply Notice** | Vendor replies that are not certificates, so a plain text answer or a portal link becomes a manager notice rather than nothing | `Gmail Trigger - Stage 6 Replies` |
| **Stage 7 - Dashboard Demo View** | Rendering the register as a web page. This is a view, not an application | `Webhook - COI Dashboard` |

**A sixth workflow exists and does not run.** `Stage 4 - COI Extraction and Validation Core` is the harness the checking rules were built and tested in. The rules themselves live in one file, `scripts/lib/coi-stage-4-validator.js`, and are embedded into the intake workflow by a generator script. Worth knowing if a technical viewer asks why the checks behave identically everywhere. Do not put it on camera.

**A note on the names.** "Stage 5" and "Stage 6" are build stage names, not client-facing ones. Leave them as they are. They reinforce that this was constructed in a sequence for a specific job, which is the whole point. If a client later wants them renamed to match their own vocabulary, that is a fifteen-minute job and worth mentioning if it comes up.

### On-screen workflow labels

**Burn a persistent label into the top left of the recording** naming the workflow currently responsible, changing as the video moves between them. Small, muted, always present.

This is the single highest-value production decision in the video. It converts a screen recording into a map, and it is what a viewer will remember: not that a dashboard looked nice, but that a specific named thing was responsible for a specific behavior.

---

## YouTube package

### Title

**Recommended:** `How vendor COI chasing gets automated inside a property management office`

72 characters, inside the roughly 70 that stay visible before truncation. It names the job, names the audience, and the verb "gets automated" describes work being done rather than a product existing.

**Alternatives:**

- `Vendor COI tracking without a portal: a full automation walkthrough` (66)
- `I automated vendor insurance chasing. Here is every piece of it.` (63)

Avoid anything of the form "Introducing X" or "X Demo." Both read as a launch, and nothing is being launched.

### Description

First 100 characters stay visible before "Show more", so the first sentence has to stand alone.

> Vendor insurance certificates arrive, get read, and land in a register without anyone typing. Here is the whole thing, piece by piece.
>
> This is not a product and there is nothing to log into. It is custom automation built inside a property management company's existing tools: their mailbox, their database, their server. Five workflows do the work, and this video names which one is responsible for each thing you see.
>
> What it does: stores every original PDF before reading it, pulls the printed facts off the document, checks those facts against fixed rules that never vary, and files the result. Once a day it looks for paperwork that is missing or lapsing, drafts a reminder, and waits for a person to release it. Nothing reaches a vendor without that click.
>
> What it will not do, explained near the end: it will not tell you a vendor is insured. Nothing that reads a certificate can.
>
> All vendors, carriers, and policy numbers shown are synthetic test fixtures.
>
> Chapters below. If you run a property management company and want to know where your own paperwork stands, the last thirty seconds explain how.

### Chapters

Paste into the description as timestamps. YouTube builds the chapter bar automatically when the first is `0:00`.

```
0:00 A certificate arrives and nothing gets typed
0:22 What this actually is
1:20 The register, and why the wording matters
2:12 Watching one certificate go through intake
3:50 The four states, and the smaller notes
5:03 The original document, one click away
5:36 What happens when nothing arrives
7:04 Where it lives and who owns it
7:55 What it refuses to do
8:58 How to see where your own paperwork stands
```

### Hashtags

Three, per the platform note that the first three appear above the title.

`#PropertyManagement #AIAutomation #VendorInsurance`

`#VendorCompliance` is the industry's own umbrella term and would reach further, but it sits one letter from a word this build refuses to render. `#VendorInsurance` costs a little reach and carries no risk of looking like the thing the video spends nine minutes disowning.

---

## Before You Hit Record

The board must already have data on it. All staging is done through the same screens used in the demo, with no terminal at any point.

**1. Start the stack.** In Docker Desktop, start the `vendor-coi-chasing` containers. Wait until n8n, postgres and pgweb all show as running.

**2. Check the workflows.** Open n8n at `http://localhost:5678` and go to Workflows. All five must show **Active**:

- Stage 5 - COI Intake Workflow
- Stage 5 - Source Document Route
- Stage 6 - Daily Watch Chase
- Stage 6 - Non PDF Reply Notice
- Stage 7 - Dashboard Demo View

An inactive Stage 6 watch is the single most likely reason no approval email shows up in Scene 7. If anything is inactive, toggle it on and restart n8n from Docker Desktop.

This screen is also Scene 1, so make it presentable before you start. Sort it so the five sit together and nothing half-built is visible.

**3. Stage the board.** Open the upload form at `http://localhost:5678/form/coi-intake` and upload these seven PDFs from `fixtures/pdfs/`, one submission at a time. Each belongs to a different vendor, so none overwrite each other:

| File | Lands as |
|---|---|
| `f01-clean-current.pdf` | Apex Plumbing Services LLC, green, current |
| `f03-expired-34-days.pdf` | Circuit Square Electric LLC, red, lapsed |
| `f05-inverted-dates.pdf` | Summit Shield Roofing Inc., needs review |
| `f06-wrong-holder.pdf` | Greenline Groundskeeping LLC, filed with a holder note |
| `f07-low-limits.pdf` | Clearway Pest Control LLC, filed with a low-limit note |
| `f16-owner-llc-holder.pdf` | Evergreen Appliance Repair LLC, green, accepted owner LLC |
| `f20-cancellation-notice-wording.pdf` | Cedar Path Janitorial Services LLC, green, neutral note |

Do not upload `f13-renewal-coverage-gap.pdf` or `f12-renewal-supersede.pdf`. Both are renewals for vendors already in that list, `f13` supersedes the lapsed Circuit Square row and `f12` supersedes Blue Ridge, and you lose states the story depends on.

Hold back `fixtures/pdfs/f02-expiring-20-days.pdf`. That is the one uploaded live in Scene 4. Its vendor, Blue Ridge HVAC Co., is untouched by everything above, so it lands as a clean new amber row on camera.

**4. Confirm the board.** Open the dashboard and check those seven rows look right before recording anything.

**5. Verify the two refusals.** These never appear in the video, because refusals do not make good narration, but they are the most important behaviors to confirm before presenting. A silent failure here is worse than a crash. Upload both through the same form:

| File | Expected |
|---|---|
| `f11-not-a-certificate.pdf` | **No row changes at all.** Anchor Tile and Flooring LLC stays "No certificate on file". A manager notice is created instead. The intake workflow must not invent a certificate from a W-9 |
| `f18-password-protected.pdf` | Rapid Response Restoration LLC goes to **Needs review**, without the workflow erroring |

For `f11`, open the **Executions** tab on Stage 5 - COI Intake Workflow and confirm the run finished successfully. A clean finish that creates no certificate is the correct result, not a failure.

`f18` leaves an extra Needs review row on the board. That is harmless. It is a real review case and Scene 5 has plenty to point at either way.

**6. Prime the approval email.** A minute before you record Scene 7, open Stage 6 - Daily Watch Chase and click **Execute workflow**. The run pauses at `Gmail Approval - Send and Wait` and one approval email lands in the demo mailbox. Do this off camera so the email is already waiting, or show the click on camera if you would rather the trigger be visible.

After the Scene 7 approval, check `outreach_log` in pgweb for a row carrying the vendor, sent timestamp, recipient and follow-up date. That confirms the send was recorded, not just delivered.

**On resetting:** clearing the register back to 18 blank rows is the one thing with no path through these screens. It needs a script from a terminal, and you do not need it. Re-uploading a fixture through the form supersedes the earlier copy, so staging works from whatever state the board is currently in.

Tabs to have open, in this order:

1. n8n workflow list: `http://localhost:5678/home/workflows`
2. Dashboard: `http://localhost:5678/webhook/coi`
3. The upload form: `http://localhost:5678/form/coi-intake`
4. Gmail for the demo mailbox
5. File Explorer at `fixtures/pdfs/`
6. pgweb: `http://localhost:8081/?session=coi-only`

Close everything else. Silence notifications.

---

## Scene 1: A certificate arrives and nothing gets typed (0:00-0:22)

**Workflow on screen:** Stage 5 - COI Intake Workflow

**Screen:** Gmail, an unread message with a PDF attachment. Open it, show the attachment, do not download it. Cut to the dashboard and let the row fill in.

This is the cold open. It shows the outcome before any explanation, because the first fifteen seconds decide whether anyone watches the other nine minutes.

> "A vendor emails their insurance certificate. Nobody opens the PDF, nobody types a date anywhere, and the register updates itself."

Let the row sit for a beat.

> "That is the idea. The rest of this is every piece of how it works, and which part is responsible for what."

*6-minute cut: keep, trimmed to the first line.*

---

## Scene 2: What this actually is (0:22-1:20)

**Workflow on screen:** the n8n workflow list, all five

**Screen:** the n8n Workflows page, five rows showing Active. Move down them as they are named.

This scene carries the positioning. If a viewer takes one thing away, it should be this.

> "One thing first, because it changes how you read the rest. This is not a product. Nothing to log into, no seats, no monthly fee, nothing for your vendors to join."

Point at the list.

> "What got built is this. Five automations on a server the client owns, reading the mailbox they already use, writing to a database that belongs to them."

Move down the rows as they are named.

> "Intake handles an arriving certificate. The source route hands the original PDF back. The daily watch finds paperwork running out and drafts the reminder. The reply notice catches vendor answers that are not certificates. The dashboard workflow renders the register."

> "Every screen after this is one of those five doing something, labelled in the corner."

*6-minute cut: keep the first two lines and the list on screen. Drop the per-workflow narration.*

---

## Scene 3: The register, and why the wording matters (1:20-2:12)

**Workflow on screen:** Stage 7 - Dashboard Demo View

**Screen:** Dashboard, scrolled to the top. Let the rows sit for three seconds before speaking.

> "Most property management companies already have this list. Knowing who your vendors are was never the hard part. It starts after the first certificate is filed."

> "This page is rendered by one of those five workflows. No application, no accounts. It exists so a person can see what the other four did."

Point at the status column and slow down.

> "Read the status wording, the most deliberate thing here. Current until a date. Expires in a number of days. Lapsed a number of days ago. No certificate on file. Needs review."

Short pause.

> "Every one of those is a fact printed on a document. Not one is a judgment about insurance."

*6-minute cut: keep the first line and the status paragraph.*

---

## Scene 4: Watching one certificate go through intake (2:12-3:50)

**Workflow on screen:** Stage 5 - COI Intake Workflow

**Screen:** the upload form, then n8n Executions, then the dashboard.

> "So let us put one through. In a real office this arrives as an email attachment and the Gmail trigger picks it up. The upload form is the same path from step two on."

Drag the held-back PDF onto the form. Submit.

> "Ordinary certificate PDF. Nothing typed."

Switch to the intake workflow's Executions tab and open the run. Let the node path light up on camera.

> "This is the intake workflow running, and the order matters."

Point at `Write Original PDF To Storage`.

> "The original is written to disk before anything reads it. If every step after this failed, the document would still be filed and linked from the row."

Point at the extraction nodes.

> "Then it reads, text layer first, falling back to reading the page visually if the document is a scan."

Point at `Normalize Validate Stage 5 Result`.

> "This node matters most. The model transcribes what the page says and rates its own confidence. It is never asked whether the certificate is acceptable. Every decision happens here, in fixed rules that run identically every time. Is the expiration after the effective date. Does the holder match one of your legal names."

> "The reason to split it that way: a model that reads something wrong is checkable, because the document is one click away. A model that decides something wrong is invisible."

Switch to the dashboard. It refreshes every five seconds.

> "And there it is. Carrier, policy number, limit, expiration date, counting down."

**Do not quote a specific day count in the narration.** Fixture dates are fixed, so the countdown shifts by one every day since the fixtures were generated. Describe the behavior and let the screen show the number.

*6-minute cut: keep the upload, the storage-first point, and the result. Cut the extraction paragraph and shorten the validation point to its first two sentences.*

---

## Scene 5: The four states, and the smaller notes (3:50-5:03)

**Workflow on screen:** decisions made in Stage 5 - COI Intake Workflow, rendered by Stage 7 - Dashboard Demo View

**Screen:** Dashboard. Move down the rows deliberately.

> "The whole board is really four situations."

Point at a current row, then the expiring row.

> "Current, with a date attached. Nothing to do. Running out soon, the one that used to depend on somebody remembering."

Point at a lapsed row.

> "Past the date printed on the document. Notice what it is not saying. It is not saying this vendor cannot work. It is saying the paperwork on file has run out."

Point at a review row.

> "This one waits for a person. The dates were inverted, expiration before effective. It could have picked one. It does not guess. A holder name that is not yours, a locked file, a vendor name one keystroke from an existing one, all of it goes to review rather than becoming a number in a column."

Point at an amber note under a vendor name.

> "Smaller problems become notes, not alarms. This one came in under the limit for that trade. Filed, visible, not a crisis. Sorting by severity is most of the work."

*6-minute cut: keep current, lapsed and review. Drop the notes paragraph.*

---

## Scene 6: The original document, one click away (5:03-5:36)

**Workflow on screen:** Stage 5 - Source Document Route

**Screen:** Click a source link on a row. Let the PDF open. Hold on it for three full seconds before speaking.

> "Every row links back to the certificate it came from. Separate small workflow. The link hits a webhook, it looks up where the file was stored, and hands the original back."

> "Something read this and put facts in a table. Checking a date against the original is one click, not a search through an inbox. Nobody has to take an automation's word for anything."

Close the tab. Return to the dashboard.

*6-minute cut: keep. It answers the trust objection before it gets asked.*

---

## Scene 7: What happens when nothing arrives (5:36-7:04)

**Workflow on screen:** Stage 6 - Daily Watch Chase

**Screen:** the daily watch workflow, then Gmail, then the outreach log.

> "Everything so far assumed a certificate turned up. The other half of the job is what happens when one does not."

Show the workflow, point at the schedule trigger.

> "This runs once a day, sorting every vendor: never received anything, lapsed, running out in fourteen days, thirty, sixty. Vendors with no certificate come first, because they have no date to remind anyone."

Point at the drafting node.

> "For each one it drafts a short email naming the vendor, the policy number and the date, making no claims about insurance."

Point at `Gmail Approval - Send and Wait`.

> "Then it stops."

Switch to Gmail and open the approval email.

> "The manager gets this first. The vendor, the reason, the recipient, and the exact message that would be sent."

Click **Approve**.

> "To be precise: I approved that a reminder gets sent. I did not approve the vendor for anything. If nobody clicks within twenty four hours, it expires rather than sending."

Show the sent message, then the outreach log row.

> "The vendor can reply with the certificate attached or use the upload link. Either way it lands back in intake, and the send is logged. Ignore two requests and it stops chasing, handing the vendor to the manager rather than emailing somebody forever."

*6-minute cut: keep the schedule line, the approval email, the click and the log. Drop the drafting node and the bucket detail.*

---

## Scene 8: Where it lives and who owns it (7:04-7:55)

**Workflow on screen:** none. This is the database and the execution history.

**Screen:** pgweb showing the `coi_pgweb` views, then n8n's execution history.

This scene used to be optional and technical. It is now the point of the video, because it is what separates this from buying a product.

> "Worth being concrete about where this sits, because it is the difference between this and buying software."

Show the views, then the execution history.

> "Vendors, certificates, coverage lines, reminder history. An ordinary database on the client's own server. Not my account, no shared instance, no other customer in it. And this is every run, with what happened and when."

> "It all exports. Workflows are files, the database takes a standard dump, the certificates are PDFs in dated folders. Handing it to another developer is a folder and an afternoon. Nothing here holds their data hostage, because there is nothing of mine to hold it in."

*6-minute cut: keep the first two lines.*

---

## Scene 9: What it refuses to do (7:55-8:58)

**Screen:** Dashboard, static. Then the verification script's forbidden-word check, briefly.

> "Last thing, and it is the part I would want to hear if I were watching this."

> "It will not tell you a vendor is insured, and nothing that reads a certificate can. A certificate describes the day it was issued. It cannot see a cancellation, read an endorsement, or decide who works on a property. That belongs with the agent and the manager."

Show the check.

> "Four words are blocked from anything the dashboard renders. If one appears in the page, the build fails and it does not ship."

> "And two statuses can only be set by a person: cancelled and non-renewed. Nothing in a certificate reveals either, so a manager sets them by hand rather than an automation pretending it found something."

*6-minute cut: keep the first paragraph and the two-statuses line.*

---

## Scene 10: How to see where your own paperwork stands (8:58-10:06)

**Screen:** Dashboard.

> "So: it arrives, it gets stored, it gets read, fixed rules decide, the register updates, and anything unclear waits for a person."

Short pause.

> "This is not an enterprise risk platform and is not trying to be. It is the part of the job that currently lives in a spreadsheet, an inbox and somebody's memory."

Close on the offer.

> "If you want to know where your own paperwork stands, send me ten vendor certificates. I will run them and send back one page: what is current, what has lapsed, what is missing, what needs a look. No access to your software, nothing to install, no cost. If it is in decent shape, that is what the page will say."

> "Vendor documents only, nothing with resident information, and I delete the files when I send the page back."

---

## If They Ask

Short answers to what comes back most often.

**"Does this tell me if a vendor is actually insured?"**
No, and nothing that reads a certificate can. A certificate is a snapshot of what was on file the day it was issued. This tracks the paperwork and the dates. Policy status belongs with the agent or carrier.

**"What if it reads the document wrong?"**
Then the row goes to review rather than getting a number typed into it. That is why the source PDF sits on every row. The reading is checkable, not final, and low-confidence documents are routed to a person by design.

**"Is this a product I'd be buying?"**
No. It is a build. The workflows run on your server, read your mailbox and write to your database, and you own all of it when it is done. There is no login, no seats and no subscription for a dashboard. If we stopped working together it would keep running, because there is no service of mine in the middle of it.

**"We already have this in our property management software."**
Most of them have a field for it, and the field is not the problem. Keeping the field current is the problem, and that still means somebody opening PDFs and typing dates. This is the part before the field.

**"Will it email my vendors without me knowing?"**
No. Nothing goes out without a person clicking approve on that specific message, and an unanswered request expires rather than sending. That is the gate in Scene 7.

**"How long to set up?"**
Load the vendor list, confirm the legal names that should appear as certificate holder, connect the mailbox, then batch through the certificates you already have. The first useful output is the register.

**"What happens if you disappear?"**
Everything exports. Workflow files, a database dump, and the PDFs in dated folders. Another developer can pick it up, which is a reasonable thing to want and a fair thing to ask about.

---

## Fallback Lines

If something stalls mid-recording, say one of these and keep moving. Do not apologize or troubleshoot on camera.

**Gmail is slow**

> "Gmail delivery can lag by a minute. The intake already ran and the register is updated, so let me show that first and come back to the email."

**Approval link does not resume**

> "That approval is a step held open in the background waiting for a click. Let me show the pending row, and I will pick up from a run I approved earlier."

**Model or API delay**

> "Reading the document depends on an outside API. Everything stored so far is still on the register, and the source PDFs are all here."

**Internet drops**

> "This runs on a local machine, so the register and the documents stay up. Only new document reading and email delivery need the outside connection."

**A workflow execution errors on camera**

> "That is what the execution history is for. It caught it, it kept the original PDF, and nothing got filed from a failed run. Let me open the run and show you."

---

## Language Rules

Not stylistic preferences. The honesty boundary depends on them, and the same four words are blocked in the dashboard itself.

**Never say:**

- "This confirms the vendor has active insurance."
- "This confirms additional insured status."
- "This detects cancellation."
- "This decides whether a vendor can be dispatched."
- "This replaces your broker."
- Any use of *compliant*, *verified*, *covered* or *approved* to describe a vendor or a certificate.

**Say instead:**

- "This tracks certificate paperwork."
- "This reads date and document facts."
- "This keeps the source PDF one click away."
- "This flags rows that need a person."
- "This drafts reminder emails and waits for the manager."

**On the word approve.** It appears once, in Scene 7, as the verb for a human releasing an email. That use is precise and worth keeping, and the line immediately after it draws the distinction out loud: approving the email is not approving the vendor. Never use it any other way.

**Product language to avoid**, separate from the honesty rules and just as important:

| Do not say | Say |
|---|---|
| my platform, my tool, my product, the app | the intake workflow, the daily watch, the build |
| users, subscribers, customers of the tool | the manager, the office, whoever handles the paperwork |
| sign up, onboard onto, log in to | nothing, there is no account |
| the system does X | the intake workflow does X |

The last row is the one that slips most often under recording pressure. "The system" is how a product describes itself. A named workflow is a component someone owns.

The distinction to keep in your head throughout: it reports what a document says. It never reports what is true.

---

## Pre-Recording Checklist

- [ ] Containers running in Docker Desktop
- [ ] All five workflows showing Active in n8n, list tidy enough to film for Scene 2
- [ ] Dashboard loads and auto-refreshes
- [ ] Seven fixtures uploaded and the board checked
- [ ] Both refusals verified off camera (`f11`, `f18`)
- [ ] `f02-expiring-20-days.pdf` held back for Scene 4
- [ ] Stage 6 watch executed so the approval email is waiting
- [ ] Approval email actually arrived in the demo mailbox
- [ ] pgweb showing only `coi_pgweb` views, no n8n internal tables
- [ ] Workflow label overlay prepared for all five names
- [ ] No day counts quoted in the narration
- [ ] "Synthetic test data" label ready for the first ten seconds
- [ ] Notifications silenced, unrelated tabs closed
- [ ] Screen readable at the recording resolution

---

## Research Notes

Office-workflow and insurance context in this script reflects:

- Buildium's vendor insurance tracking guidance, which describes vendor insurance expiration notices in the vendor record: https://help.buildium.com/hc/s/article/Tracking-Vendor-Insurance-1557495330433
- RealPage's vendor credentialing overview, which lists COIs, liability, workers' comp, auto, licenses, W-9s and background checks as common credentialing items: https://www.realpage.com/vendor-credentialing/
- Atlas Global Advisors' vendor onboarding checklist, which includes business license, COI, workers' comp documents, W-9 and background checks where applicable: https://atlasglobaladvisors.com/blog/vendor-onboarding-checklist-for-property-managers/
- OxMaint's property maintenance vendor management guide, which describes centralized vendor records and alerting before credentials lapse: https://oxmaint.com/industries/property-management/vendor-management-property-maintenance-guide
- NY DFS's certificate filing, which states that the certificate is informational and does not change the policy: https://www.dfs.ny.gov/apps-and-licensing/insurance-companies/certificates-approved/acord-25-2025-12-liability
- Texas Department of Insurance certificate FAQ, which explains that additional-insured and cancellation-notice wording depends on policy or endorsement language: https://www.tdi.texas.gov/certificates/faq.html

Behavior described in the scenes traces to `docs/how-the-system-works.md`, `scripts/lib/coi-stage-4-validator.js`, and the workflow exports in `n8n-workflows/`.
