# Vendor COI Chasing  -  Demo Build Plan

**Target:** US residential property management, 150-600 doors
**Token budget:** under $4 of the $10 allowance
**Paid dependencies:** none for the demo

---

## 1. Research findings

### 1.1 What I verified, and what changed the build

| Claim in your source doc | Verdict | Effect on build |
|---|---|---|
| Buildium API gated behind Premium | **Confirmed, and worse**  -  Premium is now **$400/mo** (was $375). Open API is Premium-only. | None. Reinforces zero-integration design. Update your sales numbers. |
| Extract From File replaced Read PDF | **Confirmed.** Current core node. | Use as specified. |
| Email Trigger (IMAP) exists with attachment download | **Confirmed.** Core node. | Kept, but **not** as the live demo path (see 1.4). |
| n8n has native approval flows | **Confirmed, and much better than expected** | See 1.3  -  Gmail approval is now the centrepiece; Telegram is optional. |
| Use `n8n-nodes-ocrbro` for OCR | **Rejected.** See 1.2. | OCR removed from the build entirely. |
| ACORD 25 is a standardised one-page form | **Confirmed.** Note there are multiple live revisions (a 2025/12 revision is filed with NY DFS alongside the older 2016/03). | Extraction prompt must not assume one revision's exact field order. |
| Certificate ≠ proof of coverage; AI status needs endorsement | **Confirmed.** ACORD's own form text states it is issued as a matter of information only and confers no rights on the certificate holder. | This is your best credibility line. Section 11. |

### 1.2 The OCR node is a trap  -  and you don't need OCR at all

`n8n-nodes-ocrbro` is MIT-licensed, but the maintenance signal is bad: **two releases, both published on the same day (28 Dec 2025), zero dependent packages, SourceRank 4.** That is a package someone published once and walked away from. Putting it in a live sales demo is an unforced risk.

The better-maintained alternative is `n8n-nodes-tesseractjs` (jreyesr, MIT, actively updated  -  Tesseract.js v6 bump, timeout option, PDF image extraction). Note separately that the unrelated npm package `node-tesseract-ocr` carries a known OS-command-injection advisory through 2.2.1  -  do not confuse the two.

**But the real finding is that you should drop OCR entirely.** The Anthropic Messages API accepts a PDF directly as a `document` content block (base64, `media_type: application/pdf`, limits: 100 pages / 32MB). For a scanned certificate with no text layer, Claude reads it with vision  -  no Tesseract, no community node, no system binaries, no separate rasterisation step. Quality on a photographed certificate is materially better than Tesseract.js, and it removes your only third-party node dependency.

**This changes the architecture: there is no OCR branch, there is a text-first / PDF-fallback branch, and both terminate at the same model call.**

**This holds on OpenAI too**, so the decision to drop OCR is provider-independent. OpenAI accepts PDFs as `input_file` (Responses API) or a `file` content part (Chat Completions), base64 or file ID. One behavioural difference matters for cost: **OpenAI extracts both the text layer and page images from every PDF and sends both to the model**, whereas you control that split yourself on Anthropic. See 1.9.

### 1.3 n8n has native human-in-the-loop, and it is your best demo moment

I did not expect this to be as strong as it is. n8n has **Send and Wait** approval operations that render **Approve / Decline buttons** and **pause the workflow** until tapped. Gmail is now the default approval channel for this demo because it works in the prospect's normal inbox with no app install. Telegram remains useful for manager alerts and for prospects who already use it.

This means your human-in-the-loop gate is not a compromise you have to explain away  -  it is a live, physical interaction you hand to the prospect. They tap Approve in their own email client and the vendor email sends in front of them. Build the demo around this.

**Two verified caveats:**
- The approval button resolves against your n8n webhook URL, so `WEBHOOK_URL`/`N8N_HOST` must be set to a publicly reachable HTTPS address. Multiple community reports of "invalid URL" failures trace to this. **This is the single most likely thing to break on the call.** Mitigation in Section 10.
- The approval operation returns a minimal approval result. Don't design anything that needs to edit or delete the prompt message afterwards.

### 1.4 Licensing  -  one finding that affects your business model, not just the build

| Component | Licence | Commercial use | Note |
|---|---|---|---|
| n8n (self-hosted) | Sustainable Use License (fair-code, **not** OSI open source) | **Conditional  -  read below** | |
| `n8n-nodes-tesseractjs` | MIT | Yes | Not needed under chosen design |
| PostgreSQL | PostgreSQL License (permissive) | Yes | |
| ReportLab (fixture generator) | BSD | Yes | |
| Telegram Bot API | Free, no per-message cost | Yes | |
| Anthropic API | Commercial terms, pay-per-token | Yes | |

**The n8n licensing finding you need to act on.** The Sustainable Use License permits use "only for your own internal business purposes." n8n's own docs explicitly confirm you may **offer commercial consulting or support services (e.g. building n8n workflows) without a separate licence agreement**. That covers you building workflows for a client.

What is *not* clearly covered is the model where **you host one n8n instance on your VPS, run several paying clients' COI pipelines on it, and charge them monthly.** That starts to look like providing n8n as a service rather than internal use. Nobody will chase a solo freelancer with two clients, but it is a real exposure that gets awkward at the exact moment things go well.

**Recommendation:** for production, install n8n on infrastructure belonging to the client (or a VPS you provision in their name and hand over), so it is *their* internal business use, and you bill for setup and support. This is also a **better sales position**  -  "the system runs on your server, I just build and maintain it" removes a trust objection. For the demo, your own instance is fine. If you intend to run multi-tenant, email `license@n8n.io` and get it in writing; it costs you an email.

**I could not verify** whether n8n would consider your specific single-tenant-per-client model as needing an agreement. I'm flagging the shape of the risk, not giving you a legal opinion.

### 1.5 The ACORD copyright issue your source document missed entirely

ACORD forms are **copyrighted, licensed rather than sold**, and ACORD's own licensing materials state that you must be party to a written licence agreement with ACORD Corporation to display, reproduce or distribute ACORD forms.

This does **not** stop you doing what this product does. Reading a certificate that a vendor sent your client is not a licensed activity  -  your client receives these in the ordinary course of business, and you are extracting data from a document you were given. Data extraction is contemplated in ACORD's own licensing language.

**Where it bites you is test fixtures and marketing:**

- **Do not** generate pixel-accurate replicas of the ACORD 25 blank form to use as fixtures, and do not commit such replicas to a repo or ship them in a proposal deck.
- **Do not** reproduce the ACORD logo or the ACORD copyright notice in anything you produce.
- **Do not** describe yourself as "ACORD certified", "ACORD licensed", or "ACORD integrated"  -  that is a trademark problem on top of a copyright one.
- **Do** build fixtures that are *layout-similar but not facsimile*: same field names and tabular structure, your own visual design, a clear `SPECIMEN  -  SYNTHETIC TEST DOCUMENT` watermark, obviously fictional carriers and vendors.
- **Do** say "reads standard certificate of liability insurance forms" rather than "reads ACORD 25s" in written marketing. Saying "ACORD 25" verbally on a call is normal industry shorthand and is fine.

I am not a lawyer and this is not legal advice  -  it is a description of the risk shape. The mitigation costs you nothing, so take it.

### 1.6 Regulatory gates  -  which apply and which don't

| Gate | Applies? | Why |
|---|---|---|
| **A2P 10DLC** | **Not to the demo. Blocks SMS in production.** | Registration takes 1-4 weeks; AT&T's manual campaign review alone is consistently 2-4 weeks and cannot be expedited. Critically, **brand registration requires a US EIN  -  which you, in India, do not have.** SMS must therefore be registered and billed under the *client's* entity, not yours. Unregistered A2P traffic is filtered, and T-Mobile levies per-violation fees. Gmail approval and optional Telegram alerts sidestep all of this for the demo. |
| **CAN-SPAM** | **Applies, but you land in the exempt category** | A renewal request to an existing vendor is transactional/relationship content, not commercial advertisement. Per the FTC, such messages must not contain false or misleading routing information but are otherwise exempt from most CAN-SPAM provisions. **Design implication: send from the client's own mailbox and domain, with their real reply-to. Never spoof, never send vendor mail from your infrastructure under your identity.** |
| **TCPA** | **Not applicable to this build** | TCPA governs calls, texts and faxes  -  not email. It becomes relevant only if you add SMS in production. |
| **Fair housing** | **Not applicable** | Nothing here is tenant-facing or housing-transaction-related. This is vendor administration. Say so plainly if asked; it is a point in your favour. |
| **State habitability windows** | **Not applicable** | No maintenance dispatch or repair timing in this product. |
| **FTC endorsement rules (16 CFR 255)** | **Applies to your marketing, not the build** | Once you have those first two case-study clients, testimonials must be genuine, and any material connection (e.g. discounted pricing in exchange for a testimonial) must be disclosed. You are explicitly planning discounted pricing for testimonials  -  **disclose it.** |

### 1.7 Data privacy  -  what you tell a prospect who asks

You are in India processing US business data. The good news: **this product touches no tenant data and no consumer personal information.** Vendor contact details, carrier names, policy numbers and dates are B2B business records. That keeps you clear of the consumer-privacy regimes (CCPA and successors) that would otherwise complicate an offshore processor.

Facts you can state accurately:

- **Certificates and extracted data live in Postgres on the VPS you control** (production: on the client's own server). Name the hosting region.
- **Certificate content is sent to a model API for extraction.** Both providers are materially equivalent here, and both are a good answer:
  - **Anthropic:** under the Commercial Terms, API inputs and outputs are **not used to train models** and are **deleted from Anthropic's backend within 30 days** by default.
  - **OpenAI:** API data is **not used to train models by default**, and inputs and outputs are retained **up to 30 days for abuse monitoring**, then deleted.
  - Zero Data Retention exists on both but is approval-gated and aimed at enterprise agreements. You will not have it. Don't imply you do.
  - Cite the provider's own privacy page rather than paraphrasing from memory. Have the link ready.
- **One nuance if you go with OpenAI and get a sharp prospect:** a 2025 court order in the New York Times litigation temporarily required OpenAI to preserve API content that would ordinarily have been deleted on the 30-day cycle. OpenAI has stated it returned to standard deletion practices. This is not a reason to avoid OpenAI, but if someone raises it, the honest answer is *"there was a litigation hold, it's been lifted, and here's their statement"*  -  not a blank look.
- **Neither first-party API offers an EU-only inference region** (Anthropic exposes `us` and `global`). Irrelevant for US clients; know it in case you are asked.
- **Nothing is written to their PMS.** The system has no credentials to Buildium, Rentec, Rent Manager or Propertyware and cannot alter anything in their system of record.

What you should do:
- Retain original certificate PDFs only as long as the client wants a paper trail; make retention a configurable setting, default 24 months.
- Do not store anything you don't need. There is no reason to hold vendor bank details, tax IDs, or W-9s  -  if a vendor emails one, don't ingest it.
- Offer to sign a one-page mutual NDA before they send you the ten sample certificates. It costs nothing and it converts.

### 1.8 Could not verify

- Whether n8n considers a single-tenant-per-client hosted arrangement to require a commercial agreement. Email them.
- The exact query semantics and limits of n8n's newer native **Data Table** node  -  I confirmed it exists as a core node with row and table operations, but not enough to bet a demo on it. Using Postgres instead (Section 4).
- Rentec Direct / Rent Manager / Propertyware API tiers and pricing. **Deliberately not researched further**  -  the chosen design needs zero PMS integration, so their API terms cannot block this sale. Ask the qualifying question anyway, because it tells you what you can sell them *next*.

### 1.9 Using OpenAI instead of Anthropic

**Verdict: use OpenAI by default for the demo, through n8n's built-in OpenAI node V2. Keep Anthropic as a fallback option.**

Current n8n documentation changes the earlier implementation choice. n8n OpenAI node V2, introduced in n8n 1.117.0, supports the OpenAI Responses API. Its **Generate a Model Response** operation supports message types including **Text**, **Image**, and **File**, with File currently supporting PDFs. It also exposes an **Output Format** option that can return Text, JSON Object, or a specified JSON Schema.

That means the default implementation should use the built-in OpenAI node, not a raw HTTP Request node:

- Text branch: OpenAI node V2 -> Generate a Model Response -> Text message -> JSON Schema output
- Scanned/PDF fallback branch: OpenAI node V2 -> Generate a Model Response -> File message, PDF binary from the previous node -> JSON Schema output
- Email drafting: OpenAI node V2 -> Generate a Model Response -> Text message

Use **HTTP Request** only if the installed n8n version is older than 1.117.0, the OpenAI node UI does not expose a setting we need, or you switch to Anthropic. Do not build provider-switching logic for the demo.

Four things genuinely differ.

**① Structured Outputs  -  a real advantage for OpenAI, and the strongest reason to switch**

OpenAI's `response_format: {"type": "json_schema", "strict": true}` constrains token generation at decode time against your schema. Output that violates the schema is not merely unlikely  -  it is *unable to be generated*. OpenAI reports 100% schema compliance in their evaluations.

Anthropic has no equivalent `json_schema` response format; you get schema conformance through prompting, which is highly reliable but not guaranteed.

For a demo that must not break in front of a prospect, a hard guarantee beats a strong tendency. This lets you reduce defensive parsing and shorten the system prompt (see 5.3). **If you have no other preference, this is the reason to pick OpenAI for this particular build.**

Three caveats, all verified:
- Strict mode restricts which JSON Schema features you can use. Every property must appear in `required`, `additionalProperties: false` is mandatory, and optional fields must be expressed as a union with `null` (which is already how the Section 5.2 schema is written  -  no change needed).
- **Refusals become a first-class failure mode.** The model may return a `refusal` object instead of your JSON. Check `message.refusal` before parsing, or the pipeline throws on an input it declined to process.
- The schema itself counts toward input tokens  -  roughly 200-500 for a schema this size. Negligible here.

**② PDF token economics run the other way**

OpenAI always sends *both* extracted text and page images for a PDF file input. That makes a PDF sent as a file more expensive than the same document sent as plain text  -  which makes the **text-first branch more valuable on OpenAI, not less.** Keep the two-branch design; it is doing more work for you here.

Practical effect: on the text branch the two providers cost roughly the same. On the vision branch, expect OpenAI to run somewhat higher per certificate. At this volume the absolute difference is fractions of a cent, so do not let it decide anything.

**③ Model churn is the operational risk nobody mentions**

Over roughly four months OpenAI shipped GPT-5.4, GPT-5.5 and then the GPT-5.6 family (Sol, Terra, Luna, GA 9 July 2026)  -  and **GPT-4o, GPT-5, GPT-5-mini and GPT-5-nano came off the published pricing page** in that period. Anthropic's lineup has moved more slowly.

For a solo operator running unattended client workflows, a model ID disappearing underneath you is a real maintenance event, and you will find out about it when a client's certificates stop processing. Mitigations, whichever provider you choose:

- **Pin a dated snapshot model ID**, never a floating alias. `gpt-5.6` is an alias for `gpt-5.6-sol` and will move under you.
- Put the model ID in `client_config`, not hardcoded in the node, so changing it is a database update rather than a workflow edit across every client.
- The canary certificate job in Section 14 catches a dead model ID the same way it catches expired OAuth. This is now a stronger reason to build it.

**④ Long-context billing tiers**

OpenAI bills requests above a 272K-token input threshold at roughly 2× input and 1.5× output *for the entire request*. Irrelevant for a one-page certificate  -  flagged only so you don't get surprised if you later extend this to leases.

**What does not change:** the two-branch design, the JSON schema, every validation rule, the approval gate, the dashboard, every fixture, the demo script, the honesty list, and the privacy answer (see 1.7).

**Recommendation:** use OpenAI through n8n's built-in OpenAI node V2 for the demo. Pin the model ID in `client_config`. Keep HTTP Request documented as a fallback path, not the default path.

You share your screen showing a clean dashboard listing eighteen of their vendors  -  except it's empty, because nothing has been processed yet. You say "I'm going to send this system a certificate the same way your vendors send you one," and you forward an email with a PDF attached. While it processes, you keep talking  -  you explain that this is exactly what lands in their inbox on a Tuesday. Then you switch back and the row has filled itself in: vendor name, carrier, policy number, general liability limit, and an expiry date, with the source PDF one click away for verification. The row is amber, and it says *expires in 20 days*. You drop in a second certificate; that row goes red and reads *expired 34 days ago*. Then you say "here's the part that matters"  -  and their phone buzzes. It's an approval email showing a drafted message to that vendor's insurance agent, with the policy number already filled in, and two buttons: **Approve** and **Decline**. You ask them to tap Approve. They do, on their own phone, and the email sends  -  from the configured client mailbox, to the agent, in front of them. Total elapsed time: under four minutes. Then you close: *"Send me ten of your actual vendor certificates and I'll run this over them. You'll have a real picture of where you stand tomorrow morning, and it costs you nothing to find out."*

The whole demo is engineered around one sentence you want them to say to themselves: **"I approved that. It didn't do it on its own."** That is what makes a stranger from another country safe to hire.

---

## 3. Architecture

### 3.1 Diagram

```
┌─────────────────────── WORKFLOW 1: INTAKE ────────────────────────┐
│                                                                    │
│  [Gmail Trigger]              [n8n Form Trigger]                   │
│   poll: 1 min                  instant, public URL                 │
│   download attachments         "Upload a certificate"              │
│         │                              │                           │
│         └──────────────┬───────────────┘                           │
│                        ▼                                           │
│              [Filter: PDF attachments only]                        │
│                        ▼                                           │
│              [Extract From File]  ← operation: Extract from PDF    │
│                        ▼                                           │
│              [IF: text.length > 200]                               │
│                   │           │                                    │
│              true │           │ false  (scanned / photographed)    │
│                   ▼           ▼                                    │
│        [OpenAI node V2]  [OpenAI node V2]                          │
│         text message      PDF File message (vision fallback)       │
│         JSON Schema       JSON Schema                              │
│                   │           │                                    │
│                   └─────┬─────┘                                    │
│                         ▼                                          │
│              [Code: validate + normalise]   ← deterministic, $0    │
│                         ▼                                          │
│              [IF: confidence == LOW  OR  hard validation failure]  │
│                   │                    │                           │
│              true │                    │ false                     │
│                   ▼                    ▼                           │
│        [Postgres: upsert       [Postgres: upsert                   │
│         status=NEEDS_REVIEW]    status=ON_FILE]                    │
│                   │                    │                           │
│                   └─────────┬──────────┘                           │
│                             ▼                                      │
│                  [Telegram: sendMessage]                           │
│                   "Certificate processed  -  <vendor>"               │
└────────────────────────────────────────────────────────────────────┘

┌────────────── WORKFLOW 2: DAILY WATCH + CHASE ─────────────────────┐
│                                                                    │
│  [Schedule Trigger 08:00]      [Manual Trigger]  ← demo uses this  │
│              └──────────┬──────────────┘                           │
│                         ▼                                          │
│         [Postgres: SELECT with days_to_expiry]                     │
│                         ▼                                          │
│  [Switch: NEVER_RECEIVED / EXPIRED / 14d / 30d / 60d /            │
│           RE-ATTEST (quarterly) / none]                            │
│                         ▼                                          │
│         [OpenAI node V2: draft vendor email]  ← short text call    │
│                         ▼                                          │
│  ╔═══════════════════════════════════════════════════╗             │
│  ║  [Gmail: Send and Wait for Response]   ← DEFAULT   ║  ◄── GATE 1 │
│  ║   Response Type: Approval                         ║      + the  │
│  ║   Approve / Decline buttons, in any mail client   ║      demo   │
│  ║   [Telegram: Send and Wait]  ← optional, if the   ║      moment │
│  ║    prospect already uses it                       ║             │
│  ║   Workflow PAUSES here either way                 ║             │
│  ╚═══════════════════════════════════════════════════╝             │
│                         ▼                                          │
│                  [IF: approved == true]                            │
│                   │                    │                           │
│              true │                    │ false                     │
│                   ▼                    ▼                           │
│         [Gmail: send]         [Postgres: log DECLINED]             │
│          to: producer                                              │
│          cc: vendor                                                │
│          from: CLIENT mailbox                                      │
│                   ▼                                                │
│         [Postgres: log outreach, set follow_up_due]                │
└────────────────────────────────────────────────────────────────────┘

┌──────────────── WORKFLOW 3: DASHBOARD ────────────────────────────┐
│  [Webhook GET /coi] → [Postgres SELECT] → [Code: build HTML]      │
│                     → [Respond to Webhook: text/html]             │
│  Self-refreshing every 5s. Red / amber / green rows.              │
└────────────────────────────────────────────────────────────────────┘
```

### 3.2 Where the human gates sit

| # | Gate | What it prevents |
|---|---|---|
| 1 | **Email (or Telegram) approval before any vendor email sends** | The system never contacts a third party on its own. This is the one that matters  -  it's also the demo's best moment. **Default to email approval:** n8n's `Send and Wait for Response` renders the same Approve/Decline buttons inside an ordinary email, so it works in any mail client with no app install and no account creation. Telegram has low US business penetration  -  do not make your demo's emotional peak depend on a prospect installing an app. Keep Telegram configured as a bonus for the minority who already use it. |
| 2 | **LOW confidence or failed validation → `NEEDS_REVIEW`, never stored as fact** | A bad extraction never becomes a silent wrong answer. |
| 3 | **No PMS credentials at all** | The system structurally cannot alter their system of record. Not "we chose not to"  -  it has no ability to. |
| 4 | **Dashboard states date facts only, never a verdict** | No screen anywhere says "compliant" or "verified". Enforced in the HTML template, not just in the prompt. |

### 3.3 Design decisions, and what I rejected

**Chosen: email/form in → Postgres → email out, with zero PMS integration.**

- **Rejected: any Buildium write-back.** Confirmed $400/mo Premium gate. Requiring a tier upgrade before you've been paid kills the deal, and you'd be selling against your own proposal.
- **Rejected: OCR via community node.** Native PDF vision on the model removes the dependency entirely and reads photographed certificates better. (Section 1.2.)
- **Rejected: Google Sheets as the store.** Adds a Google OAuth dependency and makes "where does my data live?" a worse answer. Postgres on your own box is both simpler and a better sales line.
- **Rejected: EspoCRM.** It's your CRM for your sales pipeline; it is not a COI register. Installing it here buys you a UI you can't tune for a 90-second demo, plus an extra service to keep alive on stage.
- **Rejected: NocoDB / Metabase / Appsmith dashboards.** Same reasoning. A single webhook-served HTML page has zero licence questions, zero extra containers, and looks like *your product* instead of somebody's admin panel. In a demo, controlling every pixel is worth more than any feature these give you.
- **Rejected: n8n Data Table node.** Genuinely appealing  -  native storage, no external DB. I confirmed the node exists but could not verify its query semantics well enough to commit a live demo to it. Postgres is the known quantity. Revisit for v2.
- **Rejected: IMAP Email Trigger as the live demo path.** Kept in the build for realism, but see Section 9  -  polling latency is a demo-killer, and the fix is a matter of sequencing rather than architecture.

---

## 4. Tech stack

| Component | What it does | Cost | Licence | Why it beat the alternative |
|---|---|---|---|---|
| **n8n (self-hosted, Docker)** | Orchestration | Free | Sustainable Use License  -  see 1.4 | Already your stack. Native HITL primitive is the deciding factor. |
| **PostgreSQL 16 (Docker)** | Vendor + policy store | Free | PostgreSQL License | Real SQL for date bucketing; no third-party account; best answer to "where does our data live". Beat Sheets, Airtable, Data Table. |
| **Gmail Trigger** (`n8n-nodes-base.gmailtrigger`) | Watches `coi@` inbox | Free | Core node | OAuth is more reliable than IMAP app-passwords and the node exposes attachment download cleanly. |
| **Email Trigger (IMAP)** (`n8n-nodes-base.emailimap`) | Alternative ingest for non-Google clients | Free | Core node | Build it, keep it disabled for the demo. Needed for Outlook/M365 clients later. |
| **n8n Form Trigger** (`n8n-nodes-base.formtrigger`) | Instant upload page | Free | Core node | Zero-latency ingest for the live demo, and the thing you hand the prospect to try themselves. |
| **Extract From File** (`n8n-nodes-base.extractfromfile`) | PDF text layer extraction | Free | Core node | Replaced Read PDF at v1.21. Confirmed current. |
| **OpenAI node V2** (`n8n-nodes-langchain.openai`) | Calls the model for extraction and drafting | Free | Core node | Current n8n supports the Responses API, PDF File message input, and JSON Schema output format. This is now the default model node for the OpenAI build. |
| **HTTP Request** (`n8n-nodes-base.httprequest`) | Fallback model API call path | Free | Core node | Keep only as a fallback if the installed n8n version is older than 1.117.0, if the OpenAI node cannot expose a required setting, or if you switch to Anthropic. |
| **Code** (`n8n-nodes-base.code`) | Validation, date maths, HTML build | Free | Core node | Deterministic checks cost zero tokens and catch most model errors. |
| **Postgres node** (`n8n-nodes-base.postgres`) | Upsert / select | Free | Core node | |
| **Switch / IF / Filter** | Routing | Free | Core nodes | |
| **Telegram** (`n8n-nodes-base.telegram`) | Optional manager alerts + optional approval gate | Free | Core node | Free Bot API and no A2P registration. Use for alerts or for prospects who already use Telegram; do not make it the default approval path. |
| **Gmail node** (`n8n-nodes-base.gmail`) | Sends approved vendor emails | Free | Core node | Supports threading headers (the Send Email SMTP node does not)  -  matters for follow-ups landing in the same thread. |
| **Send Email / SMTP node** (`n8n-nodes-base.sendemail`) | Generic SMTP fallback | Free | Core node | Not required for the Gmail demo. Use only for non-Gmail clients when no native mail node is available; it does not support threading headers. |
| **Webhook + Respond to Webhook** | Serves the dashboard | Free | Core nodes | |
| **Model  -  Anthropic option:** Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) | Extraction + email drafting | $1 / $5 per MTok | Commercial terms | Cheapest current-generation Claude. Good structured extraction, reads scanned PDFs via vision. |
| **Model  -  OpenAI option:** GPT-5.4 Mini (`gpt-5.4-mini`) | Same | $0.75 / $4.50 per MTok | Commercial terms | Closest equivalent tier, marginally cheaper, and unlocks strict Structured Outputs. **Pin the dated snapshot ID, not the alias.** |
| **Escalation  -  Anthropic:** Claude Sonnet 5 (`claude-sonnet-5`) | If a fixture repeatedly fails on the cheap tier | $2 / $10 per MTok (intro through 31 Aug 2026, then $3 / $15) | Commercial terms | Only for a specific failing fixture. Not a default. |
| **Escalation  -  OpenAI:** GPT-5.4 (`gpt-5.4`) | Same | $2.50 / $15 per MTok | Commercial terms | Same rule. GPT-5.6 Terra ($2.50/$15) or Luna ($1/$6) are alternatives  -  verify on the live pricing page, this lineup moves fast. |

**Do not use the cheapest tier available.** GPT-5.4 Nano ($0.20/$1.25) and GPT-4.1 Nano ($0.10/$0.40) are tempting, and they are probably fine on the *text* branch. They are the wrong call on the **vision** branch, where reading a skewed phone photo of a certificate is the whole job. The saving is under a cent per certificate. Use one model for both branches so you have one thing to debug.
| **ReportLab** (Python) | Generates synthetic test fixtures | Free | BSD | Lets you script twelve fixtures from a JSON spec instead of hand-making PDFs. |
| **pdf2image / Pillow** | Rasterises a fixture to fake a scan | Free | BSD-like / HPND | One fixture only. |

### Model tier assignment

| Step | Model | Rationale |
|---|---|---|
| Certificate → JSON (text branch) | **OpenAI cheap tier** (GPT-5.4 Mini or current equivalent) | ~1,200 input tokens of tabular text. Quality is verifiable against the source document on screen, but the task is extraction, not judgement. |
| Certificate → JSON (vision branch) | **Same cheap tier** | Higher token count per page; still fractions of a cent. Same model as the text branch so there's one thing to debug. |
| Is this even a certificate? | **No model.** Code node regex on extracted text | Free, instant, deterministic. Don't spend a classification call on this. |
| Days-to-expiry bucketing | **No model.** SQL + Code node | Never let a model do date arithmetic. |
| Vendor email drafting | **Same OpenAI cheap tier** | Short output (~150 tokens), visible to the prospect, but it's a templated business email. You review every one at the approval gate anyway. |

**Cost-risk flag:** nothing here repeatedly processes long documents. A certificate is one page, ~800-1,500 tokens. If you later extend to leases or management agreements (20,000+ tokens), revisit  -  that is where caching and cheaper tiers start to matter. For this product they don't.

---

## 5. Data model

### 5.1 Postgres schema

```sql
CREATE TABLE vendors (
  id                 SERIAL PRIMARY KEY,
  legal_name         TEXT NOT NULL,
  normalised_name    TEXT NOT NULL UNIQUE,  -- lowercased, punctuation stripped, for matching
  trade              TEXT,                   -- 'Plumbing', 'HVAC', etc. Manually seeded.
  wc_exempt          BOOLEAN DEFAULT false,  -- sole proprietors are WC-exempt in many states
  chase_paused       BOOLEAN DEFAULT false,  -- set on escalation; stops automated reminders
  last_attested_at   DATE,                   -- last time coverage was re-confirmed
  contact_email      TEXT,
  producer_name      TEXT,
  producer_email     TEXT,
  producer_phone     TEXT,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE certificates (
  id                    SERIAL PRIMARY KEY,
  vendor_id             INT REFERENCES vendors(id),
  source                TEXT,          -- 'email' | 'form'
  source_ref            TEXT,          -- message id or submission id
  original_filename     TEXT,
  stored_path           TEXT,          -- path to retained PDF
  certificate_date      DATE,
  certificate_holder    TEXT,
  holder_match          BOOLEAN,       -- fuzzy match vs client legal name
  extraction_confidence TEXT,          -- HIGH | MEDIUM | LOW
  extraction_method     TEXT,          -- 'text' | 'vision'
  raw_extraction        JSONB,         -- full model output, always retained
  validation_flags      JSONB,         -- array of flag codes, see 5.3
  status                TEXT,          -- ON_FILE | NEEDS_REVIEW | SUPERSEDED
                                       -- | CANCELLED | NON_RENEWED  (both human-set only)
  cancellation_notice_wording TEXT,    -- verbatim from Description of Operations, if present
  status_set_by         TEXT,          -- 'system' | user identifier, for CANCELLED/NON_RENEWED
  status_note           TEXT,          -- why a human overrode the status
  received_at           TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE coverages (
  id                 SERIAL PRIMARY KEY,
  certificate_id     INT REFERENCES certificates(id) ON DELETE CASCADE,
  coverage_type      TEXT,   -- GENERAL_LIABILITY | AUTO | UMBRELLA | WORKERS_COMP | OTHER
  insurer_name       TEXT,
  naic               TEXT,
  policy_number      TEXT,
  effective_date     DATE,
  expiration_date    DATE,
  each_occurrence    NUMERIC,
  general_aggregate  NUMERIC,
  addl_insd_asserted BOOLEAN,   -- NOTE THE FIELD NAME. See section 11.
  subr_wvd_asserted  BOOLEAN
);

CREATE TABLE outreach_log (
  id              SERIAL PRIMARY KEY,
  vendor_id       INT REFERENCES vendors(id),
  certificate_id  INT REFERENCES certificates(id),
  bucket          TEXT,      -- '60d' | '30d' | '14d' | 'EXPIRED'
  drafted_body    TEXT,
  approved        BOOLEAN,
  approved_at     TIMESTAMPTZ,
  sent_at         TIMESTAMPTZ,
  recipient       TEXT,
  follow_up_due   DATE,
  escalated       BOOLEAN DEFAULT false
);

CREATE TABLE client_config (
  key    TEXT PRIMARY KEY,
  value  TEXT
);
-- seed: min_each_occurrence, min_general_aggregate, from_mailbox,
--       reminder_days ('60,30,14,0'), reattest_days ('90'),
--       approval_channel ('email' | 'telegram'), telegram_chat_id, model_id

-- Accepted certificate holder entities. A PM company managing for 40 owners often
-- needs certificates naming individual owner LLCs, not the management company.
-- A single client_legal_name string flags all of those as mismatches.
CREATE TABLE holder_entities (
  id           SERIAL PRIMARY KEY,
  legal_name   TEXT NOT NULL,
  is_primary   BOOLEAN DEFAULT false
);

-- Per-trade insurance minimums. Roofers routinely need higher limits than
-- landscapers; one global number generates false flags in both directions.
CREATE TABLE trade_requirements (
  trade                 TEXT PRIMARY KEY,
  min_each_occurrence   NUMERIC,
  min_general_aggregate NUMERIC,
  wc_required           BOOLEAN DEFAULT true
);
```

**Design note that matters:** the field is `addl_insd_asserted`, never `additional_insured`. A schema that says `additional_insured` invites you  -  and later a client  -  to read it as a fact. It is a checkbox someone ticked on a form. Encoding the honesty in the column name is free, and it stops you drifting into overclaiming eighteen months from now when you've forgotten why you cared.

### 5.2 Extraction schema (exact JSON the model must return)

```json
{
  "is_certificate_of_insurance": true,
  "vendor_legal_name": "string",
  "vendor_address": "string | null",
  "producer_name": "string | null",
  "producer_email": "string | null",
  "producer_phone": "string | null",
  "certificate_date": "YYYY-MM-DD | null",
  "certificate_holder": "string | null",
  "coverages": [
    {
      "type": "GENERAL_LIABILITY | AUTO | UMBRELLA | WORKERS_COMP | OTHER",
      "insurer_name": "string | null",
      "naic": "string | null",
      "policy_number": "string | null",
      "effective_date": "YYYY-MM-DD | null",
      "expiration_date": "YYYY-MM-DD | null",
      "each_occurrence": "number | null",
      "general_aggregate": "number | null",
      "addl_insd_asserted": "boolean",
      "subr_wvd_asserted": "boolean"
    }
  ],
  "description_of_operations": "string | null",
  "cancellation_notice_wording": "string | null",
  "extraction_confidence": "HIGH | MEDIUM | LOW",
  "confidence_reason": "string | null"
}
```

`confidence_reason` is not decoration  -  when a prospect asks "what happens when it gets one wrong?", you open a `NEEDS_REVIEW` row and it says *"policy expiration date partially obscured by scan artefact"* in plain English. That answer is worth more than a demo feature.

**If you're on OpenAI, wrap this in Structured Outputs.** Send it as `response_format: {"type":"json_schema","json_schema":{"name":"coi_extraction","strict":true,"schema":{...}}}`. Three requirements strict mode imposes:

- Every property must be listed in `required`. Nothing is optional.
- `additionalProperties: false` on every object, including the nested `coverages` items.
- Fields that can be absent are typed as a union: `"type": ["string","null"]` rather than omitted. The schema above is already written this way, so it converts directly.

Also handle the refusal path: check `response.choices[0].message.refusal` before parsing. If it's non-null, route to `NEEDS_REVIEW` with flag `MODEL_REFUSED` rather than throwing  -  a refusal on a certificate is unlikely but a hard crash mid-demo is not a risk worth carrying.

On Anthropic there is no strict mode. Keep the "Return ONLY valid JSON" instruction in the system prompt, and keep a `JSON.parse` try/catch in the Code node that routes parse failures to `NEEDS_REVIEW`. Add one re-prompt retry before giving up.

### 5.3 System prompt for extraction

```
You extract structured data from certificates of liability insurance.

Return ONLY valid JSON matching the schema provided. No preamble, no
markdown fences, no commentary.

RULES

1. Transcribe only. Never infer, complete, or correct a value that is not
   legible in the document. If a field is absent or unreadable, return null.
   A null is always better than a guess.

2. Dates: source documents use MM/DD/YYYY. Return YYYY-MM-DD. If a date is
   ambiguous or partially illegible, return null and lower the confidence.

3. Limits: return integers without currency symbols or separators.
   "$1,000,000" becomes 1000000.

4. ADDL INSD and SUBR WVD are checkbox columns. Report only whether a mark
   is present, as a boolean. These are assertions on a form, not facts about
   coverage. Do not interpret them.

5. One object in "coverages" per coverage line present. Do not invent lines
   that are absent. Coverage lines commonly present: Commercial General
   Liability, Automobile Liability, Umbrella/Excess, Workers Compensation
   and Employers Liability.

6. Field order and layout vary between form revisions and between carriers.
   Locate fields by their labels, not by position.

7. Set is_certificate_of_insurance to false if this document is not a
   certificate of liability insurance. Return nulls for all other fields.

8. If the Description of Operations box contains wording about notice of
   cancellation to the certificate holder (for example "30 days written
   notice"), copy it verbatim into cancellation_notice_wording. Copy it
   exactly. Do not summarise it, and do not treat it as a promise that
   notice will be given  -  you are recording that a sentence appears on a
   form, nothing more.

CONFIDENCE

HIGH    -  every field you returned was clearly legible.
MEDIUM  -  the document is legible but at least one field required judgement,
         or the layout is non-standard.
LOW     -  the scan is poor, the document is rotated or cropped, or you are
         unsure about any date or limit.

When you set MEDIUM or LOW, state why in confidence_reason, in one short
sentence a non-technical person would understand.

Bias toward LOW. A human reviews everything you mark LOW. Nobody reviews
what you mark HIGH.
```

That last line is doing real work. Without it, models mark almost everything HIGH.

**On OpenAI with strict Structured Outputs, delete the first paragraph** ("Return ONLY valid JSON... no commentary")  -  constrained decoding makes it redundant, and it costs you tokens on every call. Keep rules 1-7 and the whole CONFIDENCE block: those govern *what the model says*, which no schema can enforce. The schema guarantees you get a well-formed `expiration_date` field; only the prompt stops the model inventing a plausible date to fill it. **Structured Outputs solves the shape of the answer, never its truthfulness**  -  that distinction matters more here than anywhere else in the build.

### 5.4 Validation rules (Code node  -  deterministic, zero tokens)

Run after extraction, before storage. Each produces a flag code stored in `validation_flags`.

| # | Rule | Flag | Severity |
|---|---|---|---|
| 1 | `expiration_date > effective_date` for every coverage | `DATE_INVERTED` | Hard  -  force `NEEDS_REVIEW` |
| 2 | All dates parse and fall within `certificate_date - 2y` to `+3y` | `DATE_IMPLAUSIBLE` | Hard |
| 3 | At least one `GENERAL_LIABILITY` line exists | `NO_GL_LINE` | Soft  -  store, flag on dashboard |
| 4 | `certificate_holder` fuzzy-matches `client_legal_name` (token-set ratio ≥ 0.80) | `HOLDER_MISMATCH` | Soft |
| 5 | GL `each_occurrence` ≥ `min_each_occurrence` | `LIMIT_BELOW_MINIMUM` | Soft |
| 6 | `extraction_confidence == LOW` | `LOW_CONFIDENCE` | Hard |
| 7 | `is_certificate_of_insurance == false` | `NOT_A_COI` | Hard  -  do not create a vendor record |
| 8 | Vendor already exists and new `certificate_date` is **older** than the one on file | `OLDER_THAN_ON_FILE` | Hard  -  do not overwrite |
| 9 | On supersede: `new.effective_date > old.expiration_date` | `COVERAGE_GAP` (record the day count) | Soft  -  but surface prominently |
| 10 | Rule 3 and WC checks are **suppressed** when `vendors.wc_exempt` is true |  -  | Suppression, not a flag |
| 11 | Limits compared against `trade_requirements` for the vendor's trade, falling back to the global default | `LIMIT_BELOW_MINIMUM` | Soft |
| 12 | Holder matched against **any** row in `holder_entities`, not one string | `HOLDER_MISMATCH` | Soft |
| 13 | Normalised name is a near-match to an existing vendor (0.80-0.94) rather than exact | `POSSIBLE_DUPLICATE_VENDOR` | Hard  -  create a review item, never auto-merge |

Rule 8 is the one that gets forgotten and then bites in production: a vendor re-sends last year's certificate, and a naive upsert silently replaces good data with stale data. Handle it now; it costs you four lines.

**Rule 9 is the one worth demoing.** Old policy expires 1 March, replacement certificate is effective 15 March  -  that is a fourteen-day window in which the vendor was uninsured on your client's properties, and without this check the dashboard simply turns green and nobody ever knows. It is about twelve lines of code and it catches something a spreadsheet structurally cannot. Show it.

**Rule 10 exists to stop false alarms.** Sole proprietors are exempt from workers' compensation in many states and carry an exemption certificate rather than a policy. Without the suppression, your system confidently flags perfectly legitimate vendors as deficient  -  and nothing destroys trust in an automated system faster than confident wrong alerts. Set `wc_exempt` during onboarding.

**Rule 13 protects you from your own matching.** "Mercer Plumbing" and "Mercer Plumbing & Heating" may be two different companies. A `UNIQUE` constraint on `normalised_name` turns that ambiguity into either a crash or a silent wrong merge, and a silent wrong merge means one company's certificate is filed against another company's record. On a near-match, ask a human.

**Superseding logic:** when a valid newer certificate arrives for an existing vendor, set the previous certificate's status to `SUPERSEDED` rather than deleting it. The audit trail is the product.

### 5.5 Shrinking the mid-term blind window

You cannot detect mid-term cancellation from a certificate  -  nobody can, including the enterprise platforms (Section 11). But you can make the blind window much smaller, using machinery you have already built and at zero additional cost.

**① Quarterly re-attestation instead of annual expiry-chasing.** Add `reattest_days` to `client_config`, default `90`, and a `RE_ATTEST` branch on the Switch that fires when `now() - last_attested_at > reattest_days` and the certificate is not already inside a reminder bucket. The drafted email is a short, friendly note to the producer asking them to confirm the policy remains in force, or send a current certificate if anything has changed.

If a policy is cancelled in month two, annual chasing finds out in month twelve. Quarterly re-attestation finds out by month three. **That is not monitoring, and you must not describe it as monitoring**  -  it is asking more often. But it takes a twelve-month exposure window down to three, it costs one config value and one Switch branch, and it is completely honest.

It also has a commercial benefit worth noticing: it gives your client four visible touchpoints a year instead of one, which makes a $250/month retainer feel like a service rather than a dormant script.

**② Record the cancellation-notice wording as a fact about the paperwork.** Extract `cancellation_notice_wording` verbatim (schema 5.2, prompt rule 8) and surface it on the dashboard as a plain note: *"Certificate states 30 days notice of cancellation."*

Then say exactly this to the client, and put it in the scope document:

> *"That sentence is on the form. It does not mean your client will actually be notified. Since the 2010 ACORD revision, notice goes to the insured under the policy terms, not to the certificate holder. The only thing that gets you real notice is being scheduled onto the vendor's policy by endorsement  -  and most national carriers no longer offer that."*

Recording the wording is useful; treating it as a promise is the exact overclaim that would end you. This is why the field is named `cancellation_notice_wording` and not `notice_guaranteed_days`. Same discipline as `addl_insd_asserted`.

**③ Flag when it's absent, for the vendors that matter.** For high-risk trades (roofing, electrical, anything structural), the absence of any cancellation-notice wording is worth surfacing to the client so they can raise it with their broker at contract renewal. That is a genuinely useful observation and it stays entirely inside your rules: you are reporting what the document says, never what the coverage does.

---

## 6. Build plan

Four phases, in dependency order. Each step states what "done" looks like, so Claude Code can act on it directly and you can verify it independently.

Work the phases in sequence  -  each depends on the one before it. Within a phase, steps are ordered but several are independent and can be reordered if something blocks.

### Phase 1  -  Infrastructure, storage, extraction

**1.1** Create `docker-compose.yml` with three services: `n8n` (image `docker.n8n.io/n8nio/n8n`), `postgres:16`, and a named volume for each. Put n8n behind Caddy or a Cloudflare Tunnel for HTTPS.
→ **Done when:** `docker compose up -d` brings all services healthy and n8n loads over HTTPS at a public hostname.

**1.2** Set n8n environment variables: `WEBHOOK_URL` and `N8N_HOST` to the public HTTPS hostname, `GENERIC_TIMEZONE` to the client's timezone (use `America/New_York` for the demo), `N8N_ENCRYPTION_KEY` to a generated secret.
→ **Done when:** a test Webhook node returns a public URL on the real hostname, not `localhost`. **Verify this by loading the URL on your phone over mobile data, not wifi.** If this is wrong, the approval button fails on the call and you will not know why.

**1.3** Apply the Section 5.1 schema. Seed `client_config` with `min_each_occurrence = 1000000`, `min_general_aggregate = 2000000`, `reminder_days = '60,30,14,0'`, `reattest_days = '90'`, `approval_channel = 'email'`. Seed `holder_entities` with the client's management company plus two owner LLCs. Seed `trade_requirements` for at least Roofing (higher limits), Landscaping (lower), and a default row.
→ **Done when:** `\dt` lists seven tables, and a vendor's applicable minimum resolves from `trade_requirements` with a fallback to the global default.

**1.4** Seed `vendors`. **Use the prospect's real vendor names wherever you can get them**  -  ask in the scheduling email: *"send me the names of your regular vendors so I can set the demo up against your actual list, nothing else needed."* Most will, it costs them a minute, and none of it is sensitive. Fall back to 18 fictional vendors only if they don't reply. Set `wc_exempt = true` on one sole-proprietor-style vendor. No certificates yet  -  the register starts populated with **names** and empty of **documents**.
→ **Done when:** 18 rows, each with a trade and a producer email, and the dashboard shows 18 grey "No certificate on file" rows.

**Why this is the highest-leverage step in the build:** a prospect seeing *their own* eighteen vendor names on screen, four of them grey, is a categorically different experience from seeing a sample. It stops being a demo of your software and becomes a picture of their business. It also removes the "whose vendors are those?" question that makes a staged demo visible.

**1.5** Create the model-provider credential in n8n as an **OpenAI API** credential. Use n8n's built-in **OpenAI node V2**. Generate an API key with a **spend limit of $10** set in the provider console. Store the model ID in `client_config` as `model_id`, not hardcoded in workflow notes or duplicated across nodes.
→ **Done when:** a trivial OpenAI node call succeeds, and changing `model_id` in Postgres changes which model the workflow is configured to call.

**1.6** Build the **text-branch extraction call** with OpenAI node V2: Resource `Text`, Operation `Generate a Model Response`, message type `Text`, output format `JSON Schema`, max output around 1500 tokens, system prompt from 5.3, user content = extracted PDF text.
→ **Done when:** feeding fixture 1's text returns schema-valid JSON with the correct vendor name and all four dates.

**1.7** Build the **vision-branch extraction call** with OpenAI node V2: same operation, but the user message includes a **File** message using the PDF binary from the previous node. Keep the same JSON Schema output.
→ **Done when:** fixture 4 (the fake scan) returns schema-valid JSON with the correct expiry date.

**1.7b** Keep an **HTTP Request fallback note**, not a default node: if the installed n8n version is older than 1.117.0 or the OpenAI node cannot express the required PDF/JSON Schema settings, recreate the two model calls with HTTP Request against the OpenAI API. If switching to Anthropic, use HTTP Request with prompt-only JSON and defensive parsing.
→ **Done when:** the fallback condition is documented and the default workflow still uses the OpenAI node.

**1.8** Write the Code node implementing all validation rules from 5.4, plus name normalisation for vendor matching.
→ **Done when:** unit-tested against hand-written JSON inputs covering every flag, including rule 8.

### Phase 2  -  Intake workflow end to end

**2.1** Build Workflow 1 skeleton: Form Trigger → Filter (PDF only) → Extract From File → IF (text length > 200) → the two OpenAI node V2 branches → Code (validate) → IF (hard flags) → Postgres upsert (two paths) → manager notice.
→ **Done when:** uploading fixture 1 through the form URL creates one `vendors` row, one `certificates` row with `status = ON_FILE`, four `coverages` rows, and a manager notice arrives through the configured notice channel.

**2.2** Add the Gmail Trigger as a second entry point into the same Filter node. Poll every minute, download attachments, filter to a dedicated label or address.
→ **Done when:** emailing fixture 2 to the demo inbox produces the same result within ~60 seconds.

**2.2b** Add the Email Trigger (IMAP) as a disabled fallback intake path for non-Google clients. It should feed into the same Filter node and downstream processing, but it is not the live demo path.
→ **Done when:** the disabled IMAP path exists and can be enabled later without changing extraction, validation, or storage nodes.

**2.3** Implement the supersede path: existing vendor + newer certificate date → mark old certificate `SUPERSEDED`, insert new. Existing vendor + older certificate → flag `OLDER_THAN_ON_FILE`, do not overwrite.
→ **Done when:** fixture 12 (renewal) supersedes correctly, and re-uploading fixture 1 afterwards does *not* regress the record.

**2.4** Handle multi-attachment emails  -  one email, two PDFs, both processed independently.
→ **Done when:** fixture 10 produces two certificate rows.

**2.5** Handle the non-certificate case: `NOT_A_COI` → manager notice saying it was ignored, no vendor record created.
→ **Done when:** fixture 11 creates zero rows and produces a clear manager notice.

**2.6** Store the original PDF to a mounted volume, record `stored_path`, and expose it via a webhook route so the dashboard can link to it.
→ **Done when:** clicking a dashboard row opens the source PDF in a new tab.

### Phase 3  -  Watch, chase, approve, dashboard

**3.1** Build Workflow 2: Schedule Trigger (08:00) **and** Manual Trigger both into a Postgres SELECT computing `days_to_expiry` in SQL against the **earliest** expiring coverage per vendor.
→ **Done when:** the query returns one row per vendor with correct bucket assignment, verified against hand-calculated dates.

**3.2** Add the Switch node. **Order matters  -  put `NEVER_RECEIVED` first.**

Branches: `NEVER_RECEIVED` (no certificate row exists for the vendor) → `EXPIRED` → `14d` → `30d` → `60d` → `RE_ATTEST` (per 5.5) → `none` (NoOp). Suppress every branch when `vendors.chase_paused` is true.

→ **Done when:** the seeded fixtures land in the buckets you expect, **a vendor with zero certificates enters `NEVER_RECEIVED` rather than falling through to NoOp**, and a `chase_paused` vendor produces nothing.

⚠️ **This ordering is a real bug fix, not a preference.** A vendor with no certificate has a NULL expiry date. Bucket on days-to-expiry alone and that vendor silently falls through to `none` and is never contacted  -  meaning the system ignores your client's *most* non-compliant vendors while diligently chasing the ones who are merely close to renewal. A prospect finds this within minutes of real use, and it is the exact failure the product claims to prevent. Give `NEVER_RECEIVED` its own email template ("we don't have a current certificate on file for you").

**3.3** Build the email-drafting OpenAI node call. Prompt it to write a short, polite renewal request addressed to the **producer** (the agent), copying the vendor, referencing the policy number and expiry date, and requesting an updated certificate naming the client as certificate holder.
→ **Done when:** the draft reads like a human wrote it, is under 120 words, contains the correct policy number, and contains **no claim about coverage status**.

**3.4** Add the approval gate. **Default to the Gmail node's `Send and Wait for Response` operation**, Response Type `Approval`, Type of Approval `Approve and Disapprove`. Message body: vendor name, expiry date, recipient address, and the full drafted email. Set **Limit Wait Time** to 24 hours so a forgotten approval doesn't wedge an execution forever.

Build the Telegram equivalent as a parallel branch selected by `client_config.approval_channel`, for the minority of prospects who already use Telegram.

→ **Done when:** running the workflow puts an email with two working buttons in your inbox, tapping Approve resumes the execution, **and you have tested it on a phone you have not logged into n8n on.**

**Why email is the default:** Telegram has low US business penetration. Asking a property manager to install an app before a sales call is real friction, and some will simply decline  -  which kills the demo's best moment. Email approval renders the same buttons in any mail client, needs no install and no account, and is what a real client would actually use day to day, so it survives into production instead of being a demo gimmick. Slightly less theatrical, far more reliable.

**3.5** Add the post-approval branch: IF approved → Gmail send → Postgres log with `sent_at` and `follow_up_due = now() + 7 days`. IF declined → Postgres log `approved = false`.
→ **Done when:** approving actually delivers an email to a test address and writes the log row.

**3.6** Add escalation: a second scheduled pass finds `outreach_log` rows where `follow_up_due < now()` and no newer certificate has arrived, alerts the manager, and **sets `vendors.chase_paused = true`**. Two ignored requests escalate to a human; they do not escalate to more automation.
→ **Done when:** back-dating a `follow_up_due` triggers a manager alert, and the vendor receives no further automated reminders until a human clears the pause.

**The pause is the point.** A system that keeps emailing a vendor after a human has taken the conversation over makes your client look disorganised to their own vendor  -  which is the opposite of what they are paying for.

**3.6b** Add the **non-PDF reply handler**: any mail arriving at the intake address with no PDF attachment routes to a manager notice rather than being silently dropped. Detect two specific cases and label them  -  a plain-text reply ("I'll get that to you next week"), and a **portal-link email** ("download your certificate here"), which larger agencies increasingly send. Do not attempt to fetch the link; hand it to a human.
→ **Done when:** a text-only reply and a link-only email both produce a clear manager notice naming the vendor.

**3.6c** Add a **manual status override** so a human can mark a certificate `CANCELLED` or `NON_RENEWED` with a note and an attribution. Given that mid-term cancellation is undetectable from the document (Section 11), this is the one place the system can capture that fact once a person learns it.
→ **Done when:** setting the status turns the dashboard row red with the human's note visible.

**3.7** Build Workflow 3, the dashboard. Webhook (GET, path `/coi`) → Postgres SELECT → Code node returning a complete HTML document → Respond to Webhook with `Content-Type: text/html`.
→ **Done when:** the URL renders all 18 vendors with correct status colours and refreshes itself every 5 seconds.

**3.8** Dashboard content rules  -  enforce in the template:
- Columns: Vendor, Trade, Carrier, Policy #, GL Limit, Expires, Status, Source
- Status strings are **date facts only**: `Current until 14 Mar 2027`, `Expires in 20 days`, `Expired 34 days ago`, `No certificate on file`, `Needs review`
- The words *compliant*, *verified*, *covered*, *approved* appear **nowhere** in the template
- Amber at ≤30 days, red at ≤0 or `NEEDS_REVIEW`, grey for no certificate
- Every row links to its source PDF
→ **Done when:** a text search of the rendered HTML for those four forbidden words returns nothing.

### Phase 4  -  Fixtures, hardening, rehearsal

**4.1** Generate the full fixture set (Section 7) with the ReportLab script.
→ **Done when:** every fixture exists, each visually plausible, each watermarked `SPECIMEN`, and the whole set regenerates from the JSON spec with one command.

**4.2** Run every fixture through the pipeline and record actual behaviour in a results table.
→ **Done when:** each fixture's outcome matches its expected outcome, or you have consciously accepted the deviation and know what you'll say about it.

**4.3** Reset script: truncate `certificates`, `coverages`, `outreach_log`; leave `vendors` and `client_config`. Bind it to a single command.
→ **Done when:** one command returns the demo to its opening state in under two seconds. **You will need this mid-call at some point.**

**4.4** Record a 4-minute screen capture of a perfect run, including the phone. This is your fallback if the live demo fails (Section 10) and your follow-up asset.
→ **Done when:** the video exists, is under 100MB, and is uploaded somewhere you can link to from your phone.

**4.5** Rehearse the full script five times. Twice with your wifi off mid-demo, to practise the recovery.
→ **Done when:** you can run it in under four minutes without looking at notes, and you have said the failure line out loud enough times that it sounds relaxed.

---

## 7. Test fixtures

You have no client data, so every fixture is synthetic. Generate them with a ReportLab script driven by a JSON spec so you can regenerate the whole set after any change.

**Construction rules for every fixture:** layout similar to a standard certificate but not a facsimile; no ACORD logo or copyright notice; visible `SPECIMEN  -  SYNTHETIC TEST DOCUMENT` watermark; fictional carriers (Northgate Mutual, Cardinal Casualty, Ironvale Indemnity); fictional vendors; certificate holder `Harbourline Property Management LLC` except where the fixture tests otherwise.

| # | Fixture | What it tests | Expected outcome |
|---|---|---|---|
| 1 | **Clean and current.** GL + Auto + WC, expires in 8 months, limits $1M/$2M | Happy path, multi-coverage parse | `ON_FILE`, green, confidence HIGH |
| 2 | **Expiring in 20 days.** Single GL line | The amber state  -  **demo hero** | `ON_FILE`, amber, enters 30d bucket |
| 3 | **Expired 34 days ago** | The red state  -  **demo hero** | `ON_FILE`, red, enters EXPIRED bucket |
| 4 | **Scanned.** Fixture 1 rasterised at 150dpi, rotated 1.5°, grey background, slight JPEG artefacting | Vision fallback branch | Routes to vision branch, extracts correctly, confidence MEDIUM |
| 5 | **Inverted dates.** Expiration precedes effective on the GL line | Validation rule 1 | `NEEDS_REVIEW`, flag `DATE_INVERTED` |
| 6 | **Wrong certificate holder.** Names "Beacon Ridge Realty" instead of the client | Validation rule 4 | `ON_FILE` with flag `HOLDER_MISMATCH` surfaced on dashboard |
| 7 | **Limits below minimum.** GL each-occurrence $300,000 | Validation rule 5 | `ON_FILE` with flag `LIMIT_BELOW_MINIMUM` |
| 8 | **Four coverage lines, four different expiry dates** spanning 3 months | Earliest-expiry logic | Dashboard shows the **earliest** date, not the GL date |
| 9 | **No GL line.** Auto + WC only | Validation rule 3 | `ON_FILE` with flag `NO_GL_LINE` |
| 10 | **Two certificates in one email** | Multi-attachment handling | Two independent certificate rows |
| 11 | **Not a certificate.** A W-9-style form | Classification / rejection | Zero rows created, `NOT_A_COI` manager notice |
| 12 | **Renewal for an existing vendor.** Same vendor as fixture 2, certificate dated later, expiry 12 months out | Supersede logic, rule 8 | Old certificate → `SUPERSEDED`, new → `ON_FILE`, row turns green |
| 13 | **Renewal with a coverage gap.** Replacement for fixture 3; old policy expired 1 Mar, new one effective 15 Mar | Validation rule 9  -  **the sleeper demo moment** | `ON_FILE` with `COVERAGE_GAP`, dashboard reads "14-day gap in March" |
| 14 | **No fixture  -  a vendor with nothing.** Leave 4 seeded vendors with zero certificates | `NEVER_RECEIVED` bucket | All four enter the chase queue on the first scheduled run |
| 15 | **Sole proprietor, no workers' comp.** GL only, `wc_exempt = true` on the vendor | Rule 10 suppression | `ON_FILE`, **no** WC flag raised |
| 16 | **Certificate naming an owner LLC**, not the management company, where the LLC is in `holder_entities` | Rule 12 | `ON_FILE`, **no** holder mismatch |
| 17 | **Near-duplicate vendor.** "Mercer Plumbing & Heating" when "Mercer Plumbing" exists | Rule 13 | Review item created; **no** silent merge |
| 18 | **Password-protected PDF** | Graceful failure | `NEEDS_REVIEW` with a readable reason, not a crashed execution |
| 19 | **Portal-link email.** Body says "download your certificate here", no attachment | Step 3.6b | Manager notice naming the vendor; no fetch attempted |
| 20 | **Certificate with cancellation-notice wording** in Description of Operations | Prompt rule 8 | Wording captured verbatim and shown as a neutral note |

### The messy ones that make it feel real

Fixtures 4, 5, 6 and 12 are the ones that separate a demo from a toy. Four things to know:

**Fixture 4 (the scan)** is the one prospects mentally test you on, because half their vendors photograph certificates with a phone. Showing it work  -  and showing it *drop to MEDIUM confidence and say why*  -  is more persuasive than showing it work silently.

**Fixture 6 (wrong holder)** is the sleeper. Certificates naming the wrong entity are genuinely common, usually because an agent copied the previous job's template. Most managers have never thought about it. When your dashboard flags one, you have shown them a problem they didn't know they had, which is a different and better sales position than solving one they already knew about.

**Fixture 12 (renewal)** is the actual steady state. Everything else is the first week. If a prospect asks "what happens next year?"  -  and the good ones do  -  this is your answer.

**Fixture 11 (not a certificate)** matters because it is the honest answer to "what if someone sends it junk?" Showing the system decline to act is a trust-builder, not a weakness.

**Fixture 13 (coverage gap)** is the one nobody expects. A fourteen-day hole between an expiring policy and its replacement is invisible to a spreadsheet, invisible to Buildium's assignment warning, and invisible to a human eyeballing two PDFs six months apart. When your dashboard says *"14-day gap in March"*, you have shown the prospect something no process they currently own could have caught. Put it in the demo.

**Fixture 14 (the vendors with nothing)** is not really a fixture  -  it is the absence of one, and it is the most common real-world state. Four grey rows on an otherwise working register is the picture that sells.

**Fixture 15 (WC-exempt)** exists to prove the system doesn't cry wolf. A prospect who has ever used a compliance tool that flagged their reliable one-man handyman as non-compliant will care about this more than any feature.

---

## 8. UI

**Yes  -  build one screen. It materially improves the demo, and it's the cheapest thing in the plan.**

The reason isn't aesthetics. It's that the dashboard is what converts an abstract capability ("it reads certificates") into a felt absence ("I don't have this"). A prospect looking at a single screen showing eighteen of their own vendor names, with three rows red, understands their exposure faster than any explanation. Without it, you're showing JSON in an n8n execution log, and you look like a developer rather than a supplier.

### What to build

**One screen. No navigation, no login, no framework.**

A single HTML document generated by a Code node and served through a Webhook. Inline CSS. A `<meta http-equiv="refresh" content="5">` tag so it updates itself while you talk  -  you never click refresh, rows just change in front of them.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Vendor Insurance Register            Harbourline Property Mgmt LLC  │
│  18 vendors · 4 never received · 3 expired · 2 expiring in 30 days   │
│  1 needs review · 1 coverage gap                                     │
├──────────────────────────────────────────────────────────────────────┤
│ VENDOR              TRADE      CARRIER      GL LIMIT  EXPIRES        │
├──────────────────────────────────────────────────────────────────────┤
│ ● Mercer Plumbing   Plumbing   Northgate    $1M    Expired 34 days   │ red
│ ● Kessler HVAC      HVAC       Cardinal     $1M    Expires in 20 d   │ amber
│ ● Vaughn Electric   Electrical Ironvale     $1M    Current to 14 Mar │ green
│ ● Alder Landscaping Grounds     -              -       No certificate    │ grey
│ ● Rowan Roofing     Roofing    Northgate    $300k  Needs review      │ amber
│   ...                                                                │
└──────────────────────────────────────────────────────────────────────┘
```

**Rules the template must enforce:**
- Status text is a date fact, never a verdict. The words *compliant*, *verified*, *covered*, *approved* must not appear anywhere in the output.
- Every row links to its source PDF. When you say "you don't have to trust it  -  here's the document," you need that link to exist and work.
- Flags (`HOLDER_MISMATCH`, `LIMIT_BELOW_MINIMUM`, `COVERAGE_GAP`, `POSSIBLE_DUPLICATE_VENDOR`) render as a small amber note under the vendor name, not a separate column.
- `COVERAGE_GAP` gets its own header count  -  it is the most valuable thing on the screen and it should not be buried in a row.
- `cancellation_notice_wording`, when present, renders as a **neutral grey** note: *"Certificate states 30 days notice."* Never green, never a tick. It is a sentence on a form, not a protection.
- `NEVER_RECEIVED` rows are grey and sort to the **top**, not the bottom. The vendors you have nothing for are the ones worth looking at first.
- The counts in the header are computed, not hardcoded. You will re-run the demo and they must change.

### Why not something off the shelf

A generic admin panel  -  NocoDB, Metabase, EspoCRM  -  gives you filtering and sorting you don't need for a four-minute demo, and takes away the thing you do need: a screen that looks like a product someone built for property managers. One HTML page has no licence question, no extra container to keep alive on stage, and no chance of an unfamiliar UI surprising you mid-call.

---

## 9. The demo script

**Total runtime: 4 minutes 10 seconds of demo.** Budget 12-15 minutes for the call including discovery and the close.

**The strongest moment is at 3:05  -  the prospect taps Approve on their own phone.** Everything before it is setup for that. Do not move it earlier: they need to have seen the problem before they can appreciate the control.

### Before the call

- Reset script run. Dashboard shows 18 vendors  -  **their real vendor names** where you got the list  -  all "No certificate on file".
- Fixture 2 (expiring in 20 days) drafted as an email, ready to send, **not sent**.
- Fixture 3 (expired) open in a folder, ready to drag into the form.
- **Approval channel confirmed.** Default: their email, which you asked for when scheduling. Only use Telegram if they already use it. Phone on the desk, screen up, **on mobile data**, in frame if you're on video.
- Fixture 13 (coverage gap) queued as the third document.
- Fallback video open in a background tab.
- Second browser tab already on the dashboard URL.

### 0:00 - 0:35  -  Send first, talk second

> *"Before I show you anything, let me start something running in the background."*

Send the fixture 2 email. Then switch to the dashboard tab.

> *"That's a vendor certificate, sent to a monitored address, exactly the way one of your vendors or their agent would send it to you. It'll take about a minute. While it works  -  this is the register. Your eighteen vendors. Right now the system knows who they are and nothing else."*

Pause on the grey rows.

> *"Every one of these is grey because there's no certificate on file. Four of them will still be grey at the end of this call  -  and those four are the ones I'd want to look at first, because 'expiring soon' is a calendar problem and 'we've never had anything from them' is a different problem entirely."*

**Use their own vendor names out loud.** *"Right now the system knows Mercer and Kessler and Alder exist and nothing else"* lands very differently from a list of strangers.

**Why this ordering matters:** the Gmail Trigger polls on a one-minute cycle. If you send the email at 2:00 and stand there watching, that minute is the longest minute of your professional life. Sending it first turns polling latency into narrative time. This is the single most important sequencing decision in the script.

### 0:35 - 1:30  -  Make them describe their own problem

> *"Quick question while that runs  -  when Mercer Plumbing shows up at a property on Thursday, how do you know his general liability is current that day?"*

Then stop talking. Let the pause be uncomfortable.

Most will describe a spreadsheet, a shared drive folder, or admit they don't really know. **That admission is the entire sale.** You have not claimed anything yet; they have diagnosed themselves.

Follow with:

> *"That's normal  -  nearly everyone I talk to is somewhere in that range. Buildium will warn you at assignment if the date someone typed in has already passed. Two gaps: somebody has to type it in first, and the warning fires when you're already dispatching, which is exactly when people override it."*

### 1:30 - 2:00  -  The reveal

Refresh is automatic. The Kessler HVAC row has filled in.

> *"There it is. Vendor, carrier, policy number, the general liability limit, and the expiry date  -  all read off the certificate. Nobody typed anything."*

Pause on the amber.

> *"And it's amber, because that policy expires in twenty days."*

Click through to the source PDF.

> *"That's the actual document, one click away. You don't have to trust the system  -  every field is next to the thing it came from. It's doing the typing, not the deciding."*

**That sentence is the most important thing you say in the whole demo.** It is the sentence that makes an unproven freelancer safe to hire. Say it slowly.

### 2:00 - 2:30  -  The red row

Drag fixture 3 into the upload form.

> *"Here's one that came in through the upload page instead of email  -  same pipeline. This one's Mercer Plumbing."*

Row appears red.

> *"Expired thirty-four days ago. Nobody knew. There was no alert, because there was no system  -  just a folder and the hope that somebody would remember."*

### 2:20 - 2:35  -  The one they didn't see coming

Drop in fixture 13  -  the renewal with the gap.

> *"Last one. This is Mercer's renewal, the replacement for that expired policy."*

Row turns green, then the flag appears.

> *"Green  -  but look at that note. Old policy ended the first of March, new one started the fifteenth. That's a fourteen-day window where he was working your properties uninsured. Nobody was going to catch that. Not a spreadsheet, not Buildium, not a person comparing two PDFs six months apart."*

Let it sit. This is the second-best moment in the demo and it costs you fifteen seconds.

### 2:35 - 3:05  -  The draft

Trigger Workflow 2 manually.

> *"So here's what happens next. The system drafts the chase email  -  addressed to the agent, not the plumber, because the agent is the one who can actually produce the certificate. Policy number's already in it. Expiry date's already in it."*

Show the drafted body on screen.

> *"But it doesn't send it."*

### 3:05 - 3:35  -  **THE MOMENT**

Their phone buzzes  -  an email, in whatever mail app they already use. (You asked for the address when scheduling, framed as *"I'll send the approval to you so you can see it land."*)

> *"Check your email."*

Wait. Let them pick it up. Do not narrate.

> *"That's the draft, and two buttons. Nothing goes out to a vendor unless a person taps Approve. Go ahead  -  tap it."*

They tap. The email sends.

> *"That just went out from your address, to that agent, and it's logged. If they ignore it, in seven days you get another message  -  not another automatic email to the vendor, a message to you. Two ignored requests escalate to a human, not to more automation."*

**Design note:** if you couldn't get their address in advance, use your own phone and hand it over if you're in person, or hold it to the camera and tap it yourself while narrating. That is materially weaker  -  get the address when you book the call. Never make this moment depend on them installing anything.

### 3:35 - 4:10  -  Name the limitation before they find it

> *"One thing I want to say before you ask, because you'd find it eventually and I'd rather you heard it from me. This reads the certificate and tracks the dates. It cannot tell you that you're covered. A certificate is an information document  -  it doesn't amend the policy, and the 'additional insured' box is an assertion someone ticked, not proof. Actual additional-insured status comes from a carrier endorsement, and no tool at this price verifies endorsements. If you need that, you want an enterprise compliance platform, and I'll tell you that rather than pretend otherwise."*

> *"What this does is make sure a certificate never expires without anyone noticing, and take the chasing off your desk."*

This paragraph wins deals. With no track record, naming your own ceiling is the fastest credibility available to you.

### The hand-over

> *"Want to try it? I'll send you the upload link  -  drop any PDF in it, doesn't have to be a certificate, and see what it does."*

Send the Form Trigger URL in chat. Let them break it. Fixture 11's behaviour means a junk PDF produces a clean, honest "this isn't a certificate" rather than garbage. **Letting a prospect try to break something in front of you, and having it behave well, is worth more than any feature.**

### The closing ask

> *"Here's what I'd like to do, and it's smaller than you're expecting. Email me ten of your actual vendor certificates  -  whatever's in the folder, however messy. No system access, no credentials, no integration, nothing touching Buildium. I'll run them tonight and send you back a one-page picture of where you actually stand: who's current, who's expiring, who's lapsed. Tomorrow morning. It costs you nothing, and if the answer is 'we're fine', I'll tell you that and we'll leave it there."*

**Why this is the right ask:** it requires no trust, no budget, no IT involvement, and no decision. It is one email with attachments. And it inverts the relationship  -  you are no longer selling, you are producing a finding. When you come back with *"seven of these ten expired more than ninety days ago"*, they are no longer evaluating you; they are dealing with a problem.

If they hesitate, shrink it further: *"Send me three."*

---

## 9b. Rehearsed answers to the questions you will actually get

These need no build. They need saying out loud until they sound relaxed. Every one of them is a question a serious buyer asks and an unserious one doesn't  -  treat them as buying signals, not attacks.

### "What if the policy gets cancelled mid-term?"

> *"It won't catch that, and neither will anything else that reads a certificate  -  including the enterprise platforms. Since the 2010 ACORD revision the carrier's obligation runs to the insured, not to you as certificate holder. The only thing that gets you real notice is being scheduled onto the vendor's policy by endorsement, and most national carriers don't offer that any more. What I can do is shrink the window: instead of finding out at renewal twelve months later, we re-confirm every ninety days. That's not monitoring and I won't call it monitoring  -  it's asking more often."*

### "What happens if you disappear?"

The question every solo, offshore, unproven supplier gets. Have the answer ready and give it without defensiveness.

> *"Fair question, and you should ask it. Three things. It runs on your server, not mine. The workflows export as a file you keep. And the data is a standard Postgres database you own. If I vanish, any n8n developer can pick it up  -  and worst case you're back to the spreadsheet you have today, which is where you'd be anyway. You're not handing me anything you can't take back."*

### "You're in India  -  what if something breaks at 9am my time?"

> *"I'm about nine and a half hours ahead, so I work while you sleep. In practice, anything you flag at end of day is usually fixed before you're back at your desk. If something breaks at nine in the morning your time, you'll wait a few hours  -  which is why nothing in this system is time-critical by design. It drafts and notifies; it never has to act inside a deadline. That's deliberate."*

### "I'm not comfortable emailing you our vendor documents"

> *"Completely reasonable, and I'm happy to sign an NDA before you send anything. Worth saying though  -  these are documents your vendors hand to anyone who asks for one. There's no tenant data in them, no financial data, no bank details. If it helps, start with three instead of ten."*

### "Isn't this just a spreadsheet with extra steps?"

> *"For twelve vendors, honestly, yes  -  and I'd tell you not to buy it. The break point is somewhere around fifteen to twenty regular vendors, because that's where nobody can hold the dates in their head any more and the spreadsheet stops being updated. How many do you use regularly?"*

Being willing to disqualify them is the most persuasive thing you can do.

### "How much?"

Don't let them ask first. Name it immediately after the closing ask, anchored against the right comparison:

> *"Six hundred to set up, two-fifty a month. The way I'd frame that: people hire an offshore VA for exactly this work, and those packages run a thousand to twenty-five hundred a month. This does the chasing part for a fraction of that, doesn't need training, and doesn't quit. And for the first couple of clients I'm pricing below that in exchange for a written testimonial  -  I need case studies more than I need the margin, and I'd rather be straight with you about why."*

Naming the discount's motive is stronger than hiding it  -  and if you use their testimonial in marketing, the FTC requires the connection be disclosed anyway (Section 1.6). Get the honest habit early.

---

## 10. Failure recovery

Rehearse the lines. Reading them cold is how a small failure becomes a large one.

| What breaks | Likelihood | What you say | What you do |
|---|---|---|---|
| **Approval button 404s** | **High  -  most likely failure** | *"That's my webhook URL, not the workflow  -  one second."* | This is why 1.2 exists. If it fails, approve from the n8n Executions view on screen instead: *"Same gate, just approving it from here."* The concept survives; only the theatre is lost. |
| **Gmail Trigger doesn't fire** | Medium | *"Email polling is on a one-minute cycle and it's being slow  -  let me use the upload page instead, it's the same pipeline."* | Drag the fixture into the Form Trigger. Rehearse this switch until it's smooth. |
| **Model API 429 / 500** | Low | *"That's the model API rate-limiting me  -  this is why the system retries rather than failing silently."* | Re-run the node. If it fails twice, cut to a pre-processed row: *"Here's one I ran this morning."* |
| **Your internet drops entirely** | Low | *"I've lost my connection  -  give me thirty seconds, and if it doesn't come back I've got a recording."* | Phone hotspot first. Then the fallback video from your phone. **Never** try to fix infrastructure live; you look like a hobbyist. |
| **Extraction returns a wrong field** | Medium | *"Good  -  this is exactly what I want you to see."* | Then show it flagged, or open the source PDF beside it. A visible wrong answer *next to its source document* proves the review model works. Do not apologise; explain the gate. |
| **Dashboard renders broken** | Low | *"Let me pull it up fresh."* | Second tab already open on the dashboard URL. This is why you open it before the call. |
| **They ask something you can't answer** | High | *"I don't know. I'll find out and tell you today."* | Then actually do it, same day. With no track record, one kept small promise is worth more than a confident guess. |

**The rule for all of these:** never debug in front of a prospect. Acknowledge, switch to the alternate path, keep moving. A demo that hits a snag and recovers calmly reads as *a real system built by a competent person*. A demo where someone opens a terminal reads as *a prototype*.

**The nuclear option.** If three things fail, stop:

> *"This isn't going well and I'm not going to waste your time fighting it. Let me do this instead  -  send me ten of your certificates and I'll send you back the actual output tomorrow. That's a better proof than a live demo anyway."*

That recovers more deals than grinding through. It is also, straightforwardly, true.

---

## 11. What you must not claim

The build genuinely cannot do these things. A prospect may assume otherwise. Say the honest version first.

| Prospect might assume | Reality | Say this instead |
|---|---|---|
| "It verifies our vendors are covered" | A certificate is informational. It doesn't amend the policy or confer rights on the holder  -  the form says so itself. | *"It reads the certificate and tracks the dates. It doesn't verify coverage  -  nothing that reads a certificate can."* |
| "It confirms we're additional insured" | The ADDL INSD column is an assertion. Real status requires a carrier endorsement (typically CG 20 10 / CG 20 37). Listing someone in the Description of Operations box does not extend coverage. | *"It records whether that box is ticked. Whether the endorsement actually exists is a separate document your agent has to produce."* |
| "It tells us if a policy gets cancelled" | **The most important gap.** A policy can be cancelled the day after the certificate is issued. The certificate still shows the original expiry. The system will show green on a policy that no longer exists. | *"It tracks what the paperwork says. If a carrier cancels mid-term, the certificate doesn't change and neither does this. That's a real gap and it's why this is administrative relief, not risk management."* |
| "It'll catch vendors who never sent anything" | It only knows about vendors someone entered. A vendor nobody set up is invisible to it. | *"It tracks the vendor list you give it. If somebody hires a new subcontractor and doesn't tell anyone, this won't know about them either."* |
| "It'll spot a forged certificate" | It cannot. It reads what's on the page. An altered date extracts as cleanly as a real one. | *"No. It reads the document it's given. Detecting a forgery means contacting the carrier, which is a different service."* |
| "It's 100% accurate" | It isn't, on poor scans or unusual layouts. | *"On clean PDFs it's very reliable. On phone photos it drops confidence and routes to review rather than guessing. Every field sits next to the source document."* |
| "It updates Buildium" | It has no PMS credentials and no write path. | *"Deliberately not. It doesn't touch your system of record  -  which also means it can't break anything in it."* |
| "It's a compliance system" | It is a paperwork tracker. Different product, different liability. | *"It's an automated assistant for vendor paperwork. If you need compliance infrastructure, that's an enterprise platform and a different budget."* |
| "The certificate says 30 days notice, so we'll be told" | **The wording is not a promise.** The 2010 ACORD revision removed the carrier's obligation to notify certificate holders; notice runs to the insured under policy terms. Producers can't legally alter the form to add it, and wording added in Description of Operations means nothing unless a policy form backs it. | *"We record that sentence because it's on the document. It doesn't mean you'll actually be notified. Real notice means being scheduled onto the vendor's policy by endorsement  -  ask your broker whether their carriers still offer that."* |
| "Quarterly re-attestation means you're monitoring the policy" | It is asking more often. Nothing checks the policy between requests. | *"It shrinks the window from twelve months to three. It doesn't watch anything  -  it just asks more often, and I won't dress that up as monitoring."* |

**The rule to never break:** the system never uses the words *compliant*, *verified*, *covered*, or *approved* about a vendor. Only date facts: *current until 14 March*, *expired 22 days ago*, *no certificate on file*. Facts about paperwork, never conclusions about coverage. Enforce it in the HTML template so it can't drift.

**Two more things not to claim about yourself:** don't imply you have existing clients, and don't describe the product as "ACORD-integrated" or "ACORD-certified" (Section 1.5).

---

## 12. Cost breakdown

### Build

| Item | Anthropic (Haiku 4.5) | OpenAI (GPT-5.4 Mini) |
|---|---|---|
| Extraction iterations (~250 runs, text branch, ~1.5k in / 0.4k out) | ~$0.90 | ~$0.73 |
| Vision branch iterations (~60 runs; OpenAI sends text **and** page images) | ~$0.45 | ~$0.60 |
| Email drafting iterations (~80 runs, short) | ~$0.15 | ~$0.12 |
| Contingency for re-work (×2) | ~$1.50 | ~$1.45 |
| **Total token spend** | **~$3.00** | **~$2.90** |

The two providers land within pennies of each other. **Do not let cost decide this**  -  decide on Structured Outputs (Section 1.9) or on whichever account you already have.
| VPS (Hetzner CX22 or equivalent, monthly) | **$5/mo** (or $0 if you already have one) |
| Domain / subdomain for HTTPS | $0-12/yr |
| n8n, Postgres, Telegram, Gmail, ReportLab | **$0** |
| **Total build cost** | **≈ $8**, comfortably inside your $10 ceiling |

New Anthropic accounts receive $5 in free credits, which may cover most of the token spend outright; check whether any equivalent promotional credit is live on OpenAI at signup. Set a **$10 hard spend limit** on the API key either way  -  that limit is the actual enforcement of your budget, not this table.

### Running the demo

| Item | Cost |
|---|---|
| One full demo (2 extractions + 1 email draft) | **~$0.012** |
| 20 demos | **~$0.25** |
| Free-trial run of a prospect's 10 real certificates | **~$0.05** |

You can run the "send me ten certificates" offer on every prospect you speak to for a year and spend under $5 doing it. Make that offer aggressively  -  it is nearly free and it is your best closing tool.

### Production, per client

| Item | Monthly |
|---|---|
| VPS (shared across clients, or client-hosted) | $5 / client-hosted $0 |
| Model API: ~30 certificates + ~120 reminder drafts | **~$0.60** (either provider) |
| Postgres, n8n, Telegram | $0 |
| Gmail (their existing Workspace) | $0 |
| SMS, **if** the client wants it in production | ~$10/mo campaign fees + ~$0.01/msg, **billed to the client's own account under their EIN** |
| **Your marginal cost per client** | **under $6/month** |

Against $200-350/month, gross margin is roughly 97-98%. Your real cost is your time, so price on the value of the time you save them, not on infrastructure.

**Reference point for the sales conversation:** offshore VA packages for this kind of work run $1,000-2,500/month. At $250/month you are an order of magnitude below the cheapest alternative that does the same job.

---

## 13. Future scope

Deliberately excluded from the demo. Each is a reason for a second conversation, which is exactly what you want.

| Capability | What it adds | Why it's not in the demo |
|---|---|---|
| **Vendor self-service upload portal** | Vendor gets a link, uploads directly, no email round-trip | Adds auth and a public surface. Zero demo value  -  the prospect isn't the vendor. |
| **Producer/agent direct requests** | Email the agent's office automatically at renewal, before the vendor is involved | Genuinely valuable, but needs real agent contact data. Sell it as a phase-2 add-on. |
| **W-9 and licence tracking** | Same pipeline, different documents; expands the register into a full vendor file | Obvious upsell. Adds document types and dilutes a demo that works because it's narrow. |
| **Endorsement request workflow** | Requests CG 20 10 / CG 20 37 from the agent and tracks whether it arrived | Moves toward real verification. **Deliberately excluded**  -  it edges into the compliance-assurance positioning you must avoid until you have a track record. |
| **Multi-property certificate holder logic** | Different holder entities per property or owner | Real for clients with multiple LLCs. Needs their entity structure, which you won't have pre-sale. |
| **PMS sync (read-only)** | Pull the vendor list from Buildium instead of manual seeding | Requires Premium at $400/mo. Never make this a precondition. Offer it only if they're already on Premium. |
| **SMS escalation** | Manager alerts by text instead of Telegram | Requires A2P 10DLC under the client's EIN, 1-4 weeks. Production only, client-registered. |
| **Owner-facing compliance report** | Monthly PDF the manager forwards to property owners | Strong retention feature  -  it makes their client look organised. Good phase-2 revenue. |
| **Automatic carrier verification** | Check policy status directly with the carrier | Not realistically available at this price point, and not buildable by you at all  -  see below. |

### Competitors you should be able to name before the prospect does

| Platform | What it actually does | Why it matters to you |
|---|---|---|
| **Certificial** | Connects to the **insurance agent's agency management system** for live policy data rather than parsing static PDFs; claims 25,000+ connected agencies. Published requestor pricing starts around **$99/month**. | **The one real competitor at your price point.** It solves the mid-term problem you cannot. Know it exists, verify the current pricing yourself, and be ready to say who it's for. |
| **TrustLayer** | COI automation with "Pulse" real-time validation via direct carrier partnerships (Nationwide is the named one). | Independent commentary suggests carrier coverage spans a limited subset  -  vendors outside the network fall back to ordinary document review. Enterprise-priced. |
| **NetVendor** | Enforcement-grade PMS integrations (Yardi, Entrata, RealPage, AppFolio, MRI, ResMan, Rent Manager) where compliance status gates work-order eligibility. | This is the "block dispatch automatically" product. Built and priced for enterprise multifamily  -  above your segment. |
| **myCOI, Jones, CertFocus** | Document-based COI tracking with review teams. | Enterprise portfolios. Same structural blind spot you have. |

**Heavy caveat:** almost everything published comparing these platforms is written by one of them about the others. Certificial's blog says TrustLayer can't do real-time monitoring; TrustLayer's blog says myCOI is built for a different era. Treat the entire genre as adversarial marketing and verify anything that would change a decision.

**Why you cannot build the AMS-connected version:** live policy status flows *carrier → agency* over rails like IVANS, into agency management systems (Applied Epic, AMS360, HawkSoft, EZLynx). Your client is a third party with no seat on that rail. The moat isn't code  -  it's having signed up 25,000 insurance agencies. That is years and a sales team, and no amount of n8n substitutes for it.

**What to say when a prospect raises Certificial:** *"That's the right product if you want live policy status, and it's genuinely better than what I do on that specific axis  -  it plugs into your vendors' agents' systems. Two things to check: whether your vendors' agents are actually on their network, and whether you want to run a vendor onboarding process to get them there. What I do is narrower and needs nothing from anybody  -  certificates arrive by email and get chased. If you want the live version, go look at them; I'd rather tell you that than lose your trust in month three."*

That answer costs you nothing and buys you an enormous amount. Most prospects at 200-600 doors will not run a vendor-onboarding programme, which is the actual reason your product exists.

---

## 14. Production build changes

What has to change once a paying client depends on it. None of this belongs in the demo.

### Robustness and error handling
- **Error Trigger workflow** on every production workflow, routing failures to Telegram with workflow name, node, and execution URL.
- **Retry with backoff** on all model calls (3 attempts, exponential) and on Gmail sends.
- **Dead-letter table**: any certificate that fails processing entirely lands in a row a human can see, rather than vanishing from an execution log.
- **Idempotency**: key on message-ID plus attachment hash so a re-delivered email doesn't create duplicates.
- **Schema-validate the model output** against the JSON schema before the Code node touches it, and re-prompt once on failure.

### Silent-failure monitoring  -  the one that actually matters
This product's failure mode is silence. If the Gmail Trigger quietly stops polling, nothing looks broken; certificates just stop arriving, and the client doesn't notice for six weeks. That is the exact failure this product exists to prevent, which makes it the failure that would end the engagement.

- **Heartbeat workflow**: every morning, confirm each active workflow executed in the last 24h. If not, alert.
- **Canary certificate**: a scheduled job emails a known test certificate to the intake address weekly and verifies it lands correctly end to end. This catches OAuth expiry, which is the most common silent killer.
- **Weekly digest to the client**: "3 certificates processed, 2 reminders sent, 1 awaiting review." Proves it's alive even in a quiet week, and is a retention tool.
- **Uptime monitoring** on the dashboard webhook (Uptime Kuma, self-hosted, free).

### Real-data edge cases you will hit
- Vendor legal names that don't match how the client refers to them ("Mercer Plumbing" vs "M. Mercer & Sons Plumbing Inc")  -  needs an alias table and a human matching step at onboarding.
- Certificates naming a property-specific LLC as holder rather than the management company.
- Multi-page certificates with an ACORD 101 remarks schedule attached.
- Certificates arriving as images embedded in the email body rather than as attachments.
- Agencies that send a ZIP of certificates.
- Blanket additional-insured wording in Description of Operations  -  extract it verbatim, never interpret it.
- Vendors with two active policies from different carriers simultaneously mid-switch.

### Security
- n8n behind HTTPS with basic auth or SSO; never expose the editor publicly.
- `N8N_ENCRYPTION_KEY` stored in a secret manager, not in `docker-compose.yml`.
- Postgres not exposed outside the Docker network.
- Form Trigger rate-limited and file-type-restricted (PDF only, 10MB cap).
- Certificate PDFs on an encrypted volume.
- Separate model API key per client where possible, with per-key spend limits.
- Documented, tested backup of Postgres  -  daily dump, offsite, restore tested once.

### Onboarding (build this before client one, not after)
- **Vendor import**: CSV template, or a guided session where you seed the vendor list together on a call.
- **Historical backfill**: process their existing certificate folder in one batch  -  this is also the deliverable from your free trial offer.
- **Config interview**: legal name(s), minimum limits, reminder cadence, who approves, which mailbox sends.
- **A one-page runbook**: what the statuses mean, what to do with a `NEEDS_REVIEW` row, who to contact.
- **Approver training**: fifteen minutes on the Gmail approval gate. The whole trust model depends on a human actually reading before tapping Approve, and if they start rubber-stamping, the product's honesty claim quietly becomes false.

### Commercial and legal
- **Written scope** stating explicitly what the system does not do  -  reuse Section 11 verbatim. This is the document that protects you if a vendor's lapsed policy ever becomes a dispute.
- **Professional indemnity insurance** before client two. Your product touches an area adjacent to risk management; the scope document is your first defence and insurance is your second.
- **n8n hosting decision** resolved per Section 1.4  -  client-hosted is both the safer licence position and the better sales position.
- **Data processing terms**: one page covering what you store, where, for how long, and what happens on termination.
- **Exit plan**: what the client keeps if they stop paying. Offering "you keep the database and the workflows export as JSON" removes a real objection from a solo supplier, and costs you nothing.

---

## Summary of changes from your source document

1. **OCR removed entirely.** `n8n-nodes-ocrbro` is effectively unmaintained (two releases, same day, no dependents). Native PDF vision on the model replaces it  -  better quality on scans, zero community-node dependency.
2. **The human approval gate is promoted from a step to the centrepiece.** Gmail is the default because n8n's Send-and-Wait approval works in an ordinary email client. Telegram remains optional for prospects who already use it.
3. **Demo sequencing changed**  -  send the email *first*, talk over the polling delay. Your original script has 60 seconds of dead air in it.
4. **ACORD form copyright** flagged; affects fixtures and marketing wording. Missing from your doc.
5. **n8n Sustainable Use License** affects your hosting model, not just the build. Client-hosted resolves it and sells better.
6. **A2P 10DLC needs a US EIN**, which you don't have  -  SMS must be client-registered. Sharper reason for a conclusion your doc reached by instinct.
7. **Buildium Premium is now $400/mo**, not $375. Update your objection-handling numbers.
8. **Postgres over Sheets**, and a hand-built HTML dashboard over EspoCRM.
9. **Two fixtures added** that your doc missed: the renewal/supersede case (the actual steady state) and the wrong-certificate-holder case (a problem they don't know they have).
10. **Two limitations added** to the honesty list: mid-term cancellation, and vendors who never submitted anything at all. Both are things a sharp prospect will eventually find.
11. **Two defects found and fixed on review, before any client saw them:**
    - **Vendors with no certificate were never chased.** A NULL expiry fell through the Switch to NoOp, meaning the system silently ignored the *most* non-compliant vendors while diligently chasing the ones near renewal  -  the exact failure the product claims to prevent. `NEVER_RECEIVED` is now the first branch. (Build step 3.2.)
    - **The demo's best moment depended on the prospect installing Telegram.** Email approval is now the default via the Gmail node's `Send and Wait for Response`, which renders the same buttons in any mail client. Telegram is optional. (Build step 3.4.)
12. **Nine domain gaps closed** that a prospect would have found: coverage gaps on renewal (rule 9  -  the sleeper demo moment), workers' comp exemptions producing false alarms (rule 10), per-trade insurance minimums (rule 11), multiple accepted certificate holders (rule 12), near-duplicate vendor merging (rule 13), manual CANCELLED/NON_RENEWED status, chase-pause on escalation, non-PDF and portal-link replies, password-protected PDFs.
13. **Mid-term blind window narrowed honestly (Section 5.5).** Quarterly re-attestation takes exposure from twelve months to three using one config value and one Switch branch, plus verbatim capture of cancellation-notice wording as a *fact about the paperwork*. Explicitly not described as monitoring, in the build or the sales language.
14. **Demo seeded with the prospect's real vendor names** (build step 1.4)  -  the highest-leverage step in the plan, and it removes the "whose vendors are those?" question that makes a staged demo visible.
15. **Section 9b added:** rehearsed answers for the six questions a serious buyer asks  -  mid-term cancellation, what if you disappear, the timezone, confidentiality of the ten certificates, isn't-this-a-spreadsheet, and price.
16. **Competitive notes added to Section 13.** Certificial is the one real competitor at your price point (~$99/month, AMS-connected) and you should be able to name it first. Includes why you cannot build the AMS-connected version and what to say when a prospect raises it.
17. **Provider choice (Section 1.9).** Use OpenAI through n8n's built-in OpenAI node V2 by default because current n8n supports the Responses API, PDF File input, and JSON Schema output. HTTP Request is now a fallback for older n8n versions, missing node controls, or Anthropic. OpenAI's strict Structured Outputs is the main engineering advantage; OpenAI's faster model churn remains the main operational risk. Pin model IDs and keep the ID in `client_config`.
