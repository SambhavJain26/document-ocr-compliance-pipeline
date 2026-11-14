# Problem 1  -  Vendor Insurance Certificate Chasing

**Build order: FIRST**
**Verdict: Validated  -  build and sell this before anything else**
**Segment: US residential property management, 150-600 doors**

---

## Quick Summary

| | |
|---|---|
| **What it is** | Automated tracking and chasing of vendor certificates of insurance |
| **Who buys** | Owner/principal or operations manager |
| **Why it wins first** | Zero PMS integration required, one-page standardised document, contained 90-second demo |
| **Build time** | 2-3 days to demo depth |
| **Token cost to build and test** | Under $1 |
| **Trust barrier** | Low  -  if positioned correctly (see Positioning) |
| **Price** | $600-1,200 setup, $200-350/month |

---

## The Problem

### What actually happens

A property management company works with somewhere between 12 and 40 regular vendors  -  plumbers, electricians, HVAC techs, landscapers, painters, roofers, pest control, cleaners. Every one of them is supposed to carry liability insurance before they set foot on a managed property.

The vendor provides a Certificate of Insurance  -  almost always an ACORD 25, the industry-standard single-page form. Someone at the management company files it, maybe types the expiry date into a spreadsheet, and moves on.

Then the policy expires. Different vendors renew on different dates with different carriers. Nobody is watching the calendar. The spreadsheet was last updated whenever the last person who cared about it stopped caring.

### Why it stays broken

This is the kind of task that is never urgent until it is catastrophic. There is no daily pressure to update the insurance tab. Nobody complains. No tenant calls about it. It fails silently, and the failure only becomes visible at the exact moment it matters most.

It is also genuinely tedious in a way that resists delegation. Chasing a plumber for an updated certificate means emailing him, waiting, emailing his insurance agent, waiting, receiving a PDF, opening it, reading four date fields, and typing them somewhere. Multiply by 25 vendors, once a year, on 25 different dates.

### What the software they already own does  -  and doesn't

This matters, because you'll be asked.

Buildium **does** let you record vendor insurance details and it **will warn** a manager at work-order assignment if a vendor's recorded insurance has expired.[^1]

Buildium does **not**:
- Read a certificate PDF and extract the dates
- Notice that an expiry is approaching
- Email the vendor to request a renewal
- Follow up when the vendor ignores the first email
- Tell you which vendors are currently non-compliant, in one view

The warning at assignment is a last line of defence, not a system. It fires at the worst possible moment  -  when a job is urgent and a human is under pressure to override it.

---

## Real-Life Examples

### Example 1  -  The override

> A 280-door management company in Charlotte works with 18 regular vendors. The insurance tab in their vendor spreadsheet was last updated in January by an office manager who has since left.
>
> Their main plumber's general liability policy expired in March. Nobody noticed  -  no alert, no reminder, no process.
>
> In May, a tenant reports water coming through a ceiling. The maintenance coordinator dispatches the plumber. Buildium flags his insurance as expired at assignment. She overrides it, because water is actively coming through a ceiling and she's fairly sure he emailed a renewal certificate at some point.
>
> He didn't. He soldered a joint, a smoulder started in the wall cavity, and the resulting fire caused $80,000 of damage.
>
> His carrier denies the claim  -  no coverage in force on the date of loss. The management company's own insurer opens a question about whether they met their duty to verify vendor coverage under the management agreement.
>
> The override took four seconds. The exposure is six figures.

### Example 2  -  The quiet version, which is far more common

> Same company, no fire. In November they discover during an owner audit that 7 of their 18 vendors have certificates that expired more than 90 days ago.
>
> Nothing bad happened. But the ops manager now spends three full days emailing vendors, chasing insurance agents, downloading PDFs, and re-typing dates. Two vendors have changed carriers entirely and nobody knew.
>
> The client asks: *"how did we not know this?"* There's no good answer, because there was never a system  -  just a spreadsheet and the hope that someone would remember.

**Use Example 2 in sales calls.** Example 1 sells fear, and fear makes buyers defensive. Example 2 describes their actual Tuesday.

---

## Evidence This Is a Real Problem

### Unprompted practitioner demand  -  the strongest signal available

Multiple threads exist on r/PropertyManagement dedicated entirely to this problem, including ones titled *"COI tracking"* and *"New to all of this and almost had an uninsured vendor on site last week, how are you guys managing your COIs?"*[^2]

This matters more than any survey statistic. Nobody prompted these people. They went looking for help, publicly, using their own words. That is demand, not stated preference.

### The software gap is confirmed from the vendor's own documentation

Buildium's help centre documents vendor insurance tracking as manual date entry with a work-order warning.[^1] There is no OCR, no extraction, no outreach, no follow-up. This is not an inference from a comparison site  -  it's from the platform's own docs.

### Real legal grounding

An uninsured contractor causing damage transfers liability to the property manager and can constitute a breach of the management agreement with the owner.[^3] Courts have held property owners and management companies liable for injuries caused by contractors where the company failed to verify adequate coverage.[^3]

### No affordable competitor at this portfolio size

The specialised vendor compliance platforms  -  TrustLayer, Jones, NetVendor, CertFocus  -  are built and priced for enterprise portfolios.[^3][^4] Mid-market operators are left with spreadsheets and calendar alerts.

### It survives the constraint that killed other opportunities

Buildium's Open API is gated behind the Premium plan at roughly $375-400/month.[^5][^6] Any product requiring database write-back forces the client into a tier upgrade before they've paid you anything.

**This product needs zero Buildium integration.** PDFs arrive by email, data lives in your own store, reminders go out by email. Nothing touches their PMS.

### Honest counter-evidence

One vendor compliance company states plainly that manual tracking *"at small scale, this can work"* and only breaks down at portfolio scale.[^3] A 500-unit operator may manage 150-300 vendor relationships producing 600-1,500 policy expirations a year;[^4] a 250-door single-family shop with 18 vendors is a different order of magnitude.

**This is real and you should know it.** It's why the product is priced at $200-350/month and not $800, and why you sell it as administrative relief rather than as risk management infrastructure.

---

## Ideal Buyer

### Profile

| Attribute | Target |
|---|---|
| Doors | 200-600 |
| Vendor count | 15+ regular vendors |
| Property type | Mixed SFR / small multifamily |
| Staff | 3-15 |
| PMS | Buildium, Rentec Direct, Rent Manager, Propertyware |
| Buyer | Owner/principal, or ops manager with budget authority |

### Strong buying signals

- They've had an insurance scare, a claim dispute, or an owner ask about vendor compliance
- Their management agreement with owners contains a vendor-vetting clause
- They've recently taken on an institutional or out-of-state owner who asks harder questions
- Their liability insurance is up for renewal and the carrier is asking questions
- They employ or have employed a VA to "check vendor insurance"

### Qualifying questions

Ask these in discovery. They tell you whether to pitch at all:

1. *"How many outside vendors do you use regularly?"*  -  under 12, walk away
2. *"How do you know today whether your plumber's insurance is current?"*  -  listen for "spreadsheet," "the file," or a pause
3. *"When did you last chase a vendor for an updated certificate?"*  -  if the answer is "we don't," the pain isn't felt yet
4. *"Which Buildium plan are you on?"*  -  establishes their API ceiling for everything you'll ever sell them

### Disqualifiers

- Fewer than 12 vendors  -  genuinely a spreadsheet problem
- They use one in-house maintenance team and almost no subcontractors
- They're already on a compliance platform
- Above 800 doors  -  you're now competing with enterprise tools that do endorsement verification properly

---

## Positioning and Sales

### The single most important framing decision

**Sell it as chasing paperwork. Never as verifying coverage.**

Here is the technical reason, and you must understand it before you sell anything:

A certificate of insurance is informational only. It does not amend the underlying policy or grant rights beyond what the policy and its endorsements already provide.[^7] The ADDL INSD and SUBR WVD columns on an ACORD 25 are *assertions*, not proof  -  an X in either column is only a claim.[^8] Additional insured status requires a carrier-issued endorsement, typically ISO form CG 20 10 for ongoing operations or CG 20 37 for completed operations. **Listing someone as additional insured in the Description of Operations box does not extend coverage to them.**[^9]

So your tool can reliably tell a manager *"this certificate expires on 14 March and here's the draft email to the vendor."* It cannot tell them *"you are covered."*

| ❌ Don't say | ✅ Say |
|---|---|
| "Ensures your vendors are compliant" | "Never lets a certificate expire unnoticed" |
| "Protects you from uninsured vendor liability" | "Takes the chasing off your desk" |
| "Verifies coverage" | "Reads the certificate and tracks the dates" |
| "Compliance system" | "Automated vendor paperwork assistant" |

The honest framing is also the *easier sale*. Compliance assurance is a high-trust purchase that a buyer would reasonably prefer to make from an established agency. Administrative relief is a low-trust purchase they'll make from a freelancer on a first call.

### The positioning that actually converts

**Sell it as a virtual assistant, not as software.**

Property management companies at this size already hire offshore VAs for exactly this kind of work  -  chasing vendor insurance, chasing late rent, processing paperwork.[^10] That's your real competition, and it's the frame the buyer already thinks in.

> *"You know how people hire a VA to chase vendor certificates? This does that part, costs less, doesn't need training, and doesn't quit."*

This sidesteps the "why would I pay for custom software" objection entirely.

### Opening the conversation

Lead with their reality, not your product:

> *"Quick question  -  when your plumber shows up to a job, how do you know his insurance is current that day?"*

Most will describe a spreadsheet, a folder, or admit they don't really know. That admission is your entire pitch. You haven't sold anything yet; they've diagnosed themselves.

### Objection handling

**"Buildium already tracks this."**
> "It does  -  it warns you at assignment if the date you typed in has passed. Two gaps: someone has to type the date in the first place, and the warning fires when you're already dispatching, which is when people override it. This fills the certificate in automatically and tells you 30 days early, when there's still time to do something."

**"We've never had a problem."**
> "Most companies haven't. The question isn't whether it's happened  -  it's how long it takes you to find out when it does. Want me to run your current vendor folder through it? I'll tell you in ten minutes where you actually stand." *(This is a strong close. Offer it free.)*

**"Can't I just set calendar reminders?"**
> "You can, and some do. The reminders are the easy half  -  the annoying half is opening each PDF, reading four date fields, typing them somewhere, then emailing the vendor and following up when they ignore you. That's what this removes."

**"How do I know this is accurate?"**
> "You don't have to trust it  -  every extracted field is shown next to the source document for you to confirm. It's doing the typing, not the deciding. And I'll say plainly: it reads the certificate. It can't verify endorsements, and no tool at this price can. If you need endorsement-level verification you want an enterprise compliance platform, and I'll tell you that rather than pretend otherwise."

That last answer wins deals. Naming your own limitation before they find it is the fastest credibility you can buy with no track record.

---

## The Build

### What the automation does

1. **Ingests** a certificate PDF  -  from a monitored email inbox, a web upload form, or a folder
2. **Extracts** structured data from the ACORD 25
3. **Validates** the extracted fields against basic rules
4. **Stores** vendor, policy, coverage and expiry data
5. **Watches** the calendar and fires reminders at 60, 30, 14 and 0 days before expiry
6. **Drafts** an outreach email to the vendor requesting a renewed certificate
7. **Escalates** to the manager when a vendor ignores two requests
8. **Reports** a single dashboard view: who's current, who's expiring, who's lapsed

### Why the document is easy  -  and why that matters

ACORD 25 is an industry-standard single-page form.[^7] Every certificate has the same boxes in the same places:

| Section | Contents |
|---|---|
| PRODUCER | Insurance agent/broker  -  name, phone, email |
| INSURED | The vendor's legal name and address |
| INSURERS A-F | Carrier names and NAIC numbers |
| COVERAGES table | Per coverage line: insurer letter, policy number, POLICY EFF, POLICY EXP, limits |
| ADDL INSD / SUBR WVD | Assertion checkboxes per coverage line |
| DESCRIPTION OF OPERATIONS | Free text  -  project, AI wording, primary & non-contributory |
| CERTIFICATE HOLDER | Who receives it  -  should be the management company's legal name |
| AUTHORIZED REPRESENTATIVE | Producer signature |

Coverage lines are consistent: Commercial General Liability, Automobile Liability, Umbrella/Excess, Workers' Compensation & Employers' Liability.[^7] Dates are MM/DD/YYYY.[^11]

**This is why the token cost is trivial.** One page of mostly tabular text  -  roughly 800-1,200 tokens per certificate. Compare with a 40-page lease at 20,000+ tokens. You can iterate 300 times for well under a dollar.

### n8n architecture

```
[Gmail Trigger]                 [n8n Form Trigger]
  poll: 1 min                    instant upload URL
        ↓
[Filter: PDF attachments only]
        ↓
[Extract From File]  ← operation: Extract from PDF
        ↓
[IF: text length > 200?]
        ↓ Yes                         ↓ No / scanned
[OpenAI node V2: text input]      [OpenAI node V2: PDF File input]
 Generate Model Response           Generate Model Response
 JSON Schema output                 JSON Schema output
        ↓
[Code node: validation rules]
        ↓
[Postgres: upsert vendor record]
        ↓
[Manager notice  -  Gmail or Telegram]

──── separate scheduled workflow ────

[Schedule Trigger: daily 08:00]
        ↓
[Postgres: read all vendor records]
        ↓
[Code node: compute days-to-expiry buckets]
        ↓
[Switch: never received / expired / 14d / 30d / 60d / re-attest]
        ↓
[OpenAI node V2: draft vendor email]
        ↓
[Gmail Send and Wait for Approval]
        ↓
[IF approved → Gmail send]
        ↓
[Postgres: log outreach + set follow-up flag]
```

**Node notes:**

- **Gmail Trigger** is the default inbox path for the demo. It can poll a dedicated label/address and retrieve attachment data through the Gmail API.
- **Email Trigger (IMAP)** remains a fallback for non-Google clients. Keep it disabled in the demo unless you are testing a non-Gmail mailbox.
- **Extract from File** replaced the old Read PDF node from n8n v1.21.0 onwards and handles native PDF text extraction[^13]
- Use **OpenAI node V2** for model calls when running current n8n. The `Generate a Model Response` operation supports the Responses API, PDF File message input, and JSON Schema output.[^14] Use HTTP Request only as a fallback for older n8n versions, missing node controls, or Anthropic.
- Do **not** use OCR Bro in the default build. For scanned or photographed certificates, route the raw PDF to the model's PDF File/vision path.
- Use **Gmail Send and Wait for Approval** as the default approval gate. Telegram is optional for manager alerts or for prospects who already use it.

### Extraction schema

Prompt the model to return strict JSON, nothing else:

```json
{
  "vendor_legal_name": "string",
  "vendor_address": "string",
  "producer_name": "string",
  "producer_email": "string | null",
  "certificate_date": "YYYY-MM-DD",
  "certificate_holder": "string",
  "coverages": [
    {
      "type": "GENERAL_LIABILITY | AUTO | UMBRELLA | WORKERS_COMP",
      "insurer_name": "string",
      "naic": "string | null",
      "policy_number": "string",
      "effective_date": "YYYY-MM-DD",
      "expiration_date": "YYYY-MM-DD",
      "each_occurrence": "number | null",
      "general_aggregate": "number | null",
      "addl_insd_asserted": "boolean",
      "subr_wvd_asserted": "boolean"
    }
  ],
  "description_of_operations": "string",
  "extraction_confidence": "HIGH | MEDIUM | LOW"
}
```

Note the field name `addl_insd_asserted` rather than `additional_insured`. Encode the honesty into your data model  -  it stops you drifting into overclaiming later.

### Validation rules (Code node, deterministic  -  no tokens)

Run these after extraction. They catch most model errors for free:

1. Every `expiration_date` must be after its `effective_date`  -  inverted dates are a known ACORD error mode[^11]
2. All dates must parse as valid MM/DD/YYYY[^11]
3. At minimum, a General Liability line must exist  -  flag if absent
4. If `certificate_holder` doesn't fuzzy-match the client's legal name, flag it  -  a certificate naming the wrong holder is a common and meaningful defect
5. If `each_occurrence` is below the client's configured minimum, flag it
6. If `extraction_confidence` is LOW, route to human review rather than auto-storing

### Build effort

| Phase | Time |
|---|---|
| Extraction pipeline + schema + validation | 1 day |
| Reminder scheduler + email drafting | 0.5 day |
| Dashboard view | 0.5 day |
| Testing against messy real-world variants | 1 day |
| **Total to demo depth** | **2-3 days** |

### Cost to run

| Item | Cost |
|---|---|
| n8n self-hosted | Free |
| Extract from File | Free |
| Model PDF vision fallback | API tokens only |
| LLM extraction | ~$0.002 per certificate |
| Storage (Postgres) | Free |
| Email (Gmail) | Free |
| **Monthly at 30 certificates** | **Under $0.10** |

Your margin on this product is effectively 100%.

---

## The Demo

Ninety seconds, and it's the most contained demo of the four products.

**Setup before the call:** have three sample ACORD 25 PDFs ready  -  one clean and current, one expiring in 20 days, one already expired.

**On the call:**

1. Share screen showing an empty dashboard
2. "I'm going to email a certificate to the system right now." Send the expiring one.
3. Within seconds: vendor name, carrier, policy number, coverage limits, expiry date all populate
4. Row highlights amber  -  *expires in 20 days*
5. Click through: the drafted vendor email is already written, addressed to the producer, with the policy reference filled in
6. Send the expired one. Row goes red. Manager alert fires to Telegram  -  **on their phone, in the meeting**

**Then the close:**

> *"Send me ten of your actual vendor certificates and I'll run this over them tonight. You'll have a real picture of where you stand tomorrow morning, and it costs you nothing to find out."*

That ask  -  ten PDFs by email  -  is the smallest first commitment in this entire product line. No system access, no credentials, no integration, no risk.

---

## Pricing

| Component | Price |
|---|---|
| Setup / onboarding | $600-1,200 |
| Monthly | $200-350 |
| First two clients (case-study pricing) | $400 setup, $150/month |

**Justify against the VA benchmark, not against software.** Offshore VA rates run roughly $6-12/hour, with monthly packages typically $1,000-2,500.[^10] At $250/month you are a fraction of the cheapest alternative that does the same job.

**Deliberately underprice your first two engagements** in exchange for a written testimonial and permission to publish numbers. You're buying case studies, not revenue.

---

## Risks and Limitations

**Be upfront about all of these. It's what makes you credible.**

| Risk | Reality | Mitigation |
|---|---|---|
| **Endorsement blind spot** | The certificate can't prove additional insured status  -  only a carrier endorsement can[^9] | State it in the proposal. Position as tracking, not verification |
| **Scanned/photographed certificates** | Extraction quality drops on low-quality scans | Route LOW confidence to human review. Never silently store a bad extraction |
| **Non-standard forms** | Some carriers use modified layouts | Field-level review UI. Don't chase 100% automation |
| **Small-portfolio ceiling** | Under 12 vendors this genuinely is a spreadsheet | Qualify hard. Walking away protects your reputation |
| **Scope creep into compliance** | Clients will ask you to "just confirm they're covered" | Hold the line. That's a different product with different liability |

### The rule to never break

**Never let the system tell a manager a vendor is "compliant" or "verified."** Use the language of dates and documents: *current until 14 March*, *expired 22 days ago*, *no certificate on file*. Facts about paperwork, never conclusions about coverage.

---

## Citations

[^1]: Buildium Help Center, "Tracking Vendor Insurance." https://help.buildium.com/hc/s/article/Tracking-Vendor-Insurance-1557495330433  -  documents manual insurance date entry and work-order assignment warning.

[^2]: r/PropertyManagement  -  "COI tracking" https://www.reddit.com/r/PropertyManagement/comments/1rm3sxo/coi_tracking/ and "New to all of this and almost had an uninsured vendor on site last week, how are you guys managing your COIs?" https://www.reddit.com/r/PropertyManagement/comments/1t00808/new_to_all_of_this_and_almost_had_an_uninsured/  -  unprompted practitioner demand.

[^3]: ExpiryEdge, "Vendor COI Tracking for Property Managers: The Manual-to-Automated Guide." https://expiryedge.com/articles/vendor-coi-tracking-property-managers/  -  vendor source; note the concession that manual tracking works at small scale.

[^4]: COIPulse  -  vendor relationship and policy expiration volume estimates for 500-unit portfolios. Vendor-published; treat as directional.

[^5]: Supergood, "Buildium API: Grade D | The API Report Card." https://supergood.ai/api-report-card/buildium  -  API paywalled behind Premium at $400+/month, no official SDKs, Zapier integrations reportedly fragile.

[^6]: PropertyCEO, "Buildium Pricing 2026." https://thepropertyceo.com/compare/buildium-pricing  -  Essential $58, Growth $183, Premium $375; Premium justified only by API access.

[^7]: Infrrd, "ACORD 25 Guide: Certificate of Liability Insurance Explained." https://www.infrrd.ai/blog/acord-25-certificate-of-liability-insurance-guide  -  form structure; additional insured status requires an endorsement.

[^8]: Ellie Insurance Group, "How to Read ACORD 25." https://ellieinsurancegroup.com/resources/how-to-read-acord-25-certificate-of-liability-insurance  -  ADDL INSD and SUBR WVD columns are assertions only.

[^9]: Get Business Coverage, "ACORD 25 Certificate of Insurance: Template and Guide." https://www.getbusinesscoverage.com/resources/acord-25-certificate-template-guide  -  AI status requires carrier endorsement CG 20 10 / CG 20 37; certificate alone cannot create it.

[^10]: Offshore VA market rates for property management support  -  MyOutDesk, Virtudesk, GigaBPO, BruntWork; $6-12/hour, $1,000-2,500/month packages.

[^11]: Instafill, "ACORD 25 (2016/03) Certificate of Liability Insurance." https://instafill.ai/forms/acord-25-201603-certificate-of-liability-insurance  -  MM/DD/YYYY validation, expiration-after-effective rule, common error modes.

[^12]: n8n Docs, "Email Trigger (IMAP)." https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.emailimap

[^13]: n8n Docs, "Extract From File." https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.extractfromfile  -  replaced Read PDF node from v1.21.0.

[^14]: n8n Docs, "OpenAI Text Operations." https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-langchain.openai/text-operations  -  documents `Generate a Model Response`, PDF File message input, and JSON Schema output support in the OpenAI node.
