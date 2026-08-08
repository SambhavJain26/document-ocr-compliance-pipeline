# Demo Script: Vendor COI Chasing Automation

A recorded screen walkthrough for YouTube, aimed at people who run US residential property management companies.

**Target length:** about 10 minutes. A 6-minute cut is marked at every scene.

**How to read this file.** Every scene has the same four parts, in the same order:

1. **On screen:** what the viewer is looking at
2. **You do:** the exact clicks, in order
3. **You say:** the narration, in quotes
4. **Why this scene is here:** one line, for you, not for the viewer

Everything in "You do" has been run against the real system. Nothing in here asks you to click something that breaks the flow. Where a step has a trap in it, the trap is called out in the scene rather than left for you to find on camera.

---

## The voice

You are talking to one person. Not an audience, not a room. Someone who runs a management company, sitting at their desk, half deciding whether to close the tab.

That means:

- **"You", not "people" or "companies".** Not "property managers often struggle to track certificates." Instead: "you already know which vendor you'd have to go digging for."
- **Contractions.** "It doesn't", "you've", "that's". Reading a script aloud without contractions is what makes a video sound like a presentation.
- **Short sentences.** Then occasionally a longer one, so it doesn't turn into a list.
- **No throat-clearing.** No "in this video I'll be showing you". Just start.
- **No selling words.** No "powerful", "seamless", "game-changing". If a sentence would sound strange said to one person across a desk, cut it.

Read every scene out loud before recording. If you run out of breath, the sentence is too long.

---

## What this is, and the line you must not cross

**I don't sell software. I build automation inside a business that already exists.**

Every screen in this video is something the automation renders so a person can see what it did. None of it is a product. No login, no seats, no subscription, no second customer on the same instance. It runs on the client's own server, reads their own mailbox, writes to their own database, and they own all of it when the work is done.

That's easy to lose on camera, because a dashboard looks like a product. Three rules keep it honest:

1. **Lead with the workflows, not the dashboard.** The viewer should see that the automations are the deliverable before they see a nice-looking page.
2. **Name the workflow every time something happens.** This is what makes it a build walkthrough instead of a product tour.
3. **Never say "the system does X".** Say "the intake workflow does X". A named workflow is a component someone owns. A "system" is a product someone rents.

Never say **my platform**, **my tool**, **my product**, **the app**, **users**, **sign up**, or **subscribers**.

Say **the intake workflow**, **the daily watch**, **your mailbox**, **your database**, **the office**, **the manager**.

---

## The five workflows on camera

Every scene names one of these five. Burn a small, muted label into the top left of the recording naming the workflow currently responsible, and change it as the video moves between them. This single production decision is what turns a screen recording into a map.

| Name in n8n | Responsible for | Started by |
|---|---|---|
| **COI Intake** | Everything that happens to an arriving certificate: storing the original, reading it, checking it, filing the result | Gmail trigger, the upload form, or a manual run |
| **Source Document Route** | Handing the original PDF back when someone clicks the link on a row | The source PDF webhook |
| **Daily Watch and Chase** | Finding paperwork that's missing or running out, drafting the reminder, and dispatching each vendor for approval | Schedule trigger at 08:00 |
| **Non-PDF Reply Notice** | Vendor replies that aren't certificates, so a text answer or a portal link becomes a manager notice instead of nothing | Gmail trigger on replies |
| **COI Dashboard** | Rendering the register as a web page. A view, not an application | The dashboard webhook |

**Two more exist in the workflow list and don't get their own scene.**

`Extraction and Validation Core` doesn't run at all — it's the harness the checking rules were built in. Worth knowing if a technical viewer asks why the checks behave identically everywhere. Keep it off camera.

`Vendor Approval Request` genuinely runs, every time. Daily Watch and Chase calls it once per actionable vendor, and it's where the Gmail approval gate actually lives. It's split out on purpose: an n8n Wait node can only pause an execution once, so giving every vendor their own paperwork request run as one shared execution meant only the first vendor ever got a real pause — everyone else was silently marked declined a few milliseconds after the first click, without ever getting an email. Calling a separate workflow once per vendor gives each one its own genuine execution and its own genuine pause. You don't need to explain this on camera; Scene 7 shows the result of it (multiple approval emails, each independently clickable) without naming the mechanism.

---

## Before you hit record

### 1. Check the model, before anything else

This is the step that will silently ruin a recording, so it goes first.

Open pgweb at `http://localhost:8081/?session=coi-only` and check `client_config`. **`model_id` must be `gpt-5.6-luna`.** The tested fallback is `gpt-5.4-mini`.

If it says `gpt-5.4-nano`, stop and fix it. Verified on 2026-08-05: the nano tier reads the watermarked test certificates as "not a certificate of insurance" and refuses to file them, with high confidence. Your staging will appear to work, every upload will finish cleanly, and the board will stay empty. There is no error to see.

The fixtures carry a `SPECIMEN - SYNTHETIC TEST DOCUMENT` watermark on purpose, for copyright reasons. Real client certificates won't have it, so this only affects the demo fixture set.

### 2. Start the stack, then run the reset

In Docker Desktop, start the `vendor-coi-chasing` containers. Wait for n8n, postgres and pgweb to all show running.

Then, from the repo root:

```bash
.\scripts\reset-demo.ps1
```

**Run this on the day you record, even if the board is already clean.** It is not only a reset. It also creates today's certificate storage folder, and without that folder every upload fails.

Certificates are stored under a dated path, `data/certificates/YYYY/MM/DD`, and n8n's write node cannot create the folder itself. The date rolls over at UTC midnight. So a stack that worked perfectly yesterday will fail on the first upload today, at the `Write Original PDF To Storage` node, with **"The file or directory does not exist"**. Nothing else is broken when that happens, and the fix is this one command.

This has already interrupted one recording. If you stage the board one day and record the next, run the reset again before you record.

### 3. Check all six workflows are Active

Open `http://localhost:5678/home/workflows`. Six rows now, and all six must show **Active**:

COI Intake · Source Document Route · Daily Watch and Chase · Vendor Approval Request · Non-PDF Reply Notice · COI Dashboard

An inactive Daily Watch and Chase or Vendor Approval Request is the most likely reason no approval email turns up later — Daily Watch and Chase calls Vendor Approval Request once per vendor, and that call fails outright if the target isn't active. If anything is inactive, toggle it on and restart n8n from Docker Desktop.

This screen is Scene 2, so tidy it now. Sort it so the five on-camera workflows sit together; `Vendor Approval Request` never gets its own scene, so keep it out of the way rather than centred.

### 4. Stage the board

Open `http://localhost:5678/form/coi-intake` and upload these seven from `fixtures/pdfs/`, **one submission at a time, waiting for each to finish**.

| File | Lands as |
|---|---|
| `f01-clean-current.pdf` | Apex Plumbing, green, current until Mar 2027 |
| `f03-expired-34-days.pdf` | Circuit Square Electric, red, lapsed |
| `f05-inverted-dates.pdf` | Summit Shield Roofing, red, Needs review |
| `f06-wrong-holder.pdf` | Greenline Groundskeeping, amber, holder note |
| `f07-low-limits.pdf` | Clearway Pest Control, amber, low-limit note |
| `f16-owner-llc-holder.pdf` | Evergreen Appliance Repair, amber |
| `f20-cancellation-notice-wording.pdf` | Cedar Path Janitorial, amber |

**Upload them one at a time.** Batching them through a single run produces inconsistent results.

**Don't upload** `f13-renewal-coverage-gap.pdf` or `f12-renewal-supersede.pdf`. Both are renewals that supersede rows the story depends on.

**Hold back** `f02-expiring-20-days.pdf`. That's the one you upload live in Scene 4. Its vendor, Blue Ridge HVAC, is untouched by everything above.

### 4b. Put the Scene 1 email in the mailbox

Scene 1 opens on an email arriving. **Nothing else in this prep puts an email in that mailbox**, so you have to send one, and you have to send it before you record.

From any account, send an email to `sambhavn8n@gmail.com` with `fixtures/pdfs/f08-multiple-expiry-dates.pdf` attached. Subject and body do not matter. That fixture belongs to Bright Hall Cleaning Co., which none of the seven staged fixtures touch, so it lands as its own new row.

Then wait about two minutes and check the dashboard. Bright Hall should now have a certificate on it. The Gmail trigger polls once a minute.

Three things to know:

- **Do not open the email before it processes.** The trigger only looks at **unread** messages with an attachment. If you read it first, it can be skipped entirely.
- Once it has processed, the message stays unread, so you can still open it on camera. That is the point: by the time you record, the row is genuinely already there, and you are showing the email that produced it.
- If Bright Hall does not appear after three minutes, the Gmail trigger is not picking mail up. Do not burn recording time on it. Use the Gmail fallback at the end of this file, which opens Scene 1 on the upload form instead.

**Honest note:** the Gmail *sending* path is tested and working. The Gmail *intake* trigger has not been verified end to end with a real inbound email on this setup. Scene 1 is the only scene that depends on it. Test it before you record, not during.

### 5. Confirm what the board actually looks like

Open the dashboard. Rows now sort best first, so the board reads top to bottom as: green, then amber notes, then expiring, then expired, then Needs review, and vendors with nothing on file at the bottom.

You should have **exactly two green rows**: Apex Plumbing and Bright Hall Cleaning. Everything else that filed carries at least one amber note. That surprises people, so here it is in full, in the order it appears. Verified 2026-08-07:

| # | Vendor | Status | Tone | Notes shown |
|---|---|---|---|---|
| 1 | Apex Plumbing | Current until Mar 30, 2027 | green | none |
| 2 | Bright Hall Cleaning | Current until Sep 15, 2026 | green | none |
| 3 | Cedar Path Janitorial | Current until Jul 1, 2027 | amber | no workers' comp line |
| 4 | Greenline Groundskeeping | Current until May 1, 2027 | amber | holder mismatch, no WC line |
| 5 | Evergreen Appliance Repair | Current until Apr 1, 2027 | amber | no workers' comp line |
| 6 | Clearway Pest Control | Current until Jan 1, 2027 | amber | limit below minimum, no WC line |
| 7 | Circuit Square Electric | Expired *(n)* days ago | red | no WC line, no cancellation wording |
| 8 | Summit Shield Roofing | Needs review | red | low confidence, dates inverted, others |
| 9+ | The other 10 | No certificate on file | grey | |

Bright Hall is there because it is the Scene 1 email from step 4b. If you skipped that step, you will have one green row instead of two, and Scene 1 has nothing to show.

Most of the amber is the missing workers' compensation line. Only one seeded vendor is marked WC-exempt (Mason Creek Handyman), so a GL-only certificate raises a note on everybody else. That's correct behavior and fine on camera, but don't call a row "green" in narration unless it's Apex or Bright Hall.

After Scene 4's live upload, Blue Ridge HVAC appears between the amber rows and Circuit Square, reading "Expires in *(n)* days".

### 6. Check the two refusals, off camera

These never appear in the video. They're the most important things to confirm, because a silent failure here is worse than a crash. Upload both through the same form:

| File | What should happen |
|---|---|
| `f11-not-a-certificate.pdf` | **Nothing changes on the board.** Anchor Tile stays "No certificate on file". A manager notice is created instead. The intake workflow must not invent a certificate from a W-9 |
| `f18-password-protected.pdf` | **Also nothing visible on the board.** It creates a Needs review record, but a locked file can't be read, so no vendor name comes out of it and it attaches to no vendor. Rapid Response Restoration stays "No certificate on file" |

That second one is worth understanding before someone asks. A password-protected PDF produces a review item with no vendor attached, and the dashboard is one row per vendor, so there's nothing new to see. The run finishes cleanly. That is the correct result, not a failure.

For both, open the **Executions** tab on COI Intake and confirm the run finished successfully.

### 7. Know what the daily watch will actually do

**Do not expect one approval email.** With the board staged as above, the daily watch finds **13 things to chase**: 12 vendors with no certificate on file at all, plus Circuit Square, whose certificate has lapsed.

Every one of those gets dispatched to its own **Vendor Approval Request** run, and those runs go out together, not one after another. So the correct expectation is: 13 approval emails, arriving within a few seconds of each other, all sitting unread at once. Approving or ignoring one has no effect on the rest — each is a fully separate execution with its own 24-hour expiry. For the video you only ever open and click the one you chose in Scene 7's prep. The rest can sit unapproved and expire on their own.

Count the grey rows on your dashboard before recording. Grey rows plus red rows is the number the watch will find, and Scene 7 says that number out loud.

### 8. Gmail

Scenes 1 and 7 need working Gmail OAuth in n8n. Scene 1 shows a certificate arriving by email, and Scene 7 is the approval. If Gmail is not connected, see the fallback at the end of this file before recording.

The demo mailbox is `sambhavn8n@gmail.com`, and it is both the approver and the test recipient. Two things to check:

- **The n8n credential must be named exactly `Gmail account`.** Four Gmail nodes reference it by that name, spread across three workflows: two in COI Intake and Non-PDF Reply Notice, and two in Vendor Approval Request (the approval send and the approved send). A credential under a different name leaves them unbound, and the symptom is an approval email that simply never arrives, with no obvious error.
- **`stage_6_approver_email` and `stage_6_test_recipient_email` must both be set** in `client_config`. If either is blank, the run stores a config notice and emails nobody, which is deliberate but will look like nothing happened.

Approver and recipient being the same address is fine. It means the approval request and the resulting vendor email both land in the same inbox, so searching All Mail by exact subject is clearer than watching the Primary tab.

While `stage_6_outbound_test_mode` is `true`, the approved send is redirected to the test recipient rather than the real producer. Leave it true for recording.

### Tabs to have open

1. n8n workflows: `http://localhost:5678/home/workflows`
2. Dashboard: `http://localhost:5678/webhook/coi`
3. Upload form: `http://localhost:5678/form/coi-intake`
4. Gmail for the demo mailbox
5. File Explorer at `fixtures/pdfs/`
6. pgweb: `http://localhost:8081/?session=coi-only`

Close everything else. Silence notifications.

### On resetting

Clearing the board back to 18 blank rows is the one thing with no path through these screens. It needs `.\scripts\reset-demo.ps1` from a terminal. You don't need it mid-recording, because re-uploading a fixture supersedes the earlier copy.

---

## Scene 1: Nothing gets typed (0:00 - 0:20)

**Workflow label:** COI Intake

**Before this scene:** you sent the Scene 1 email in prep step 4b, waited, and confirmed Bright Hall Cleaning Co. now has a certificate on the dashboard. The email is still unread.

**On screen:** Gmail, then the dashboard.

**You do:**

1. Open Gmail for `sambhavn8n@gmail.com`. The email you sent yourself is sitting there unread with a PDF attached.
2. Click it open. Let the attachment name show. Do not download or preview it.
3. Switch to the dashboard tab, `http://localhost:5678/webhook/coi`.
4. Point at the Bright Hall Cleaning Co. row, which already has a carrier, a policy number and a date on it.

**You say:**

> "A vendor sends you their insurance certificate. Nobody opens the PDF. Nobody types a date anywhere. And the register updates itself."

Let the row sit for a beat.

> "That's the whole idea. The rest of this is how it works, and which piece is responsible for what."

**Watch out for:** the row must already be populated before you start filming. You are not waiting for it live in this scene. If you try to time it live and the poll has not fired, you will be sitting in silence.

**Why this scene is here:** the first fifteen seconds decide whether anyone watches the other nine minutes. Show the outcome before any explanation.

*6-minute cut: keep, first line only.*

---

## Scene 2: This isn't a product (0:20 - 1:15)

**Workflow label:** the workflow list

**On screen:** the n8n Workflows page.

**You do:**

1. Go to `http://localhost:5678/home/workflows`.
2. Sit still on the list for a second so the viewer can read it. The five you're about to name show **Active**; ignore any other rows.
3. Move your cursor down the five names as you say each one, skipping past `Vendor Approval Request` and `Extraction and Validation Core` if either is in view. Neither gets its own explanation on camera.

**You say:**

> "One thing first, because it changes how you read everything after it. This isn't a product. There's nothing to log into, no seats, no monthly fee, and nothing for your vendors to sign up for."

Point at the list.

> "What got built is this. Five automations, on a server you own, reading the mailbox you already use, writing to a database that belongs to you."

Move down the rows.

> "Intake handles an arriving certificate. The source route hands the original PDF back when you click it. The daily watch finds paperwork running out and drafts the reminder. The reply notice catches vendor answers that aren't certificates. And the dashboard renders the register."

> "Everything after this is one of those five doing something, and I'll tell you which."

**Watch out for:** the list now shows six or seven rows, not five. `Vendor Approval Request` is real and runs every time Daily Watch and Chase does, and `Extraction and Validation Core` doesn't run at all. Scroll so the five named ones sit together and neither extra row needs explaining.

**Why this scene is here:** this carries the positioning. If a viewer takes one thing away, it should be this.

*6-minute cut: keep the first two lines and the list. Drop the per-workflow narration.*

---

## Scene 3: Read the wording (1:15 - 2:05)

**Workflow label:** COI Dashboard

**On screen:** the dashboard, scrolled to the top.

**You do:**

1. Switch to the dashboard tab and scroll to the very top.
2. Say nothing for three seconds. Let them read.
3. Move your cursor slowly down the Status column while you talk.

**You say:**

> "You've probably got this list already. Knowing who your vendors are was never the hard part. It gets hard after the first certificate is filed."

> "This page is rendered by one of those five workflows. No accounts, nothing stored here. It exists so a person can see what the other four did."

Point at the status column.

> "Read the status wording, because it's the most deliberate thing on this screen. Current until a date. Expires in so many days. Expired so many days ago. No certificate on file. Needs review."

Short pause.

> "Every one of those is a fact printed on a document. Not one of them is a judgment about insurance."

**Why this scene is here:** the honesty boundary, stated early, in the viewer's own interest rather than as a disclaimer.

*6-minute cut: keep the first line and the status paragraph.*

---

## Scene 4: Watch one go through (2:05 - 3:40)

**Workflow label:** COI Intake

**Before this scene:** `f02-expiring-20-days.pdf` has not been uploaded yet. Blue Ridge HVAC Co. still reads "No certificate on file", near the bottom of the board.

**On screen:** the upload form, then n8n Executions, then the dashboard.

**You do:**

1. Switch to the form tab, `http://localhost:5678/form/coi-intake`.
2. Drag `fixtures/pdfs/f02-expiring-20-days.pdf` onto the file field. Click **Submit**. You get a short confirmation.
3. Switch to n8n. Open **COI Intake**, then the **Executions** tab at the top of the workflow. The newest run is at the top of the list. Click it.
4. The canvas opens with the path it took lit up. Point at **Write Original PDF To Storage**.
5. Point at **Extract Text From Stored PDF** and the two **OpenAI Extract** nodes.
6. Point at **Normalize Validate Stage 5 Result**.
7. Switch to the dashboard. It refreshes itself every five seconds. Blue Ridge HVAC has moved up the board with a date on it.

**You say:**

> "Let's put one through. In your office this arrives as an email attachment and the Gmail trigger picks it up. This form is the same path from step two onward."

Drag and submit.

> "Ordinary certificate PDF. Nothing typed."

Open the execution.

> "This is the intake workflow running, and the order matters."

Point at the storage node.

> "The original gets written to disk before anything reads it. If every step after this failed, you'd still have the document, and it'd still be linked from the row."

Point at the extraction nodes.

> "Then it reads. Text layer first. If the document's a scan, or a photo somebody took on their phone, it falls back to reading the page visually."

Point at the validation node.

> "This node is the one that matters most. The model transcribes what the page says, and rates how sure it is. It's never asked whether the certificate is acceptable. Every decision happens here, in fixed rules that run identically every time. Is the expiration after the effective date. Does the holder match one of your legal names."

> "Here's why that split matters to you. A model that reads something wrong is checkable, because the document is one click away. A model that decides something wrong is invisible."

Switch to the dashboard.

> "And there it is. Carrier, policy number, limit, expiration date, counting down."

**Watch out for:**

- The run takes roughly ten to twenty seconds. Do not cut to Executions instantly. Talk through the first line while it finishes.
- Do not say a number of days. The fixture dates are fixed, so the countdown shifts by one every day. Let the screen show it.

**Why this scene is here:** this is the mechanism. Storage-before-reading and the reading/deciding split are the two things that earn trust.

*6-minute cut: keep the upload, the storage point, and the result. Cut the extraction paragraph, shorten the validation point to its first two sentences.*

---

## Scene 5: Four states, and the smaller notes (3:40 - 4:50)

**Workflow label:** decisions from COI Intake, rendered by COI Dashboard

**On screen:** the dashboard.

**Board order, top to bottom:** clean rows first, then rows carrying a note, then anything expiring, then expired, then Needs review, and vendors with nothing on file last. So you are walking down the board from settled to unsettled, which is the order you narrate in.

**You do:**

1. Point at **Apex Plumbing Services LLC** at the top. Green, no notes.
2. Point at **Blue Ridge HVAC Co.**, the row you created in Scene 4.
3. Scroll down to **Circuit Square Electric LLC**, the red expired row.
4. Point at **Summit Shield Roofing Inc.**, the Needs review row.
5. Point at the small amber note under **Clearway Pest Control LLC**, which reads that a limit is below the minimum.

**You say:**

> "The whole board is really four situations."

Point at Apex, then Blue Ridge.

> "Current, with a date on it. Nothing to do. Running out soon, which is the one that used to depend on somebody remembering."

Point at Circuit Square.

> "Past the date printed on the document. Notice what that's not saying. It isn't saying this vendor can't work. It's saying the paperwork you have has run out."

Point at Summit Shield.

> "This one's waiting for a person. The dates were inverted, expiration before effective. It could have picked one. It doesn't guess. A holder name that isn't yours, a locked file, a vendor name one keystroke from one you already have, all of that goes to review instead of quietly becoming a number in a column."

Point at the amber note.

> "Smaller problems become notes, not alarms. This one came in under your limit for that trade. Filed, visible, not a crisis. Sorting by how much something matters is most of the work."

**Watch out for:** only Apex and Bright Hall are truly green. Every other filed row carries an amber note, usually about a missing workers' compensation line, which is correct behavior. Do not call any other row green.

**Why this scene is here:** shows judgment being deferred to a human, which is the thing that makes automation safe to hire.

*6-minute cut: keep current, lapsed and review. Drop the notes paragraph.*

---

## Scene 6: The document, one click away (4:50 - 5:20)

**Workflow label:** Source Document Route

**On screen:** the dashboard, then a PDF in a new tab.

**You do:**

1. On the **Apex Plumbing Services LLC** row, find the source link in the last column. It reads **Open PDF**.
2. Click it. The certificate opens in a new browser tab.
3. Hold on the open PDF for three full seconds before you say anything.
4. Close the tab and return to the dashboard.

**You say:**

> "Every row links back to the certificate it came from. Separate little workflow. The link hits a webhook, it looks up where the file was stored, and hands you the original."

> "Something read this and put facts in a table. Checking one against the source is a click, not a hunt through your inbox. You never have to take an automation's word for anything."

**Watch out for:** only rows with a filed certificate have a link. Grey "No certificate on file" rows do not, so click a row near the top.

**Why this scene is here:** answers the trust objection before it gets asked.

*6-minute cut: keep.*

---

## Scene 7: When nothing arrives (5:20 - 6:50)

**Workflow label:** Daily Watch and Chase → Vendor Approval Request

**Before this scene, off camera:**

1. Count the rows on your dashboard that are either grey ("No certificate on file") or red. Write that number down. That is roughly how many approval emails are about to land.
2. Open **Daily Watch and Chase** in n8n and click **Execute workflow** at the bottom of the canvas.
3. Wait for the approval emails to arrive in `sambhavn8n@gmail.com`. They arrive together, within a few seconds of each other, not one at a time — every actionable vendor gets its own request at once. Leave them unopened.
4. Decide which single vendor's email you'll click on camera, and note its subject line ("Approve certificate request: [vendor]"). You don't need to touch the others; leaving them unclicked is fine; each expires safely on its own after 24 hours.
5. Now start recording.

**On screen:** the workflow canvas, then Gmail, then pgweb.

**You do:**

1. Show the **Daily Watch and Chase** canvas. Point at **Schedule Trigger - Daily Watch 08:00** on the left.
2. Point at **OpenAI Draft Stage 6 Chase Email** in the middle.
3. Point at **Call Stage 6 Vendor Approval**, the last node on this canvas.
4. Switch to Gmail. Open the one approval email you chose in prep. Don't linger on how many others are sitting there.
5. Click **Approve** in that email.
6. Switch to pgweb at `http://localhost:8081/?session=coi-only` and open the outreach log view. Point at the one row matching the vendor you approved.

**You say:**

> "Everything so far assumed a certificate turned up. The other half of this is what happens when one doesn't."

Point at the schedule trigger.

> "This runs once a day. It sorts every vendor: never sent anything, lapsed, running out in fourteen days, thirty, sixty. The ones who've never sent anything come first, because they've got no date to remind anyone they exist."

Say the number you counted.

> "On this board it found [your number]. Most of them are vendors with nothing on file at all, plus the one whose certificate has lapsed."

Point at the drafting node.

> "For each one it drafts a short email with the vendor, the policy number and the date, and makes no claims about insurance."

Point at the handoff node.

> "Then each vendor gets handed to its own approval step, so nobody's waiting behind somebody else's decision."

Switch to Gmail, open the chosen email.

> "Here's one of them. The vendor, the reason, who it's going to, and the exact message that would go out."

Click Approve.

> "To be precise about what I just did: I approved that this one reminder gets sent. I didn't approve the vendor for anything, and I didn't touch any of the others sitting in this inbox. If nobody clicks within twenty-four hours, a request just expires instead of sending."

Show the outreach log row.

> "Your vendor can reply with the certificate attached, or use the upload link. Either way it lands back in intake, and the send is on the record. Ignore two requests and it stops chasing and hands the vendor to you, rather than emailing somebody forever."

**Watch out for:**

- Do not say "thirteen" or any fixed number. Say the number you actually counted, because it depends on how the board is staged that day.
- Your inbox will show several unread approval requests at once, not a slow trickle. That's correct. Don't apologize for it or explain the mechanics on camera — just open the one you picked in prep and ignore the rest.
- Approving one has no effect on the others. If you want proof of that rather than just claiming it, you can show a second, untouched request still sitting in the inbox after you approve the first — but that's optional and not written into the main narration.

**Why this scene is here:** the approval click is the emotional centre of the video. It is the moment a stranger's automation becomes safe to hire.

*6-minute cut: keep the schedule line, the count, the approval email, the click and the log. Drop the drafting node and the handoff line.*

---

## Scene 8: Where it lives, and who owns it (6:50 - 7:40)

**Workflow label:** none. Database and execution history.

**On screen:** pgweb, then n8n execution history.

**You do:**

1. In pgweb at `http://localhost:8081/?session=coi-only`, show the list of views on the left: vendors, certificates, coverages, outreach log.
2. Click one or two so the viewer sees real rows, not empty tables.
3. Switch to n8n and open **Overview**, then **Executions**, showing the full run history across workflows.

**You say:**

> "Worth being concrete about where this sits, because it's the difference between this and buying software."

Show the views.

> "Vendors, certificates, coverage lines, reminder history. An ordinary database, on your own server. Not my account, no shared instance, nobody else's data in it. And this is every run, with what happened and when."

Show the execution history.

> "It all exports. The workflows are files, the database takes a standard dump, the certificates are PDFs in dated folders. Handing this to another developer is a folder and an afternoon. Nothing here holds your data, because there's nothing of mine in the middle of it."

**Watch out for:** pgweb must be showing only the `coi_pgweb` views. If n8n internal tables are visible, stop and run `.\scripts\apply-pgweb-viewer.ps1`, then hard-refresh.

**Why this scene is here:** separates a build from a subscription, and answers "what if you disappear" before they have to ask.

*6-minute cut: keep the first two lines.*

---

## Scene 9: What it won't do (7:40 - 8:40)

**On screen:** the dashboard, then a code editor.

**You do:**

1. Stay on the dashboard, still, for the first paragraph.
2. Open `scripts/verify-stage-7-dashboard.ps1` in your editor and scroll to the line listing the four blocked words. Show it for two or three seconds. Do not read the code aloud.
3. Return to the dashboard for the last line.

**You say:**

> "Last thing, and it's the part I'd want to hear if I were the one watching."

> "It won't tell you a vendor is insured, and nothing that reads a certificate can. A certificate describes the day it was issued. It can't see a cancellation, it can't read an endorsement, and it can't decide who works on your property. That belongs with your agent and with you."

Show the check.

> "Four words are blocked from anything this dashboard renders. If one shows up in the page, the build fails and it doesn't ship."

Return to the dashboard.

> "And two statuses can only be set by a person: cancelled, and non-renewed. Nothing in a certificate tells you either one, so a manager sets those by hand instead of an automation pretending it found something."

**Watch out for:** have the file already open in a tab before recording. Hunting for it on camera kills the pace.

**Why this scene is here:** naming your own limits before the viewer finds them is the fastest credibility available with no track record.

*6-minute cut: keep the first paragraph and the two-statuses line.*

---

## Scene 10: Where your own paperwork stands (8:40 - 9:45)

**On screen:** the dashboard.

**You do:** nothing. Sit on the board and talk.

**You say:**

> "So: it arrives, it gets stored, it gets read, fixed rules decide, the register updates, and anything unclear waits for a person."

Short pause.

> "This isn't an enterprise risk platform and it isn't trying to be. It's the part of the job that currently lives in a spreadsheet, an inbox, and somebody's memory."

> "If you want to know where your own paperwork stands, send me ten vendor certificates. I'll run them and send you back one page: what's current, what's lapsed, what's missing, what needs a look. No access to your systems, nothing to install, no cost. If it's all in good shape, that's what the page will say."

> "Vendor documents only, nothing with resident information in it, and I delete the files when I send the page back."

**Why this scene is here:** the smallest possible first commitment. No credentials, no integration, no risk.

---

## If they ask

**"Does this tell me if a vendor is actually insured?"**
No, and nothing that reads a certificate can. A certificate is a snapshot of what was on file the day it was issued. This tracks the paperwork and the dates. Policy status belongs with the agent or the carrier.

**"What if it reads something wrong?"**
Then the row goes to review instead of getting a number typed into it. That's why the source PDF sits on every row. The reading is checkable, not final, and anything the model is unsure about goes to a person by design.

**"Is this a product I'd be buying?"**
No. It's a build. The workflows run on your server, read your mailbox, write to your database, and you own all of it when it's done. No login, no seats, no subscription. If we stopped working together it'd keep running, because there's no service of mine in the middle.

**"We already have this in our property management software."**
Most of them have a field for it, and the field isn't the problem. Keeping the field current is the problem, and that still means somebody opening PDFs and typing dates. This is the part before the field.

**"Will it email my vendors without me knowing?"**
No. Nothing goes out without you clicking approve on that specific message, and an unanswered request expires instead of sending.

**"How long does it take to set up?"**
Load your vendor list, confirm the legal names that should appear as certificate holder, connect the mailbox, then batch through the certificates you already have. The first useful thing you get is the register.

**"What happens if you disappear?"**
Everything exports. Workflow files, a database dump, and the PDFs in dated folders. Another developer can pick it up. That's a reasonable thing to want and a fair thing to ask.

---

## If something stalls

Say one of these and keep moving. Don't apologize or troubleshoot on camera.

**Gmail is slow**
> "Gmail can lag by a minute. The intake already ran and the register's updated, so let me show you that and come back to the email."

**The approval link doesn't resume**
> "That approval is a step held open in the background waiting for a click. Let me show you the pending row, and I'll pick up from a run I approved earlier."

**Model or API delay**
> "Reading the document depends on an outside API. Everything stored so far is still on the register, and the source PDFs are all here."

**Internet drops**
> "This runs locally, so the register and the documents stay up. Only new document reading and email delivery need the outside connection."

**A workflow errors on camera**
> "That's what the execution history is for. It caught it, it kept the original PDF, and nothing got filed from a failed run. Let me open the run and show you."

**An upload fails at `Write Original PDF To Storage`**

The error reads "The file or directory does not exist". This is the dated storage folder, not a real fault. Stop recording, run `.\scripts\reset-demo.ps1`, and re-stage. It takes about a second. Do not try to narrate around it, because every upload will keep failing until the folder exists.

**Gmail OAuth isn't connected at all**

Record Scenes 2 through 6 and 8 through 10 as written. They don't touch Gmail. For Scene 1, open the upload form instead of the mailbox and change the first line to "A vendor sends you their insurance certificate, or drops it on a form like this one." Then either cut Scene 7 and note in the description that the approval step is covered in a follow-up, or re-record it once OAuth is connected and edit it in. Don't fake it, and don't describe the approval gate without showing it. The click is the whole point of that scene.

---

## Language rules

Not style preferences. The honesty boundary depends on them, and the same four words are blocked in the dashboard itself.

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
- "This drafts reminder emails and waits for you."

**On the word approve.** It appears once, in Scene 7, as the verb for a human releasing an email. That use is precise and worth keeping, and the line right after it draws the distinction out loud. Never use it any other way.

**Product language to avoid:**

| Don't say | Say |
|---|---|
| my platform, my tool, my product, the app | the intake workflow, the daily watch, the build |
| users, subscribers, customers of the tool | you, the manager, whoever handles the paperwork |
| sign up, onboard onto, log in to | nothing, there's no account |
| the system does X | the intake workflow does X |

That last row slips most often under recording pressure. "The system" is how a product describes itself. A named workflow is a component someone owns.

The distinction to keep in your head: it reports what a document says. It never reports what's true.

---

## YouTube package

### Title

**Recommended:** `How vendor COI chasing gets automated inside a property management office`

72 characters, inside the roughly 70 that stay visible. Names the job, names the audience, and "gets automated" describes work being done rather than a product existing.

**Alternatives:**

- `Vendor COI tracking without a portal: a full automation walkthrough` (66)
- `I automated vendor insurance chasing. Here is every piece of it.` (63)

Avoid anything shaped like "Introducing X" or "X Demo". Both read as a launch, and nothing is being launched.

### Description

The first 100 characters stay visible before "Show more", so the first sentence has to stand alone.

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

Paste as timestamps. Recompute these against your final edit; they follow the scene slots above.

```
0:00 Nothing gets typed
0:20 This isn't a product
1:15 Read the wording
2:05 Watch one go through
3:40 Four states, and the smaller notes
4:50 The document, one click away
5:20 When nothing arrives
6:50 Where it lives, and who owns it
7:40 What it won't do
8:40 Where your own paperwork stands
```

### Hashtags

`#PropertyManagement #AIAutomation #VendorInsurance`

`#VendorCompliance` is the industry's own umbrella term and would reach further, but it sits one letter from a word this build refuses to render. The reach isn't worth looking like the thing the video spends nine minutes disowning.

---

## Pre-recording checklist

- [ ] `.\scripts\reset-demo.ps1` run **today**, so today's dated storage folder exists
- [ ] `model_id` is `gpt-5.6-luna` in `client_config`
- [ ] All five URLs return 200, especially `http://localhost:5678/form/coi-intake`
- [ ] Containers running in Docker Desktop
- [ ] All six workflows Active, including `Vendor Approval Request`; the five on-camera ones sit tidy in the list for filming
- [ ] Dashboard loads and auto-refreshes
- [ ] Seven fixtures uploaded one at a time, board checked against the table above
- [ ] Scene 1 email sent to the demo mailbox and Bright Hall Cleaning now shows a certificate
- [ ] Exactly two green rows: Apex Plumbing and Bright Hall Cleaning
- [ ] Both refusals checked off camera (`f11`, `f18`), neither changed the board
- [ ] `f02-expiring-20-days.pdf` held back for Scene 4
- [ ] Grey rows plus red rows counted, so Scene 7 says the right number
- [ ] Daily Watch and Chase executed off camera; approval emails waiting, and you've picked which one you'll click on camera
- [ ] Gmail OAuth connected for `sambhavn8n@gmail.com`, or the fallback plan chosen
- [ ] n8n Gmail credential named exactly `Gmail account`
- [ ] `stage_6_approver_email` and `stage_6_test_recipient_email` both set to the demo mailbox
- [ ] pgweb showing only `coi_pgweb` views
- [ ] Workflow label overlay prepared for all five on-camera names
- [ ] No day counts spoken in narration
- [ ] "Synthetic test data" label ready for the first ten seconds
- [ ] Every scene read aloud once
- [ ] Notifications silenced, unrelated tabs closed

---

## Research notes

Office-workflow and insurance context reflects:

- Buildium's vendor insurance tracking guidance: https://help.buildium.com/hc/s/article/Tracking-Vendor-Insurance-1557495330433
- RealPage's vendor credentialing overview: https://www.realpage.com/vendor-credentialing/
- Atlas Global Advisors' vendor onboarding checklist: https://atlasglobaladvisors.com/blog/vendor-onboarding-checklist-for-property-managers/
- OxMaint's property maintenance vendor management guide: https://oxmaint.com/industries/property-management/vendor-management-property-maintenance-guide
- NY DFS certificate filing, which states the certificate is informational and does not change the policy: https://www.dfs.ny.gov/apps-and-licensing/insurance-companies/certificates-approved/acord-25-2025-12-liability
- Texas Department of Insurance certificate FAQ, on additional-insured and cancellation-notice wording: https://www.tdi.texas.gov/certificates/faq.html

Behavior described in the scenes traces to `docs/how-the-system-works.md`, `scripts/lib/coi-stage-4-validator.js`, and the workflow exports in `n8n-workflows/`. Board states and the Scene 7 count were verified against a live staged run on 2026-08-05.
