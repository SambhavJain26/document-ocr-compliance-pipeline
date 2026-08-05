# How The System Works

A plain-language explanation of what this system actually does, end to end, and which workflow is responsible for each part of it. Written for understanding the behaviour, not for editing the code.

Every section below names the workflow doing the work, and where it helps, the specific node. If you are ever looking at the dashboard wondering "what put that there", the answer is in here.

The document runs in three parts. First, the problem it was built for. Then how the built system behaves, piece by piece. Then what putting it inside a working property management office actually involves.

## The Problem This Solves

### What actually happens in the office

A property management company at 150 to 600 doors works with somewhere between twelve and forty regular vendors. Plumbers, electricians, HVAC techs, landscapers, painters, roofers, pest control, cleaners, a handyman, someone for snow. Every one of them is supposed to carry liability insurance before they set foot on a managed property, and every one of them proves it the same way: by sending a certificate of insurance, almost always a one-page standard form.

Someone at the office receives that certificate. They save it somewhere. If the office is organised, they type the expiration date into a spreadsheet column. Then they move on, because there are eleven other things happening that morning.

Then the policy expires.

Different vendors renew on different dates with different carriers. The plumber's general liability runs to March, the roofer's to August, the landscaper switched carriers last year and nobody wrote that down. Nobody is watching the calendar, because watching the calendar is not anybody's job. The spreadsheet was last updated whenever the last person who cared about it stopped caring, or left.

### Why it stays broken

This is the kind of task that is never urgent until it is catastrophic. There is no daily pressure to update the insurance tab. No tenant calls about it. No owner emails about it. It fails silently, and the failure only becomes visible at the exact moment it matters most, which is the moment you are least able to do anything about it.

It is also genuinely tedious in a way that resists delegation. Chasing a plumber for an updated certificate means emailing him, waiting, emailing his insurance agent, waiting, receiving a PDF, opening it, reading four date fields, and typing them somewhere. That is maybe four minutes of work. Multiply by twenty-five vendors, once a year, on twenty-five different dates that nobody is tracking, plus the second and third follow-ups for the ones who do not reply. The cost is real, but it is spread so thinly across the year that it never appears on anyone's list as a task worth solving.

There is a second reason it stays broken, and it is worth naming because it shaped the design. Property managers are not insurance professionals. Asked to look at a certificate and say whether it is acceptable, most would rather not commit to an answer, and there is no comfortable way to ask. So the safe move is to file it and move on, which is exactly the behaviour that lets a lapse go unnoticed.

### What the software they already own does, and does not do

This matters, because it is the first objection anyone raises.

Property management platforms do let you record vendor insurance details, and some will warn a manager at work-order assignment if the recorded insurance has expired. That is a real feature and it is worth having.

What they do not do:

- read a certificate PDF and pull the dates out of it
- notice that an expiration is approaching
- email the vendor or their agent to request a renewal
- follow up when that email is ignored
- show you, in one view, which vendors currently have nothing on file

The warning at assignment is a last line of defence, not a system. It depends entirely on someone having typed the date in correctly in the first place, and it fires at the worst possible moment, when a job is urgent and a human is under pressure to click past it. The field is not the problem. Keeping the field current is the problem, and that still means somebody opening PDFs and typing dates.

### The two ways this shows up

The dramatic version is the one everybody imagines. An uninsured vendor causes damage, the carrier denies the claim because no coverage was in force on the date of loss, and the management company is left explaining to an owner why nobody checked. It is real, and it is rare.

The common version is quieter, and it is the one this system was actually built for. During an owner review someone asks a simple question: which of our vendors are current right now? Nobody can answer it without spending an afternoon opening files. When somebody finally does, seven of eighteen certificates turn out to have lapsed months ago and two vendors have changed carriers entirely. Nothing bad happened. But the honest answer to "how did we not know this?" is that there was never a system, just a spreadsheet and the hope that someone would remember.

### What kind of problem this actually is

Worth being precise here, because it determines what the system does and does not attempt.

This is an attention problem, not a judgement problem. The hard part is not deciding whether a certificate is good. The hard part is noticing, on the right day, that a document nobody has looked at in eleven months is about to stop being current, and then doing something about it before it does.

That distinction is the whole design. The system is built to notice things on time and to do the typing. It is not built to form opinions about insurance, and the sections below are unusually strict about that line, because the moment a tool starts telling a property manager that a vendor is fine, it has become something nobody at this price should be selling and nobody at this scale should be trusting.

## The One-Paragraph Version

Vendor insurance certificates arrive as PDFs. The system saves each one, reads the facts printed on it, checks those facts against what you require, and files the result against the right vendor. It keeps a register showing which vendors have current paperwork and which do not. Every day it looks for paperwork that is missing, expiring, or expired, writes a reminder email for each one, and holds that email until a person approves it. Nothing is sent without that approval.

The distinction that governs the whole design: it reports what a document says. It never reports what is true.

Everything that follows is an elaboration of that sentence. Where a design decision looks strange, it is almost always because it was made to protect that line.

## The Five Workflows

Everything the system does is one of these five. Nothing runs outside them.

| Workflow, as named in n8n | What it owns | What starts it |
|---|---|---|
| **COI Intake** | Everything that happens to an arriving certificate: storing the original, reading it, checking it, filing the result | `Gmail Trigger - COI Intake`, `Form Trigger - Certificate Upload`, or `Manual Trigger - Run Stage 5 Smoke` |
| **Source Document Route** | Handing the original PDF back when someone clicks the link on a dashboard row | `Webhook - Source PDF` |
| **Daily Watch and Chase** | Finding paperwork that is missing or running out, drafting the reminder, holding it for a person, sending it, logging it, and escalating when a vendor ignores you | `Schedule Trigger - Daily Watch 08:00`, or `Manual Trigger - Run Stage 6 Watch` |
| **Non-PDF Reply Notice** | Vendor replies that are not certificates, so a plain text answer or a portal link becomes a manager notice instead of nothing | `Gmail Trigger - Stage 6 Replies` |
| **COI Dashboard** | Turning the current state of the database into the register web page | `Webhook - COI Dashboard` |

Two of these are event-driven and the important one is not, which is worth understanding because it explains why both exist. The intake workflow reacts to something happening: a document arrived. The daily watch reacts to nothing happening, which is a thing no inbox trigger can ever detect. An email trigger fires on arrivals. It has no way to notice an absence, and absence is the actual failure mode this product exists to catch.

**A sixth export exists and does not run.** `Extraction and Validation Core` is the harness the checking rules were built and tested in. The rules themselves live in `scripts/lib/coi-stage-4-validator.js` and are copied into the intake workflow by a generator script, which is why the checks behave identically wherever they run. If you ever need to change a rule, you change that file and regenerate. You do not edit the workflow.

Each workflow is named for what it does. The underlying workflow IDs still carry build-stage names (`stage-5-intake-workflow` and so on), which is why scripts and CLI commands refer to those rather than to the display names. The display names can be changed to match an office's own vocabulary without touching behaviour: they are set in the `scripts/generate-stage-*` generators, and changing one is a regenerate and a re-import.

Every node inside these workflows still carries a stage label in its name, for example `Load Stage 6 Actionable Vendors`. That is deliberate. Several code nodes and expressions reference other nodes by exact name, so node names are load-bearing in a way workflow names are not.

## The Parts Underneath

Distinct from the five workflows above. These are the components the workflows use.

**n8n** runs the workflows and keeps the record of what happened. Its execution history is the audit trail: every run, what it did, when, and which node failed if one did. This matters more than it sounds. When something looks wrong, the question is never "did the system do something odd" but "which run, and at which step", and that is answerable from the history without anyone guessing.

**Postgres** is the memory, and more of the logic than you might expect. Vendors, certificates, coverage lines, reminder history and your settings live here, but so do several functions that make real decisions. See "What Lives In Postgres Rather Than n8n" below. This is the actual asset. Everything else is machinery for keeping it accurate.

**The AI model** does one narrow job: read a certificate and return the facts printed on it. It is instructed to transcribe rather than interpret, and to return nothing rather than guess. It makes no decisions about whether a certificate is acceptable. It is called in exactly three places: `OpenAI Extract Stage 5 Text`, `OpenAI Extract Stage 5 PDF File`, and `OpenAI Draft Stage 6 Chase Email`. Two of those read documents. The third writes a reminder email that a human then reads before it goes anywhere.

**Gmail** is both doors. Certificates come in through it, and approved reminders go out through it, from the office's own mailbox rather than from anything belonging to the system.

**Disk storage** holds every original PDF under a dated folder, `/home/node/.n8n-files/certificates/YYYY/MM/DD/`, mounted from `./data/certificates`. The dated structure is deliberate: it makes the folder browsable by a human without needing the database, and it makes backup boundaries obvious.

**The dashboard** is a web page rendered on request by a workflow. It has no accounts, no sessions, and stores nothing of its own. Closing it loses nothing, because there is nothing in it that is not already in Postgres.

## The Journey Of One Certificate

**Workflow: COI Intake.** All of it. Six steps, in order, with the nodes that do them.

**1. It arrives.** Three ways in, and each has its own short entry path that normalizes the document and loads your settings:

- Gmail: `Gmail Trigger - COI Intake` then `Mark Gmail Intake Source`, `Normalize Gmail Intake Items`, `Load Stage 5 Gmail Context`, `Attach Context To Gmail Items`
- The upload form: `Form Trigger - Certificate Upload` then the matching four form nodes
- A manual test run: `Manual Trigger - Run Stage 5 Smoke` then `Load Stage 5 Manual Context`, `Build Manual Smoke Items`

All three converge at `Route Intake Item Type`, so behaviour is identical from that point regardless of how a document came in. This is why a certificate uploaded through the form is not a lesser citizen than one that arrived by email: past the second step, there is no difference between them.

The Gmail trigger polls every minute and filters on unread messages carrying an attachment. It does not filter by sender or by label, so anything with an attachment landing in that mailbox is a candidate.

An email with two PDFs becomes two independent certificates handled separately. They do not share a fate: one can file cleanly while the other goes to review.

`Route Intake Item Type` is also the first refusal. Anything that is not a PDF goes to `Build Direct Intake Notice Payload` and becomes a manager notice rather than a certificate.

**2. It gets saved first.** `Prepare Stored PDF Metadata` works out the dated path, `Write Original PDF To Storage` writes the file, and `Reattach PDF Context After Storage` puts the record back together, because the file node drops everything else.

This ordering is deliberate, and it is the most defensive decision in the system. The original is on disk before anything tries to interpret it. If the model call fails, if the checking code throws, if the database is unreachable, the document still exists and is still findable. The alternative ordering, read first and store on success, loses documents on exactly the days you can least afford to lose them.

**3. It gets read.** `Route Password Protected PDF` runs first, because a locked file would otherwise break extraction and take the whole run with it. Locked files skip straight to `Mark Password Protected Review Result`.

Everything else goes to `Extract Text From Stored PDF`, then `Route By Extracted Text Length` decides which way to read it:

- Enough text: `Mark Text Extraction Method` then `OpenAI Extract Stage 5 Text`
- Too little, meaning a scan or a photo: `Mark Vision Extraction Method` then `OpenAI Extract Stage 5 PDF File`, which sends the PDF itself to be read visually

The second branch is what handles a certificate somebody photographed on a phone and saved as a PDF. There is no text layer in a photograph, so extraction returns almost nothing and the document is handed to the model as an image to read rather than as text. A skewed or glare-marked photo will usually still be read, but it is also the case most likely to come back with low confidence, which routes it to a person instead of filing it. That is the intended outcome, not a failure.

Either way the output is the same shape: vendor, carrier, policy number, coverage lines, limits, effective and expiration dates, certificate holder, and the model's own confidence rating of HIGH, MEDIUM, or LOW.

**4. It gets checked.** `Normalize Validate Stage 5 Result`. This is the part that is not AI. A fixed set of rules, the same every time with no judgment involved, compares the extracted facts against your requirements. Are the dates in a sensible order? Is the expiration plausible? Is there a general liability line? Does the certificate holder match one of your accepted legal names? Do the limits meet your minimum for that trade? Is this vendor suspiciously similar to one already on file? Each problem found becomes a flag with a severity.

All three branches converge here: the password-protected branch, the text branch, and the vision branch. However a document was read, it is judged by the same code.

**5. It gets filed.** `Store Stage 5 Intake Result`. The flags decide what happens, described below.

**6. The register updates.** Nothing pushes. The next time anyone loads the dashboard, Stage 7 reads the current state, and the page auto-refreshes every five seconds. There is no cache to invalidate and no sync step that can fall behind, because the dashboard has no state of its own to fall behind with.

## Why The Reading And The Checking Are Separate

The most important design decision in the system, and it is visible in the node list.

`OpenAI Extract Stage 5 Text` reads. `Normalize Validate Stage 5 Result` decides. The model is never asked whether a certificate is good enough, only what the document says. Everything consequential is decided by fixed logic that behaves identically every single time.

The reason is about what kind of error you can catch. A model that reads a date wrong produces a claim you can check, because the source document is one click away on the same row and the wrong value is sitting next to it. A model that decides something wrong produces a judgement with no visible working, and there is nothing on the screen to compare it against. The first kind of error is embarrassing and fixable. The second kind is invisible and compounds.

There is a second benefit: the rules do not drift. A model asked the same question twice can answer differently. The checking code cannot. When a vendor asks why their certificate was flagged, the answer is a specific rule with a specific threshold, and it will be the same answer next month.

This is also why the model's own confidence rating is treated as an input to the rules rather than as a decision. The model saying it is unsure is useful information. It is not permission to file something anyway.

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

Two of these deserve a note, because they exist to prevent a specific silent failure.

`OLDER_THAN_ON_FILE` catches a vendor re-sending last year's certificate, which happens more than you would expect, usually because someone forwarded the wrong file from their own folder. Without this check, a naive save would quietly replace good current data with stale data, and the register would get worse while appearing to get updated.

`POSSIBLE_DUPLICATE_VENDOR` exists because automatic name matching is where this kind of system does its worst damage. "Mercer Plumbing" and "Mercer Plumbing & Heating" may be two different companies. Merging them files one company's certificate against the other's record, and nothing on the screen would ever reveal it. On a near-match, the system asks rather than guesses.

**Soft. The certificate is filed, with a visible amber note.**

| Flag | Plain meaning |
|---|---|
| `HOLDER_MISMATCH` | The certificate holder is not one of your accepted legal names |
| `LIMIT_BELOW_MINIMUM` | A limit is under your requirement for that trade |
| `NO_GL_LINE` | No general liability coverage line is present |
| `NO_WC_LINE` | No workers' compensation line is present, suppressed for vendors marked exempt |
| `COVERAGE_GAP` | A renewal starts later than the previous policy ended, leaving a gap. This one compares the new certificate against the one it replaces rather than reading it alone |

Soft flags are filed rather than blocked because they describe a document that is real and readable but does not match what you asked for. That is a conversation with the vendor or their agent, not a reason to withhold the information from your own register.

`COVERAGE_GAP` is the one worth understanding properly, because it catches something a spreadsheet structurally cannot. The old policy ends on the first of March; the replacement certificate is effective the fifteenth. Both documents are perfectly valid. Between them is a fortnight during which that vendor was working on your properties with nothing in force, and once the new certificate is filed the register turns green and the gap disappears from view forever. The check compares the incoming certificate against the one it supersedes and records the day count.

`NO_WC_LINE` is suppressed for vendors marked exempt because sole proprietors are exempt from workers' compensation in many states and carry an exemption document rather than a policy. Without the suppression, the system would confidently flag legitimate vendors as deficient, and confident wrong alerts destroy trust in an automated system faster than anything else it can do.

**Note. Recorded as neutral information only.**

| Flag | Plain meaning |
|---|---|
| `NO_CANCELLATION_NOTICE_WORDING` | A high-risk trade's certificate does not mention notice of cancellation |

This one is deliberately not a problem. It is an observation a manager may want to raise with their broker at contract renewal, recorded because it is useful and left neutral because the presence or absence of that sentence on a form does not determine what a carrier will actually do.

The rule underneath all of this: a hard flag can never quietly become a filed, current certificate. If something is wrong, a person sees it.

## How A Certificate Gets Filed

**Node: `Store Stage 5 Intake Result`.** Four outcomes:

- **Filed as current.** Clean, or carrying only soft and note flags. It becomes the vendor's active paperwork and the dashboard row updates to reflect its dates.
- **Sent to review.** Any hard flag. It is stored and visible, but it does not count as current paperwork, which means the vendor stays actionable for chasing rather than appearing settled.
- **Superseded.** A newer certificate arrived for a vendor who already had one. The old record is kept as history rather than deleted, so there is an audit trail of what was on file and when.
- **No record at all.** The document was not a certificate. The manager gets a notice and no vendor record is invented.

Two properties fall out of this that are worth stating plainly. Uploading an older certificate over a newer one does not regress the register. The same document arriving twice does not create two rows. Both matter because real inboxes are messy: people forward things, reply-all to old threads, and send the same attachment from two different addresses.

Two statuses can only ever be set by a human: **cancelled** and **non-renewed**. No workflow sets these. The system cannot detect either from a certificate, because a certificate describes the day it was issued and says nothing about what happened afterwards, so a manager sets them manually with a note and their name attached. The vendor then becomes actionable without the system pretending it discovered something it could not have discovered.

## The Source Document Link

**Workflow: Source Document Route.** Six nodes, and the smallest thing here that matters most.

Every dashboard row carries a link to the certificate it came from. Clicking it hits `Webhook - Source PDF`, which passes the certificate id to `Load Certificate Source Path`. `Route Safe Stored PDF` checks the stored path is inside the allowed area before anything is read, then `Read Stored Source PDF` and `Respond With Stored PDF` hand the original back. If the file is missing or the path fails the check, `Respond Source PDF Not Found` answers instead of erroring.

Locally the route is reached as `/webhook/stage-5-source-document-webhook/coi-source/<certificate_id>`.

This is what makes the extraction checkable rather than final, and it is the answer to the only question that really matters when a stranger's software puts numbers on your screen: how do I know that is right. You do not have to take the system's word for a date. The document that produced it is one click away, on the same row, without searching an inbox or a shared drive.

It is also the reason the storage step runs before the reading step. The link is only trustworthy if the file is guaranteed to be there.

## What Happens When Nothing Arrives

**Workflow: Daily Watch and Chase.** The other half of the system, and the half that addresses the actual problem. Everything above assumes a document turned up. This part assumes it did not.

`Schedule Trigger - Daily Watch 08:00` starts it once a day. The first thing that runs is `Escalate Stage 6 Overdue Outreach`, a pre-pass that deals with vendors who have already ignored enough requests, before any new chasing is considered. Handling escalations first means a vendor who has stopped responding is taken out of the automated loop before the system considers sending them anything else.

Then `Load Stage 6 Actionable Vendors` does the sorting. For each vendor it takes the earliest-expiring active coverage and puts them in a bucket, in this order:

1. **Never received.** This vendor has no certificate at all
2. **Expired.** Past the printed date
3. **14 days.** Expiring within two weeks
4. **30 days**
5. **60 days**
6. **Re-attestation.** Nothing wrong, but it has been 90 days since the vendor last confirmed their details
7. **None.** Nothing to do

Two details in that ordering are deliberate.

Vendors with no certificate come first because they are the ones most easily forgotten. Every other bucket is triggered by a date, and a date is a reminder in itself. A vendor who never sent anything has no date attached, which means nothing will ever prompt anyone to think about them. They are simultaneously the highest exposure and the lowest visibility, and putting them at the top of the list is the cheapest correction available.

The bucket is chosen from the **earliest** expiring coverage line, not the general liability line and not the latest one. A vendor whose auto liability lapses in September and whose general liability runs to December is chased in September, because the exposure starts at the first gap.

The cadence is a setting rather than a hardcoded rule. Currently reminders at 60, 30, 14 and 0 days out, and re-attestation every 90 days. The industry convention quoted most often is 60, 30 and 7, so this schedule is deliberately different and worth explaining if anyone asks: the extra fourteen-day touch exists because the response rate on a first request is not high, and the day-zero reminder exists because "expired today" is a different conversation from "expiring soon".

Chasing is skipped when a vendor is paused, when a reminder is already awaiting approval, or when a recent reminder has not yet come due for follow-up. The system does not pile on. It also does not restart its counting when a vendor crosses a bucket boundary: the same expiry is treated as one continuous issue whether it is sixty days out or thirty, which is why a vendor does not receive a fresh first request every time a threshold is passed.

Re-attestation measures against `last_attested_at` on the vendor record. Filing a certificate counts as an attestation: when `Store Stage 5 Intake Result` files a document as current, it records that date against the vendor, so the 90-day clock restarts every time a vendor sends current paperwork.

The date recorded is the certificate's own date rather than the day it arrived, and it only ever moves forward. That means uploading a certificate that is still current but was issued eight months ago does **not** reset the clock to today, and the vendor will correctly appear for re-attestation. That is the intended reading: the vendor last confirmed anything eight months ago.

A vendor who replies to a re-attestation request in words rather than with a document is a different case. That reply becomes a manager notice through Non-PDF Reply Notice, and a person sets `last_attested_at` by hand, in the same way manual `CANCELLED` and `NON_RENEWED` statuses are set. Nothing infers an attestation from an email body.

## The Chase, And The Approval Gate

**Workflow: Daily Watch and Chase**, continuing from above. This is the longest path in the system, so here it is node by node.

`OpenAI Draft Stage 6 Chase Email` writes a short email, under 120 words, naming the vendor, the policy number and the expiry date, requesting updated paperwork, and making no claims about coverage. Where a producer or agent is on file, the request is addressed to them rather than to the vendor, because the agent is the party who can actually produce the document.

The draft is checked before it is used. If it comes back empty, over the word limit, or containing any of the four forbidden words, it is discarded and a fixed template is used instead. There are three templates: one for a vendor with nothing on file, one for a re-attestation check-in, and one for everything date-driven. A model failure therefore degrades to a plain, correct email rather than to no email or a wrong one.

`Prepare Stage 6 Draft Payload` then builds the version that will actually be sent. It appends the vendor-facing link as an anchor reading "certificate upload link", after the word-count and forbidden-word checks have run, so the model cannot invent a destination and the boilerplate does not count against the 120 words.

`Record Pending Outreach` writes the pending row before anything is sent, so a reminder can never go out without a record of it existing. The order matters for the same reason the PDF is stored before it is read: if the send fails halfway, the evidence that it was attempted survives.

`Prepare Approval Email Payload` and `Route Email Approval Configured` then check that an approver address is actually set. If it is not, the run goes to `Store Stage 6 Config Notice` instead of emailing anyone. This is a deliberate refusal rather than a fallback. A misconfigured system that sends vendor email to nobody in particular is worse than one that stops and says so.

`Gmail Approval - Send and Wait` sends the approval request to the manager and then holds the execution open. The manager sees the vendor, the reason, the intended recipient and the exact draft, with two buttons. The approval email shows the raw upload URL on its own line, because the approver is reviewing what is about to be sent and needs to see the destination. Only the vendor-facing email hides it behind anchor text.

Then `Recover Approval Result Context` and `Route Approved Stage 6 Email` decide what happens next:

- **Approved.** `Gmail Send Approved Stage 6 Chase` sends from the office's own mailbox, then `Build Sent Outreach Log Payload` and `Mark Outreach Sent` record the send time, recipient, message body and follow-up date.
- **Declined.** `Build Declined Outreach Log Payload` and `Mark Outreach Declined` log it and nothing is sent.
- **No response in 24 hours.** The request expires rather than sending. This is the default, not a setting someone has to remember.

That last behaviour is the one to understand. The failure mode of an approval gate is a manager on holiday and a queue of messages that eventually go out unattended. Here, silence means nothing happens. The vendor will be picked up again on a later run and a person will get another chance to decide, but no message ever leaves because somebody stopped paying attention.

It is worth being precise about what the approval means, because the word does a lot of work in this system and only one of its meanings is correct. Clicking approve releases one specific email. It is not a statement about the vendor, their insurance, or their suitability for work.

If a follow-up comes due and no newer certificate has arrived, a second request goes out. After two ignored requests, the `Escalate Stage 6 Overdue Outreach` pre-pass on a later day escalates to the manager and pauses automated chasing for that vendor. It will not email a vendor indefinitely. At that point the problem has stopped being administrative and has become a relationship question, which belongs with a person.

**One setting to know about.** `stage_6_outbound_test_mode` defaults to true, which redirects approved sends to a test address rather than the real producer or vendor. That is correct during setup and must be switched off deliberately before any real use.

## Replies That Are Not Certificates

**Workflow: Non-PDF Reply Notice.** Three nodes, and easy to forget it exists.

`Gmail Trigger - Stage 6 Replies` watches for vendor replies. `Normalize Stage 6 Reply Notice` and `Store Stage 6 Reply Notice` turn anything that is not a certificate, a plain text answer or a link to an insurance portal, into a manager notice rather than letting it disappear.

This exists because the most common real reply to a certificate request is not a certificate. It is "my agent will send it Monday", or a link to a carrier portal, or a question. Without this workflow those replies would sit unread in a mailbox nobody is watching, and the vendor would be chased again a week later as though they had ignored the request, which is the fastest way to sour a working relationship with a tradesperson you depend on.

A reply that does carry a PDF is picked up by the intake workflow instead, through its own Gmail trigger, and goes through the normal journey.

**Worth knowing:** vendor replies are never linked back to the outreach row that prompted them. Matching runs on the vendor name extracted from the certificate. Chasing stops because a newer filed certificate makes the vendor non-actionable, not because the system detected a reply. The outcome is right. The mechanism is not reply detection, and the distinction matters if you are ever working out why a chase did or did not stop.

## The Dashboard

**Workflow: COI Dashboard.** Five nodes and no storage of its own.

`Webhook - COI Dashboard` receives the request. `Load Stage 7 Dashboard Rows` pulls the current state from Postgres. `Build Stage 7 Dashboard HTML` renders the page. `Respond With Stage 7 Dashboard` returns it. That is the whole workflow. There is a second webhook node for a stable URL, feeding the same three nodes.

One row per vendor: name, trade, carrier, policy number, general liability limit, expiration date, status, chase, and a link to the source document. One row per vendor rather than one per certificate, because the question the page answers is "where does this vendor stand today", not "what documents do we hold".

The chase column answers "has anyone asked for this yet, and when": `Not yet chased`, `Chased 3 days ago (2 requests), follow-up Aug 12`, `follow-up overdue`, or `Chasing paused` once a vendor has ignored enough requests to be handed back to a person. Without it, the page showed the paperwork half of the product and hid the chasing half entirely, which made a large part of the work invisible.

Status is always phrased as a date fact:

- Current until *(date)*
- Expires in *(n)* days
- Expired *(n)* days ago
- No certificate on file
- Needs review

Read those again and notice what none of them say. Not one is a conclusion about insurance. Every one is a statement about a document and a date, which is the only kind of statement this system is entitled to make.

Soft flags appear as small amber notes under the vendor name rather than as alarms, because a limit below your minimum is a conversation, not a crisis. Header counts update as documents are processed. Rows with no certificate sort near the top, matching the chase priority.

The words *compliant*, *verified*, *covered* and *approved* are forbidden anywhere in this page. `Build Stage 7 Dashboard HTML` throws rather than render one, and `scripts/verify-stage-7-dashboard.ps1` fails the build if any appear. This is enforced twice rather than merely intended, because a rule that lives only in someone's memory is a rule that survives until the first busy week.

## What Lives In Postgres Rather Than n8n

Worth knowing, because reading the workflows alone will not show you where several decisions are made. The n8n nodes call these.

| Function | What it decides | Called by |
|---|---|---|
| `stage_6_actionable_vendors` | Which vendors need chasing, which bucket each falls into, and all the suppression rules | `Load Stage 6 Actionable Vendors` |
| `stage_6_vendor_issue_key` | What counts as "the same problem I already asked about". Deliberately excludes the bucket, so a vendor's expiry is one continuous issue across boundaries | Used inside the function above |
| `stage_6_escalate_overdue` | The two-strike rule, `HAVING count(*) >= 2` | `Escalate Stage 6 Overdue Outreach` |
| `stage_7_dashboard_rows` | Every value the dashboard renders, including the chase summary aggregated from `outreach_log` | `Load Stage 7 Dashboard Rows` |

The reason this logic sits in the database rather than in workflow nodes is that it is set logic over the whole vendor register, not per-item processing. Asking "which of these eighteen vendors needs attention today, excluding the ones already awaiting approval or recently contacted" is one query. Expressed as workflow nodes it would be several loops and a great deal of state, and it would be much harder to verify.

If chasing behaves in a way the workflow diagram does not explain, the answer is almost always in `db/postgres/004-stage-6-watch-chase.sql`.

## Where Everything Lives

- **Vendor register, certificates, coverage lines, reminder history and settings.** The Postgres database
- **Original PDFs.** A dated folder on disk, one folder per day, linked from every row through Source Document Route
- **Your requirements.** Minimum limits per trade, accepted certificate holder legal names, reminder cadence, approver address and which AI model to use are all settings in the database, not values buried in the workflows
- **What ran and when.** n8n's execution history
- **API keys and mailbox access.** Stored inside n8n only, never in the project files

The third point matters commercially: requirements living in a settings table means changing a coverage minimum is a database update, not a developer task. And every one of these five is a file or a database that can be copied, which is what makes the system portable rather than something you are tied to.

## What It Deliberately Refuses To Do

These are not gaps. They are the design.

It does not say a vendor is insured, compliant, verified or approved. It does not decide whether a vendor may work on a property. It does not guess at an unclear document, it asks a person. It does not send a vendor email without human approval. It does not interpret the additional-insured or subrogation checkboxes, recording only whether a mark is present, which is why those fields are named "asserted". It does not turn cancellation-notice wording into a promise that notice will be given.

The naming convention is doing real work there. A column called `additional_insured` invites everyone who reads it later, including the person who built it, to treat it as a fact. A column called `addl_insd_asserted` says what it actually is: a checkbox somebody ticked on a form. Encoding the honesty into the data model costs nothing and prevents the slow drift into overclaiming that would otherwise happen eighteen months from now, when everyone has forgotten why the distinction mattered.

## What It Genuinely Cannot Do

Worth being blunt about, because these are the limits of certificates themselves, not of the build:

- It cannot confirm a policy is active with the carrier. A certificate is a snapshot of the day it was issued.
- It cannot detect mid-term cancellation. Nothing in a certificate reveals that.
- It cannot verify additional-insured status or interpret endorsements. That requires the policy, not the certificate.
- It cannot spot a forged certificate.
- It cannot know about a vendor nobody entered into the register.
- It does not write back to property management software.
- It does not process certificate images sent as JPG or PNG. Intake filters to PDFs, so those become `NON_PDF_ATTACHMENT` notices.

The first three are not implementation shortcomings, and no amount of additional work would remove them. A certificate of insurance is an informational document. It describes what was on file the day it was issued and confers nothing by itself. Products that do address mid-term policy status manage it by connecting to the insurance agent's own systems, which is a different kind of company with a different kind of moat, and it is worth saying so plainly rather than implying this system does something it does not.

The one mitigation available is the re-attestation cadence, and it is honest about what it is. Asking every ninety days whether anything has changed does not monitor a policy. It just asks more often, which takes a twelve-month blind window down to about three. That is a real improvement and it is not monitoring, and those two statements have to be made together.

Anything in this list belongs with the agent, broker, carrier or legal advisor.

## Resetting

`reset-demo.ps1` returns everything to the opening state: 18 vendors, no certificates, no coverage rows, no notices, no reminder history, and no vendors left paused from earlier testing. Settings, credentials and email configuration survive. It takes about a second and is safe to run repeatedly.

The paused-vendor clearing in that list was added after 17 of 18 vendors were found silently carrying a pause flag from earlier escalation testing, which would have made the daily watch find almost nothing to do. Nothing on screen revealed it until the dashboard gained a chase column. It is a good illustration of this system's characteristic failure mode: not an error, just a quiet absence of activity that looks exactly like everything being fine.

## When Something Looks Wrong

Each symptom, and which workflow to open first.

- **A row shows "Needs review" unexpectedly.** Open the source PDF from the row. The document usually explains it: an inverted date, a holder name that does not match, an unusually poor scan. If you want the detail, the run is in COI Intake executions.
- **A certificate arrived but no row changed.** Check it was a PDF, then check COI Intake executions for that time. A clean run that creates no certificate is the correct result for a non-certificate document.
- **A Gmail certificate was missed entirely.** The intake trigger filters on unread with an attachment, polling every minute. A reply opened in Gmail before the trigger polls can be skipped, because it is no longer unread.
- **A certificate photo was ignored.** If it was sent as a JPG or PNG rather than a PDF, intake filtered it out and created a notice. A photograph saved as a PDF is handled, through the vision branch.
- **No reminder email appeared.** Confirm Daily Watch and Chase is published and active, and confirm the approver address is set. An inactive workflow has been the cause before, and an unset approver sends the run to `Store Stage 6 Config Notice` instead.
- **More reminders queued than expected.** Check `last_attested_at` on the vendors involved. A vendor with no recorded attestation date is re-attest actionable even with good paperwork on file, which is correct for a vendor imported at onboarding who has not sent anything since, and wrong if their certificate was filed by this system. Filing a certificate records the date automatically.
- **A vendor is never chased.** Check `chase_paused` for that vendor. Earlier escalation testing has left every vendor but one paused before now, and it is invisible outside the dashboard chase column.
- **A reminder was approved but the vendor never received it.** Check `stage_6_outbound_test_mode`. While it is true, approved sends are redirected to the test address.
- **A source PDF link returns not found.** Source Document Route answered with `Respond Source PDF Not Found`. The stored path is either missing or outside the allowed area.
- **The dashboard will not load after a restart.** n8n registers its web routes a little after the editor comes up. Wait, then retry.
- **The database browser shows unfamiliar internal tables.** Run `apply-pgweb-viewer.ps1` and hard-refresh.

## Putting This Into Your Business

Everything above describes a working system. This section describes what it takes to have it running against your vendors, in your office, and what changes for the people who work there.

### What does not change

This is the short list, and it is the important one.

**Nobody signs up for anything.** There is no account for your staff to create, no seats to buy, no password for anyone to lose. The register is a web page inside your own deployment.

**Your vendors are not asked to adopt anything.** They do not register for a portal, they do not learn a system, and they do not receive a link to somewhere they have to create a login. They reply to an email with a PDF attached, exactly as they do now. This is the largest practical difference between this and the products in the category, and it matters because vendor cooperation is where those products fail: a plumber who finds your compliance portal cumbersome does not complain, he just stops responding, and you lose both the paperwork and some goodwill.

**Your property management software is not touched.** No credentials, no integration, no write-back, no plan upgrade. The system has no ability to alter anything in your system of record, which is not a policy choice but a structural one. If your platform gates its API behind a higher tier, that is irrelevant here.

**Your mailbox stays your mailbox.** Certificates arrive where they already arrive. Reminders go out from your own address, so a vendor sees a message from the company they already work with, not from a third party they have never heard of.

**Nobody's judgement is removed.** Every outbound message waits for a person. Every unclear document waits for a person. The typing goes away; the deciding does not.

### What you already have that it uses

Almost everything it needs, you already own:

| What it needs | What that means in practice |
|---|---|
| A mailbox | Your existing Gmail or Google Workspace account, or a dedicated address such as `coi@` if you prefer the traffic separated |
| A vendor list | Names, trades, and contact emails. A spreadsheet or a CSV export from your property management software is fine |
| The certificates you already hold | Whatever is in the shared drive or the inbox today, however disorganised |
| Your legal names | The management company, plus any owner LLCs that appear as certificate holder |
| Your requirements | The coverage minimums you already ask vendors for, per trade if they differ |
| Somewhere to run it | A small server, see below |

Nothing on that list is a purchase, with the exception of the server, which is a modest monthly cost and can sit in your own cloud account.

### What gets set up, and by whom

The configuration work is mostly a conversation rather than a project. It falls into five pieces.

**The vendor register.** Your list gets imported. Each vendor needs a legal name, a trade, and ideally a contact email and their insurance agent's email. This is the step where near-duplicates get resolved and any vendors who should never be chased get paused. It is also the step that pays off fastest, because a register with everyone's name in it, even with no documents attached, already answers a question you currently cannot answer.

**Your accepted certificate holders.** More important than it sounds. A management company handling properties for a number of owners often needs certificates naming individual owner LLCs rather than the management company itself. Configured as a single name, every one of those certificates would be flagged as a mismatch, and the flags would all be wrong. This is a list, not a string.

**Your requirements.** Coverage minimums, per trade where they differ, since roofers and landscapers rarely carry the same limits. Plus which vendors are workers' compensation exempt, because sole proprietors in many states carry an exemption rather than a policy and would otherwise be flagged as deficient forever.

**The mailbox and the approver.** Connecting the mailbox, and deciding who receives approval emails and clicks the button. Worth thinking about properly: this is the person the whole system defers to, and the value of the gate depends on them actually reading the drafts rather than clicking through them.

**Your cadence.** When reminders go out, and how often re-attestation runs. The defaults are 60, 30, 14 and 0 days, with re-attestation every 90. All of it is a setting.

Then the certificates you already hold get run through in a batch, which produces the first genuinely useful output: a picture of where you currently stand, including the vendors nobody realised had nothing on file.

### What the office's week looks like afterwards

**A certificate arrives.** Nobody opens it, nobody types a date, and the register updates. If the document is unclear, it appears in review rather than becoming a number nobody checked.

**Once a day, in the morning,** the system works out who needs chasing and drafts the emails. The approver gets one message per vendor showing exactly what would be sent and to whom, and clicks approve or declines. Approving takes seconds. Nothing goes out otherwise, and an unanswered approval expires rather than sending.

**Ignored requests follow themselves up** on the configured schedule, and after two ignored requests the vendor is handed back to a person and automated chasing stops for them. You do not have to remember any of this, and you do not have to worry about a script emailing a vendor for the rest of the year.

**When somebody asks where you stand,** the answer is a page rather than an afternoon.

The work that disappears is the invisible kind: opening PDFs, reading four date fields, typing them into a spreadsheet tab, and remembering to send the third reminder. The work that remains is the work that should require a person: deciding what to do about a holder mismatch, deciding whether a limit below your minimum matters for that vendor, and deciding whether a reminder should go out at all.

### Where it runs, and who owns it

The default is one deployment per client, on a server in your own cloud account or on a small server provisioned in your name. n8n, the database, the stored certificates, the backups and the monitoring all sit inside that one environment. Nothing is shared with another company, and nothing routes through infrastructure belonging to whoever built it.

That is partly a privacy answer and partly a continuity one. It means the honest answer to "where does our data live" is a server you control in a region you chose, and it means the system does not stop working if the person who built it becomes unavailable.

It is worth being straightforward about the one thing that does leave your environment. Certificate content is sent to a model provider's API to be read. That traffic is vendor business information: company names, carrier names, policy numbers and dates. It contains no resident or tenant data, because the system never touches any. Current commercial API terms for the major providers state that inputs are not used to train models and are retained only briefly for abuse monitoring before deletion, and the provider's own published terms should be the thing you read rather than anyone's summary of them.

### What has to be built before you can rely on it

This part is the honest gate, and skipping past it would be the easiest way to lose your trust in month three.

What is described in this document works, and has been tested end to end against a full set of synthetic documents. That is not the same thing as a system a business can depend on unattended. Before that point, a specific set of controls has to be implemented and tested for your deployment:

- **Error alerting**, so a failed run reaches a person instead of sitting in a log
- **Retries** on model calls and email sends, since transient failures are normal
- **A visible failure queue**, so a document that could not be processed appears somewhere a human looks rather than vanishing
- **Duplicate protection** keyed on message ID and attachment hash, which is stricter than what the demo needs, because real mailboxes redeliver and forward
- **A daily heartbeat and a weekly canary**, the two controls that matter most here

That last pair deserves an explanation, because it addresses this system's real risk. The failure mode is not a crash. It is silence. If the mailbox connection quietly stops working, nothing looks broken: no errors, no alerts, just certificates that stop arriving. Six weeks later you discover the register has been frozen since March. That is precisely the failure this product exists to prevent, which makes it the failure that would end the engagement. A heartbeat confirms each workflow actually ran; a canary sends a known test certificate through the whole path weekly and checks it landed. Both exist to detect nothing happening, which is the hardest condition for any automated system to notice about itself.

Alongside those: HTTPS on everything public, authentication on the editor and the dashboard, the database not exposed, backups with a tested restore rather than just a backup job, and agreed retention periods for documents and data.

Then a go-live test that runs a clean certificate, an expiring one, and one that needs review; checks the dashboard; runs the daily watch; approves one reminder; and confirms the vendor email actually sent and was logged.

### Who is responsible for what

Worth agreeing explicitly, because most of the ways this goes wrong are boundary problems rather than technical ones.

**You keep** the vendor register accurate, confirm holder entities and coverage requirements, decide what happens with review rows, ask your broker or carrier when a question is genuinely about coverage rather than paperwork, and make sure approvers read drafts rather than rubber-stamping them.

**The build side keeps** the workflows and credentials healthy, monitors errors, dead letters, heartbeat, canary and backups, documents outages and fixes, exports your data whenever you ask, and does not quietly expand what the system claims to do.

### Leaving

Everything exports. The workflows are files. The database takes a standard dump. The certificates are PDFs in dated folders you can already browse. Handing the whole thing to another developer, or to an internal IT person, is a folder and an afternoon.

This is worth stating early rather than treating as an awkward question, because it is the reasonable thing to want to know before letting anyone build something your operations will come to depend on. Nothing here holds your data, and there is no component in the middle that belongs to someone else and could be withdrawn.

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
- **Scope boundary, in client-facing language.** `docs/stage-9-scope-limitations.md`
- **What production requires.** `docs/stage-9-production-readiness-plan.md`, with the onboarding checklist beside it
- **Production gaps still outstanding.** `docs/stage-9-*.md`
