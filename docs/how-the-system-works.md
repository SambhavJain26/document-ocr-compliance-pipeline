# How The System Works

Written for a property manager or an owner. **Nothing in this document requires you to know what tool it was built in, and no part of it asks you to read code.** Where a technical detail would change what you can expect from the system, it is stated in plain language. Where it would not, it is left out.

A companion document, `build-technical-notes.md`, carries the engineering detail. If you want to know which piece does what and why it was built that way, read that one instead.

**One thing stated up front, because it changes how you should read everything else: there is no client. Nobody is using this.** Every result described here comes from testing against manufactured documents. That is worth something, but it is not the same thing as a customer outcome, and this document is careful never to blur the two.

---

## The problem

**Vendor insurance certificates expire on dates nobody is watching, and the only way to find out is to go and look.**

A property management company at 150 to 600 doors works with somewhere between twelve and forty regular vendors. Plumbers, electricians, HVAC techs, landscapers, painters, roofers, pest control, cleaners. Every one of them is supposed to carry liability insurance before they set foot on a managed property, and every one proves it the same way: by sending a certificate of insurance, almost always a one-page standard form.

Someone in the office receives that certificate. They save it somewhere. If the office is organised, they type the expiration date into a spreadsheet column. Then they move on, because eleven other things are happening that morning.

Then the policy expires.

Different vendors renew on different dates with different carriers. The plumber's general liability runs to March, the roofer's to August, the landscaper switched carriers last year and nobody wrote that down. Nobody is watching the calendar, because watching the calendar is not anybody's job. The spreadsheet was last updated whenever the last person who cared about it stopped caring, or left.

### Why it stays broken

This is a task that is never urgent until it is catastrophic. There is no daily pressure to update the insurance tab. No tenant calls about it. No owner emails about it. It fails silently, and the failure becomes visible at the exact moment you are least able to do anything about it.

It is also tedious in a way that resists delegation. Chasing a plumber for an updated certificate means emailing him, waiting, emailing his insurance agent, waiting, receiving a PDF, opening it, reading four date fields, and typing them somewhere. Call it four minutes. Multiply by twenty-five vendors, once a year, on twenty-five different dates nobody is tracking, plus second and third follow-ups for the ones who never reply. The cost is real and it is spread so thinly across the year that it never appears on anyone's list as a task worth solving.

There is a second reason, and it shaped the design. Property managers are not insurance professionals. Asked to look at a certificate and say whether it is acceptable, most would rather not commit to an answer, and there is no comfortable way to ask. So the safe move is to file it and move on, which is exactly the behaviour that lets a lapse go unnoticed.

### What the software you already own does, and does not do

Property management platforms do let you record vendor insurance details, and some will warn a manager at work-order assignment if the recorded insurance has expired. That is a real feature and it is worth having.

What they do not do: read a certificate PDF and pull the dates out of it, notice that an expiration is approaching, email the vendor or their agent to request a renewal, follow up when that email is ignored, or show you in one view which vendors currently have nothing on file.

The warning at assignment is a last line of defence, not a system. It depends entirely on somebody having typed the date in correctly in the first place, and it fires at the worst possible moment, when a job is urgent and a person is under pressure to click past it. The field is not the problem. Keeping the field current is the problem.

### What kind of problem this actually is

This is an attention problem, not a judgement problem. The hard part is not deciding whether a certificate is good. The hard part is noticing, on the right day, that a document nobody has looked at in eleven months is about to stop being current, and doing something about it before it does.

That distinction governs the entire design.

---

## Is this a real industry problem

Yes, and the evidence is worth being precise about, because it is not the kind of evidence people usually present.

**There are no industry surveys with percentages in this research, and none are cited here.** What exists instead is four kinds of source, all live:

| Source | What it establishes |
|---|---|
| [r/PropertyManagement — "COI tracking"](https://www.reddit.com/r/PropertyManagement/comments/1rm3sxo/coi_tracking/) | Practitioners publicly asking for help with this exact task, unprompted |
| [r/PropertyManagement — "almost had an uninsured vendor on site last week"](https://www.reddit.com/r/PropertyManagement/comments/1t00808/new_to_all_of_this_and_almost_had_an_uninsured/) | The near-miss version of the failure, described by the person it happened to |
| [Buildium — Tracking Vendor Insurance](https://help.buildium.com/hc/s/article/Tracking-Vendor-Insurance-1557495330433) | The software gap, confirmed from the platform's own documentation rather than inferred |
| [RealPage — Vendor Credentialing](https://www.realpage.com/vendor-credentialing/) | Certificates travel with W-9s, licences and background checks as a document stack |
| [NetVendor — Why Manual COI Tracking Is Broken](https://www.netvendor.com/blog/why-manual-coi-tracking-is-broken-how-to-fix-it) | The category's own description of the failure mode it sells against |
| [BCS — What Happens When A Vendor's Insurance Expires](https://www.getbcs.com/blog/what-happens-when-a-vendors-insurance-expires-a-risk-managers-guide) | The downstream consequence, from a risk-management perspective |
| [Texas Department of Insurance — certificate FAQ](https://www.tdi.texas.gov/certificates/faq.html) | That additional-insured and cancellation-notice wording depend on policy or endorsement terms, not on the certificate |
| [NY DFS — ACORD 25 filing](https://www.dfs.ny.gov/apps-and-licensing/insurance-companies/certificates-approved/acord-25-2025-12-liability) | That the certificate is informational and does not amend the policy |

The two Reddit threads are the strongest signal available, and they are stronger than a survey statistic would be. Nobody prompted those people. They went looking for help, publicly, in their own words. That is demand rather than stated preference.

### What the research does and does not prove

**It proves the problem is real.** Practitioners describe it unprompted. The platforms they already pay for document the gap themselves. The regulators confirm the certificate does less than people assume.

**It proves the problem has been noticed by others.** There is an established software category selling to exactly this buyer: myCOI, NetVendor, VendorAccess, BCS, SmartCompliance, ExpiryEdge, Jones, Vertikal RMS, Lula. Nothing in this document should be read as claiming nobody has thought about this before. They have, and several of them have raised money doing it.

**It does not prove this solution works.** Not one of those sources evaluated this build, or any build. They establish that a problem exists and that people want it solved. They say nothing about whether this particular approach solves it, whether a property manager would adopt it, or whether it survives contact with real vendor documents at real volume.

**It does not prove the approach is novel.** Reading certificates, tracking expiry dates and sending reminders are all things the category already does. The difference claimed here is narrow and specific: this runs inside the mailbox and database a company already owns, with nothing for a vendor to log into. That is a difference in delivery, not a difference in capability, and it should not be described as one.

---

## The solution

**A certificate arrives by email, the facts printed on it are read and recorded automatically, and the register updates itself. Once a day the system looks for paperwork that is missing or running out, drafts a reminder for each one, and holds every draft until a person releases it.**

The design rests on one distinction, and every unusual decision below exists to protect it: **the system reports what a document says. It never reports what is true.**

A certificate is a photograph of one day. It cannot tell you a policy is still in force, and neither can anything that reads it. So the system tracks paperwork and dates, and refuses to form an opinion about insurance. That refusal is not a limitation it apologises for. It is the reason the rest of it can be trusted.

---

## The chase cadence

The system checks every vendor once a day and sorts them into one of seven states. The first matching state wins, in this order.

| State | What it means | What happens |
|---|---|---|
| Paused | This vendor has already ignored enough requests to be handed back to a person | Nothing |
| Never received | No certificate on file at all | Chase |
| Expired | Past the date printed on the document | Chase |
| 14 days | Expires within two weeks | Chase |
| 30 days | Expires within a month | Chase |
| 60 days | Expires within two months | Chase |
| Re-attestation | Nothing wrong, but 90 days since this vendor last confirmed anything | Chase |
| None | Nothing to do | Nothing |

Reminder points are 60, 30, 14 and 0 days out, and re-attestation runs every 90 days. Both are settings rather than fixed rules.

Two details are deliberate. **Vendors with no certificate at all are chased before vendors whose certificate is expiring**, because they are the ones most easily forgotten, precisely because they have no date attached to remind anyone they exist. And **a manually recorded cancellation is treated as expired**, because a person has told the system something the document could not.

### On the days it does nothing

This is the least obvious design decision in the build and probably the most important one.

On a typical day, most vendors match no state at all and the system does nothing about them. Beyond that, chasing is suppressed in three more situations: when a vendor is paused, when a reminder for that same problem is already sitting in somebody's inbox awaiting a decision, and when a reminder went out recently and the seven-day follow-up interval has not yet elapsed.

The effect is that a vendor who is being chased hears from you roughly once a week about a given problem, not once a day, and stops hearing from you entirely after two ignored requests.

Anything that contacts your vendors on your behalf has an opinion about how often that is acceptable, whether or not anyone wrote it down. Most automated chasing fails not because it never fires but because it fires too much, and the vendor stops reading. The restraint is the product. The sending is the easy part.

---

## What actually happens, start to finish

Fourteen steps, in the order they occur.

**1. A certificate arrives.** Three ways in: as an attachment to an email in the office mailbox, uploaded through a web form, or run manually from a test document. All three join the same path immediately, so behaviour does not depend on how a document arrived.

**2. Anything that is not a PDF is turned away.** An image, a spreadsheet, a link to an insurance portal: none of these become a certificate. Each becomes a notice for the manager, so it is visible rather than silently dropped.

**3. The original is saved before anything reads it.** The PDF goes to disk first, and its location is recorded. This ordering is the most defensive decision in the system. If the reading fails, if the checking code breaks, if the database is unreachable, the document still exists and is still findable. The alternative, read first and save on success, loses documents on exactly the days you can least afford to lose them.

**4. Locked files are routed to review rather than forced.** A password-protected PDF cannot be read, and the system does not pretend otherwise. It lands in review with the file attached so a person can go and ask for the password.

**5. The document is read.** The system tries the text already embedded in the PDF first, because that is exact. If the document turns out to be a scan or a photo with no real text in it, the page is read visually instead. Either way the output is the same set of facts: vendor, carrier, policy number, coverage lines, limits, effective and expiration dates, certificate holder.

**6. The reader rates its own confidence.** High, medium or low. Low confidence is treated as an answer in itself, not as a number to be used anyway.

**7. The facts are checked against your requirements.** This part is not AI. A fixed set of rules, identical on every run, asks: are the dates in a sensible order, is the expiration plausible, is there a general liability line, is there a workers' compensation line, does the certificate holder match one of your accepted legal names, do the limits meet your minimum for that trade, is this vendor suspiciously similar to one already on file, and does this renewal leave a gap after the policy it replaces.

**8. Each problem found is graded.** Nine problems are serious enough that no usable certificate comes out of them. Five mean the certificate is usable but falls short of something you asked for. One is recorded as neutral information. Grading them differently is most of the work, because a process that treats a locked file the same as a slightly low limit is a process people learn to ignore.

**9. The certificate is filed, or it is not.** Four outcomes: filed as current; sent to review and visibly not counted as current; recognised as older than what is already on file and ignored without regressing the register; or recognised as not a certificate at all, in which case no vendor record is invented and the manager gets a notice.

**10. The register updates.** One row per vendor, showing carrier, policy number, limit, expiration date, status, whether anyone has chased them, and a link to the original document.

**11. Every row links back to the document it came from.** One click, not a search through an inbox. This is what makes the reading checkable rather than final. Nobody has to take the system's word for a date.

**12. Once a day, the system looks for what is missing.** It sorts every vendor by the cadence above, and drafts a short reminder for each one that needs chasing, naming the vendor, the policy number and the date, and making no claims about insurance.

**13. Then it stops.** Every draft is written to the record as pending before anything is sent, and then held. The manager receives the vendor, the reason, the intended recipient and the exact message, with two buttons. Approving releases that one message and nothing else. If nobody responds within 24 hours, the request expires rather than sending.

**14. What was sent is recorded, and repeated silence ends the chase.** Recipient, timestamp, message and follow-up date all go to the log. If a follow-up comes due and nothing has arrived, a second request goes out. After two ignored requests the system stops chasing that vendor and hands them to a person. It will not email somebody indefinitely.

---

## What each part does

| Part | What it does |
|---|---|
| The office mailbox | Both doors: certificates arrive through it, approved reminders leave through it |
| The database | Holds the vendor register, the certificates, the reminder history and your requirements. This is the asset, and the client owns it |
| Document storage | Every original PDF, filed by date, linked from every row |
| The reader | Transcribes what a certificate says and rates its own confidence. Makes no decisions |
| The rules | Decide everything consequential, identically on every run |
| The daily check | Finds missing and expiring paperwork and drafts reminders |
| The approval step | Holds every outbound message until a person releases it |
| The register | A web page showing current state. A view of the data, not an application, with nothing to log into |

---

## The human boundaries

These are enforced in code, not by instructing a model to behave. That distinction matters: an instruction is a request, and a model can ignore a request. None of the following depends on one.

- **No message reaches a vendor without a person clicking approve.** Structurally so, not by policy. See the technical notes for the audit that establishes it.
- **An unanswered approval expires rather than sending.** Waiting is the default outcome, not a special case somebody has to configure.
- **Approving one message releases exactly that message.** It has no effect on any other vendor's pending request.
- **During setup, outbound mail is redirected to a test address**, so a real vendor cannot be contacted by accident before anyone intends it.
- **Two statuses can only ever be set by a person: cancelled and non-renewed.** Nothing in a certificate reveals either, so the system will not infer them. A manager records them by hand, with their name attached.
- **Four words are forbidden from anything the register displays**: compliant, verified, covered, approved. If one appears, the page refuses to render and the build fails its own check. Status is always a date fact instead.
- **A serious problem can never quietly become filed, current paperwork.** If something is wrong, a person sees it.

---

## What this system will not do

Design decisions, not gaps.

- **It will not tell you a vendor is insured.** Nothing that reads a certificate can. A certificate describes the day it was issued.
- **It will not detect a mid-term cancellation.** Nothing in the document reveals one.
- **It will not confirm additional-insured status or interpret endorsements.** That requires the policy, not the certificate.
- **It will not spot a forged certificate.**
- **It will not decide whether a vendor may work on a property.**
- **It will not guess at an unclear document.** It asks a person.
- **It will not treat a ticked checkbox as proof.** It records that a mark was present, and the field is named to say exactly that.
- **It will not turn cancellation-notice wording into a promise that notice will be given.**
- **It will not know about a vendor nobody entered into the register.**
- **It will not write back into your property management software.**

Everything in that list belongs with an agent, a broker, a carrier or a lawyer.

---

## What the proof of concept demonstrates today

Verified against 17 manufactured test certificates and a local database seeded with 18 fictional vendors. Every item below has been observed in a real run.

- A certificate uploaded through the form is read, checked, filed, and appears on the register with its source document linked and openable.
- A document that is not a certificate produces a manager notice and no certificate record. No vendor is invented from a W-9.
- A password-protected file lands in review without stopping the run.
- A certificate with the expiration before the effective date lands in review rather than having a date picked for it.
- A certificate naming a holder that is not on the accepted list is filed with a visible note rather than rejected.
- A limit below the configured minimum for that trade is filed with a visible note.
- A renewal that starts after the previous policy ended is flagged as a gap, which requires comparing two documents rather than reading one.
- An older certificate uploaded over a newer one does not regress the register.
- The daily check sorts vendors into the correct states and drafts one reminder per actionable vendor.
- Two vendors in the same run each produce an independently approvable request. In a live two-vendor test, both were approved eight seconds apart with no cross-contamination between them.
- A declined request sends nothing and is recorded as declined.
- The register refuses to render if a forbidden word appears anywhere in it.

**This is testing, not a result.** Seventeen documents that I manufactured, processed by a system I wrote, on a machine I control. No property management company has used this. No real vendor has ever received a message from it. Nothing above should be read as evidence that it saves time, catches lapses in practice, or is something a business would keep using, because none of those things have been tested and cannot be tested without a client.

---

## What a client pilot would have to measure

The pilot exists to answer questions the fixture testing structurally cannot.

**The one variable the pilot actually turns on** is outbound delivery. Today, approved messages are redirected to a test address. A pilot flips that single setting so approved messages reach the real producer or vendor. Everything else already runs. That is the entire difference between what exists and what a pilot is, and it is worth being clear that it is a one-line change guarded by a human click, not a new phase of building.

What has to be measured once it is on:

| Question | Why fixtures cannot answer it |
|---|---|
| Do real certificates read correctly? | Mine are manufactured and consistent. Real ones are scanned crooked, photographed, emailed as forwards of forwards |
| How often does a document reach review? | The fixture set deliberately over-represents problems |
| Do vendors reply, and how fast? | No vendor has ever been contacted |
| Does the reminder wording get a document back, or an argument? | Never tested on a human |
| Does the approver actually click, day after day? | This is the whole system's dependency and it is unproven |
| Does anyone open the register? | A dashboard nobody opens is not a benefit |
| How many chases per week does the office consider acceptable? | The seven-day interval is a guess |
| What breaks that I have not imagined? | Always the most valuable finding |

**A pilot should not be scored on time saved.** Any such figure would be arithmetic derived from an assumed per-certificate handling time, and I would be supplying both the assumption and the conclusion. If you want that number, measure your own handling time before starting and compare it yourself.

---

## What production would add

The current build is a working demonstration on a local machine. Running it inside a business needs controls that do not exist yet:

- Hosting the client owns, with the public surfaces protected rather than open
- Alerting when a run fails, so a failure is noticed the day it happens
- Retries and backoff on the outside services it depends on
- A dead-letter queue, so a document that fails repeatedly is visible rather than lost
- Duplicate protection keyed on message and attachment, so a forwarded email cannot double-file
- A daily heartbeat and a weekly test certificate, to prove it is still working on a quiet week
- A weekly digest to the client, so the system reports on itself
- Backups, and a restore that has actually been tested
- Written data-retention terms, and a documented way to export everything and leave

Until those are in place and tested for a specific client, this is a demonstration. It should not be described as production-ready, and this document will not describe it that way.
