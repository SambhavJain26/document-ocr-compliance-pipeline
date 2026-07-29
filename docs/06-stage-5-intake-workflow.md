# Stage 5 — Intake workflow

**Document 06 · Estimated time: 1 day · Cost: ~$0.50 of token spend**

Workflow `COI · 1 · Intake`. Two entry points, one pipeline, three terminal outcomes.

**Gate:** uploading fixture 1 through the form URL creates one vendor match, one certificate row with `status = ON_FILE`, three coverage rows, and a notification.

---

## 5.1 Node graph

```
[Form Trigger]          [Gmail Trigger]
  instant                poll 1 min, label COI-INTAKE
      │                        │
      │                        ▼
      │                 [Split Attachments]      Code, once for all items
      │                        │
      └──────────┬─────────────┘
                 ▼
        [Postgres — Load Context]                config + entities + vendors
                 ▼
        [01 Preflight]                           Code: sha256, type, size checks
                 ▼
        ┌────────┴─────────┐
     ok │                  │ reject
        ▼                  ▼
 [Extract From File]  [Postgres — Dead Letter] → [Notify Manager] ─┐
        ▼                                                          │
   [IF text > 200]                                                 │
     ┌──┴───┐                                                      │
 yes │      │ no                                                   │
     ▼      ▼                                                      │
[02 Build Text]  [02 Build Vision]                                 │
     └──┬───┘                                                      │
        ▼                                                          │
 [HTTP — OpenAI Responses]                                         │
        ▼                                                          │
 [03 Parse Response]                                               │
        ▼                                                          │
   [IF ok?] ──false──▶ [Postgres — Dead Letter] ───────────────────┤
        │ true                                                     │
        ▼                                                          │
 [Postgres — Vendor Lookup]                                        │
        ▼                                                          │
 [04 Validate]                                                     │
        ▼                                                          │
 [Switch: outcome] ──REJECT──▶ [Postgres — Dead Letter] ───────────┤
        │ STORE                                                    │
        ▼                                                          │
 [Postgres — Upsert Vendor]        (only when vendor_action=CREATE)│
        ▼                                                          │
 [Store PDF to Volume]                                             │
        ▼                                                          │
 [Postgres — Upsert Certificate]                                   │
        ▼                                                          │
 [Postgres — Insert Coverages]                                     │
        ▼                                                          │
 [Postgres — Supersede Prior]                                      │
        ▼                                                          │
 [IF was_insert?] ──false──▶ [NoOp: duplicate, stay quiet]         │
        │ true                                                     │
        ▼                                                          │
 [Notify Manager] ◀────────────────────────────────────────────────┘
```

**Build it in this order:** Form Trigger path first, end to end, with fixture 1. Add the Gmail Trigger only once the pipeline works. Debugging OAuth and extraction simultaneously is how an afternoon disappears.

---

## 5.2 Node-by-node

### N1 · `Form Trigger — Upload a Certificate`

`n8n-nodes-base.formTrigger`

| Parameter | Value |
|---|---|
| Form Path | `coi-upload` |
| Form Title | `Send us a certificate of insurance` |
| Form Description | `Drop the PDF below. We'll read it and file it against the right vendor.` |
| Field 1 | Type `File` · Label `Certificate (PDF)` · Required ✓ · Accepted File Types `.pdf` · Multiple Files ✓ |
| Field 2 | Type `Text` · Label `Anything we should know? (optional)` · Required ✗ |
| Respond When | `Form Is Submitted` |
| Options → Button Label | `Upload` |

Production URL: `https://n8n.yourdomain.com/form/coi-upload`

This URL is what you hand a prospect at the end of the demo — *"drop any PDF in it, doesn't have to be a certificate, see what it does."* Letting them try to break something in front of you, and having it behave well, is worth more than any feature. Which is why fixture 11's behaviour matters.

### N2 · `Gmail Trigger — COI Inbox`

`n8n-nodes-base.gmailTrigger`

| Parameter | Value |
|---|---|
| Credential | `Gmail account` |
| Poll Times | Every Minute |
| Simplify | **off** |
| Filters → Label Names | `COI-INTAKE` |
| Options → Download Attachments | **on** |

Simplify off gives you `payload.headers`, message ID, and the full attachment map. The `COI-INTAKE` label is set by the Gmail filter you created in Stage 0, which keeps demo traffic out of your real inbox and makes the trigger's scope precise.

> **Polling latency is a demo-sequencing problem, not an architecture problem.** One minute of dead air is the longest minute of your professional life. Stage 9's script sends the email *first* and talks over the delay. Do not try to fix this by dropping the poll interval.

### N3 · `Split Attachments` — Code, Run Once for All Items

One email can carry two certificates (fixture 10). It can also carry none (fixture 19).

```javascript
/**
 * 03_split_attachments — Code node, "Run Once for All Items"
 *
 * Fans one Gmail message out to one item per PDF attachment.
 * An email with no PDF is not dropped: it becomes a routable dead-letter
 * item, distinguishing a plain-text reply from a portal-link email.
 */
const out = [];

for (const item of $input.all()) {
  const j = item.json;
  const bin = item.binary || {};
  const headers = j.payload?.headers || [];
  const hdr = (n) => headers.find((h) => h.name?.toLowerCase() === n)?.value || '';

  const meta = {
    source: 'email',
    source_ref: j.id || j.messageId || null,
    from_address: hdr('from'),
    subject: hdr('subject'),
    body_text: j.snippet || j.text || '',
  };

  const pdfKeys = Object.keys(bin).filter((k) => {
    const b = bin[k];
    return b?.mimeType === 'application/pdf'
        || (b?.fileName || '').toLowerCase().endsWith('.pdf');
  });

  if (pdfKeys.length === 0) {
    // Portal-link emails are increasingly common from larger agencies.
    // Detect and label them, but NEVER fetch the link — hand it to a human.
    const body = `${meta.subject} ${meta.body_text}`.toLowerCase();
    const looksLikePortal =
      /(download|retrieve|access|view)\b[^.]{0,60}\b(certificate|coi|document)/.test(body) ||
      /https?:\/\/[^\s]*(portal|secure|share|download|docs)/.test(body);

    out.push({
      json: {
        ...meta,
        preflight_ok: false,
        reason_code: looksLikePortal ? 'NO_ATTACHMENT_PORTAL_LINK' : 'NO_ATTACHMENT_TEXT_REPLY',
        reason_detail: looksLikePortal
          ? 'Email contains a download link and no attachment. Not fetched — needs a person.'
          : 'Email has no attachment. Likely a reply from the vendor or agent.',
      },
    });
    continue;
  }

  for (const key of pdfKeys) {
    out.push({
      json: { ...meta, original_filename: bin[key].fileName || 'certificate.pdf', binary_key: key },
      binary: { data: bin[key] },
    });
  }
}

return out;
```

The Form Trigger path needs a two-line equivalent that maps `source: 'form'` and its submission ID. Keep them as separate Code nodes; merging them into one branching node makes both harder to read.

### N4 · `Postgres — Load Context`

`n8n-nodes-base.postgres` · Operation `Execute Query`

```sql
SELECT
  (SELECT jsonb_object_agg(key, value) FROM client_config)                       AS config,
  (SELECT jsonb_agg(jsonb_build_object(
            'legal_name', legal_name, 'normalised', normalised,
            'is_primary', is_primary))
     FROM holder_entities)                                                       AS holder_entities,
  (SELECT jsonb_agg(jsonb_build_object(
            'id', v.id, 'legal_name', v.legal_name,
            'normalised_name', v.normalised_name, 'trade', v.trade,
            'wc_exempt', v.wc_exempt, 'producer_email', v.producer_email,
            'contact_email', v.contact_email))
     FROM vendors v WHERE v.active)                                              AS vendor_candidates,
  (SELECT jsonb_object_agg(trade, jsonb_build_object(
            'trade', trade,
            'min_each_occurrence', min_each_occurrence,
            'min_general_aggregate', min_general_aggregate,
            'wc_required', wc_required))
     FROM trade_requirements)                                                    AS trade_requirements;
```

| Setting | Value |
|---|---|
| Options → Output Large-Format Numbers As | `Numbers` |
| Settings → Always Output Data | on |
| Settings → Execute Once | **on** |

`Execute Once` matters: with two attachments in flight you want one context query, not two. Merge the result onto each item with a Merge node in `Combine → Combine All` mode, or read it via `$('Postgres — Load Context').first().json` in the downstream Code nodes. **Prefer the latter** — it is one fewer node and it survives item-count changes.

### N5 · `01 Preflight` — Code, Run Once for Each Item

Everything cheap and deterministic, before spending a token.

```javascript
/**
 * 01_preflight.js — Code node, "Run Once for Each Item"
 *
 * Guards the expensive path. Computes the idempotency key, rejects anything
 * structurally unprocessable, and attaches the shared context.
 */
const crypto = require('crypto');

const ctx = $('Postgres — Load Context').first().json;
const j = $json;

const passthrough = (extra) => ({ json: { ...j, ...ctx, ...extra } });

// Items already rejected upstream (no attachment) flow straight through.
if (j.preflight_ok === false) return passthrough({});

const bin = $input.item.binary?.data;
if (!bin) {
  return passthrough({ preflight_ok: false, reason_code: 'EMPTY_ATTACHMENT',
                       reason_detail: 'No binary payload on the item.' });
}

const buf = Buffer.from(bin.data, 'base64');

if (buf.length === 0) {
  return passthrough({ preflight_ok: false, reason_code: 'EMPTY_ATTACHMENT',
                       reason_detail: 'Attachment is zero bytes.' });
}
if (buf.length > 25 * 1024 * 1024) {
  return passthrough({ preflight_ok: false, reason_code: 'NOT_A_PDF',
                       reason_detail: `Attachment is ${(buf.length / 1048576).toFixed(1)} MB; cap is 25 MB.` });
}

// Magic bytes, not the file extension. An extension is a claim.
if (buf.subarray(0, 5).toString('latin1') !== '%PDF-') {
  return passthrough({ preflight_ok: false, reason_code: 'NOT_A_PDF',
                       reason_detail: 'File does not begin with %PDF-.' });
}

// Encryption check. /Encrypt in the trailer means Extract From File will
// throw, so catch it here and dead-letter with a readable reason instead of
// a crashed execution. (Fixture 18.)
const head = buf.subarray(0, Math.min(buf.length, 4096)).toString('latin1');
const tail = buf.subarray(Math.max(0, buf.length - 4096)).toString('latin1');
if (/\/Encrypt\b/.test(head) || /\/Encrypt\b/.test(tail)) {
  return passthrough({ preflight_ok: false, reason_code: 'PDF_ENCRYPTED',
                       reason_detail: 'PDF is password-protected. Ask the sender for an unlocked copy.' });
}

const sha = crypto.createHash('sha256').update(buf).digest('hex');
const now = new Date();

return passthrough({
  preflight_ok: true,
  content_sha256: sha,
  byte_size: buf.length,
  pdf_base64: bin.data,
  stored_path: `/data/certs/${now.getUTCFullYear()}/` +
               `${String(now.getUTCMonth() + 1).padStart(2, '0')}/${sha}.pdf`,
  system_prompt: SYSTEM_PROMPT,   // pasted constant, see note below
  schema: SCHEMA,                 // pasted constant
});
```

> **Why the prompt and schema are pasted constants rather than read from disk:** the n8n Code node has no reliable filesystem read, and putting them in `client_config` makes a 4 KB blob travel through every Postgres query on the hot path. Paste them as `const SYSTEM_PROMPT = \`...\`;` at the top of the node. `extraction/prompts/` and `extraction/schema/` remain the source of truth; Stage 8 has a check that the pasted copies still match the files.

### N6 · `IF — Preflight OK`

`n8n-nodes-base.if` · Condition: `{{ $json.preflight_ok }}` **is true** (Boolean).

True → N7. False → the Dead Letter node.

### N7 · `Extract From File`

`n8n-nodes-base.extractFromFile`

| Parameter | Value |
|---|---|
| Operation | `Extract From PDF` |
| Input Binary Field | `data` |
| Options → Join Pages | on |
| Settings → On Error | `Continue (using error output)` |

Error output → Dead Letter with `PDF_UNREADABLE`. Preflight already caught encryption, so anything reaching here is a genuinely malformed file, which is rare and worth naming distinctly.

### N8 · `IF — Has Text Layer`

`n8n-nodes-base.if` · Condition: `{{ $json.text ? $json.text.trim().length : 0 }}` **Number → larger** than `200`.

True → `02 Build Text`. False → `02 Build Vision`.

The 200-character threshold is deliberate: comfortably below a real certificate's 1,500–2,500 characters, comfortably above the stray filename or date stamp some scanners bake into an otherwise image-only PDF. A `> 0` check would route those to the text branch and extract garbage.

### N9a / N9b · `02 Build Text` / `02 Build Vision`

Both are the Code node from [Stage 4 §4.5](05-stage-4-extraction-engine.md), differing only in a hardcoded `branch` value. Set:

```javascript
const j = { ...$json, branch: 'text', document_text: $json.text };
// or
const j = { ...$json, branch: 'vision' };
```

### N10 · `HTTP — OpenAI Responses`

Configured exactly as [Stage 4 §4.5](05-stage-4-extraction-engine.md). Both branches feed this one node — one thing to configure, one thing to debug, one place a timeout is set.

### N11 · `03 Parse Response`

The Code node from [Stage 4 §4.6](05-stage-4-extraction-engine.md), verbatim.

### N12 · `IF — Extraction OK`

Condition: `{{ $json.ok }}` is true. False → Dead Letter, using the `reason_code` the parser produced (`MODEL_ERROR`, `MODEL_REFUSED`, `JSON_PARSE_FAILED`).

### N13 · `Postgres — Vendor Lookup`

Finds the current certificate for the best-matching vendor, so rules 8 and 9 have something to compare against.

```sql
-- $1 = normalised vendor name from the extraction
WITH candidate AS (
  SELECT v.id
  FROM   vendors v
  LEFT JOIN vendor_aliases a ON a.vendor_id = v.id
  WHERE  v.active AND (v.normalised_name = $1 OR a.normalised = $1)
  LIMIT  1
)
SELECT c.id,
       c.certificate_date,
       c.status,
       e.earliest_expiration
FROM   certificates c
JOIN   candidate       ON candidate.id = c.vendor_id
LEFT   JOIN v_certificate_expiry e ON e.certificate_id = c.id
WHERE  c.status IN ('ON_FILE','NEEDS_REVIEW')
ORDER  BY c.certificate_date DESC NULLS LAST, c.received_at DESC
LIMIT  1;
```

Query Parameters: `={{ $json.vendor_normalised }}` — computed in `02 Build Request` by running `normaliseName(extraction.vendor_legal_name)`.

Settings → Always Output Data **on**. A vendor with no prior certificate must yield an empty item, not stall the branch.

### N14 · `04 Validate`

The Code node from [Stage 4 §4.8](05-stage-4-extraction-engine.md), verbatim.

### N15 · `Switch — Outcome`

`n8n-nodes-base.switch` · Mode `Rules` on `{{ $json.outcome }}`:

| Output | Value | Goes to |
|---|---|---|
| 0 | `STORE` | N16 |
| 1 | `REJECT` | Dead Letter |
| Fallback | — | Dead Letter with `UNKNOWN` |

Always wire the fallback. A Switch with no fallback silently discards items, which violates "nothing is ever silently dropped".

> **Seed counts for reference:** the demo register is 18 vendors, 4 of which end the demo grey (Orme, Padstow, Quill, Draycott). If your counts differ after a test run, `make db-verify` tells you which one drifted.

### N16 · `Postgres — Upsert Vendor`

Runs only when `vendor_action = 'CREATE'`. Gate it with an IF, or let the query no-op:

```sql
-- $1 legal_name  $2 normalised  $3 producer_name  $4 producer_email  $5 producer_phone
INSERT INTO vendors (legal_name, normalised_name, trade, producer_name, producer_email, producer_phone)
VALUES ($1, $2, 'DEFAULT', $3, $4, $5)
ON CONFLICT DO NOTHING
RETURNING id;
```

New vendors land on trade `DEFAULT`, which means default limits. **This is deliberate.** Guessing a trade from a company name ("Vaughn Electric" → Electrical) is a heuristic that works until "Bright Electric Cleaning Services" arrives and gets held to electrical limits. Trade assignment is a 30-second onboarding task for a human; getting it silently wrong generates confident false flags, and confident wrong alerts are what destroy trust in an automated system.

### N17 · `Store PDF to Volume`

`n8n-nodes-base.readWriteFile` · Operation `Write File to Disk`

| Parameter | Value |
|---|---|
| File Path | `={{ $json.stored_path }}` |
| Input Binary Field | `data` |
| Options → Append | off |

The `certs_data` volume is mounted at `/data/certs` in the n8n container. Content-addressed by SHA-256, so re-processing the same PDF overwrites itself byte-identically and never accumulates duplicates.

### N18 · `Postgres — Upsert Certificate`

`db/queries/q_upsert_certificate.sql` from [Stage 2 §2.6](03-stage-2-data-layer.md), 25 parameters, `RETURNING id, (xmax = 0) AS was_insert`.

Operation `Execute Query`. Parameters go in `options.queryReplacement` as **an expression evaluating to an array**:

```
={{ [
  $json.vendor_id, $json.source, $json.source_ref,
  $json.original_filename, $json.content_sha256, $json.stored_path,
  $json.byte_size, $json.page_count, $json.extraction.certificate_date,
  $json.extraction.certificate_holder, $json.holder_match, $json.holder_matched_entity,
  $json.extraction.extraction_confidence, $json.extraction.confidence_reason,
  $json.branch, $json.model_id, $json.input_tokens, $json.output_tokens, $json.latency_ms,
  JSON.stringify($json.extraction), JSON.stringify($json.flags), $json.status,
  $json.extraction.cancellation_notice_wording, $json.extraction.description_of_operations,
  $json.coverage_gap_days
] }}
```

> **An array, not the comma-separated string the UI hints at.** The string form splits on commas and therefore corrupts any value containing one — and certificate holder names and addresses are full of them (`Harbourline Property Management LLC, Suite 210`). It passes on tidy fixtures and fails on real client data, which is the worst possible failure profile. See [§12.7](12-n8n-operations-cookbook.md).

Also prefer `executeQuery` over the node's `insert` / `upsert` operations throughout — those need a `resourceMapper` structure that is awkward to hand-author, and every query in Stage 2 is already written for parameterised SQL.

### N19 · `Postgres — Insert Coverages`

Runs once per coverage line. Put an **Item Lists → Split Out** node on `extraction.coverages` first, carrying `certificate_id` through.

```sql
INSERT INTO coverages (
  certificate_id, coverage_type, insurer_name, naic, policy_number,
  effective_date, expiration_date, each_occurrence, general_aggregate,
  addl_insd_asserted, subr_wvd_asserted
) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11);
```

**Delete existing coverages for that certificate first**, so a re-processed certificate does not double its lines:

```sql
DELETE FROM coverages WHERE certificate_id = $1;
```

### N20 · `Postgres — Supersede Prior`

`db/queries/q_supersede.sql`. Runs only when `supersede_certificate_id` is non-null.

Superseded certificates are marked, never deleted. **The audit trail is the product** — when a client asks "what did we know and when did we know it?", the answer must exist.

### N21 · `IF — Was Insert`

Condition: `{{ $json.was_insert }}` is true.

- **True** → notify. A genuinely new certificate.
- **False** → NoOp. The same PDF arrived again (re-delivered email, vendor forwarded it twice, you re-ran a fixture). Updating the row is correct; announcing it is noise.

### N22 · `Notify Manager`

Two variants; the Telegram one is what you use while building because it tells you a workflow ran without opening n8n.

**Telegram** · `n8n-nodes-base.telegram` · Operation `Send Message`

- Chat ID: `={{ $('04 Validate').item.json.config.telegram_chat_id }}`
- Parse Mode: `HTML`
- Text:

```
={{ (() => { const v = $('04 Validate').item.json; return
  v.status === 'NEEDS_REVIEW'
  ? `⚠️ <b>Needs review</b> — ${v.extraction.vendor_legal_name}\n` +
    `${v.flags.map(f => '• ' + f.code + (f.detail ? ': ' + f.detail : '')).join('\n')}`
  : `✅ <b>Certificate filed</b> — ${v.extraction.vendor_legal_name}\n` +
    `Carrier: ${v.extraction.coverages[0]?.insurer_name ?? '—'}\n` +
    `Earliest expiry: ${v.earliest_expiration ?? '—'}` +
    (v.coverage_gap_days ? `\n🔶 ${v.coverage_gap_days}-day coverage gap before this policy` : '');
})() }}
```

> **Bind the context by node name.** This node sits three hops downstream of `04 Validate`, behind two Postgres nodes — and a Postgres node replaces the item's json with its query result. A bare `$json.extraction` here is `undefined`. Same rule everywhere downstream of a Postgres node ([§12.7](12-n8n-operations-cookbook.md)).

Note what this message does *not* say. Not "compliant", not "verified", not "covered". `Certificate filed` and a date. The constraint is enforced here as much as on the dashboard, because a Telegram message on a prospect's phone is user-facing output.

### N23 · `Postgres — Dead Letter`

Every reject path converges here.

```sql
INSERT INTO dead_letter (source, source_ref, original_filename, content_sha256,
                         reason_code, reason_detail, raw_payload)
VALUES ($1,$2,$3,$4,$5,$6,$7::jsonb)
RETURNING id;
```

Then a manager notice naming the vendor or sender and the reason in plain English:

```
🚫 Not filed — {{ $json.original_filename || $json.from_address }}
{{ ({
  NOT_A_PDF:                 'The attachment is not a PDF.',
  PDF_ENCRYPTED:             'The PDF is password-protected. Ask the sender for an unlocked copy.',
  PDF_UNREADABLE:            'The PDF could not be opened.',
  EMPTY_ATTACHMENT:          'The attachment was empty.',
  NO_ATTACHMENT_TEXT_REPLY:  'A reply with no attachment. Probably needs a person to read it.',
  NO_ATTACHMENT_PORTAL_LINK: 'A download link with no attachment. Not fetched — someone needs to retrieve it.',
  NOT_A_COI:                 'This document is not a certificate of insurance. Nothing was filed.',
  MODEL_REFUSED:             'The extraction step declined to process this document.',
  MODEL_ERROR:               'The extraction step failed. It will be retried.',
  JSON_PARSE_FAILED:         'The extraction returned something unreadable.'
})[$json.reason_code] || $json.reason_detail }}
```

---

## 5.3 Error Trigger workflow

Build this now, not in production. It costs ten minutes and it is how you find out a demo rehearsal failed.

New workflow `COI · 0 · Errors`:

- **Error Trigger** (`n8n-nodes-base.errorTrigger`)
- **Telegram — Send Message**:

```
={{ `🔴 <b>Workflow failed</b>\n` +
   `${$json.workflow?.name ?? 'unknown workflow'}\n` +
   `${$json.execution ? `Node: ${$json.execution.lastNodeExecuted ?? '—'}\n` : 'Activation failure\n'}` +
   `${$json.execution?.error?.message ?? $json.trigger?.error?.message ?? 'no message'}\n` +
   `${$json.execution?.url ?? ''}` }}
```

> **The Error Trigger emits two different payload shapes and you must read both.** A node-execution failure gives `{ execution: { error, lastNodeExecuted, url }, workflow }`. A **workflow-activation** failure gives `{ trigger: { error }, workflow }` — **no `execution` key at all**. A manual-trigger-only workflow with an error workflow registered produces the second shape on *every restart*, so reading only `$json.execution.*` means the alert telling you a workflow failed to come up is itself blank. See [§12.8](12-n8n-operations-cookbook.md).

Then in each COI workflow: **Settings → Error Workflow → `COI · 0 · Errors`**.

> When this goes into workflow JSON, every `\n` above must be written `\\n` — a JSON-decoded expression cannot carry a literal newline inside a quoted JS string ([§12.2](12-n8n-operations-cookbook.md)). Same applies to the Telegram and dead-letter messages above.

---

## 5.4 Testing this stage

Run in this exact order. Each step depends on the state the previous left.

```bash
make demo-reset
```

| # | Action | Expected |
|---|---|---|
| 1 | Upload `f01-clean-current.pdf` via the form | Vaughn Electric matched · 1 certificate `ON_FILE` · **3** coverage rows · confidence HIGH · Telegram "Certificate filed" |
| 2 | Upload the **same file again** | No new certificate row · `was_insert = false` · **no** Telegram message |
| 3 | Upload `f04-scanned.pdf` | Routes to the **vision** branch · `extraction_method = 'vision'` · confidence **MEDIUM** · `confidence_reason` names a field |
| 4 | Upload `f05-inverted-dates.pdf` | `status = NEEDS_REVIEW` · flag `DATE_INVERTED` · Telegram "Needs review" listing the flag |
| 5 | Upload `f11-not-a-coi.pdf` | **Zero** vendor and certificate rows · one `dead_letter` row `NOT_A_COI` · manager notice |
| 6 | Upload `f18-encrypted.pdf` | `dead_letter` `PDF_ENCRYPTED` · **no crashed execution** · readable notice |
| 7 | Email `f02` to the intake address | Same result within ~60 s · `source = 'email'` · `source_ref` is the Gmail message ID |
| 8 | Email `f10a` **and** `f10b` in one message | **Two** independent certificate rows |
| 9 | Send `f19-portal-link.eml` content as an email body | `dead_letter` `NO_ATTACHMENT_PORTAL_LINK` · **no HTTP request to the link** |
| 10 | Upload `f12-renewal.pdf` after `f02` | `f02`'s certificate → `SUPERSEDED` with `superseded_by` set · new row `ON_FILE` |
| 11 | Upload `f03` then `f13` | `f13` carries `COVERAGE_GAP` with `coverage_gap_days = 14` |
| 12 | Upload `f17-near-duplicate.pdf` | `NEEDS_REVIEW` · `POSSIBLE_DUPLICATE_VENDOR` · **`vendor_id` is NULL** — no merge |

### Verification query

```sql
SELECT c.id,
       v.display_name,
       c.status,
       c.extraction_confidence,
       c.extraction_method,
       e.earliest_expiration,
       e.coverage_line_count,
       c.coverage_gap_days,
       c.validation_flags
FROM   certificates c
LEFT   JOIN vendors v ON v.id = c.vendor_id
LEFT   JOIN v_certificate_expiry e ON e.certificate_id = c.id
ORDER  BY c.id;

SELECT reason_code, count(*), max(created_at) FROM dead_letter GROUP BY 1;
```

### Step 9 deserves its own note

Confirm no outbound HTTP request was made to the portal URL. Open the execution and check the node list — there should be no HTTP Request node in that branch at all.

**Never fetch a link that arrived in an email.** It is an unauthenticated fetch of an attacker-controllable URL from inside your client's network perimeter, triggered by anyone who can email the intake address. Hand it to a human. This is a security boundary, not a feature gap.

---

## 5.5 Export the workflow

```bash
# In n8n: workflow menu → Download
# Save to n8n/workflows/wf1-intake.json, then verify no secrets leaked:
grep -iE '"(sk-|Bearer |password|apiKey)"' n8n/workflows/wf1-intake.json && echo "LEAK" || echo "clean"
```

n8n exports credential *references* by ID, not values. The grep is belt-and-braces, and it is in the Stage 8 test suite.

---

## Stage 5 exit checklist

- [ ] Form Trigger URL is public and accepts multiple PDFs
- [ ] Gmail Trigger polls `COI-INTAKE` and downloads attachments
- [ ] All 12 test cases above produce their expected result
- [ ] The same PDF uploaded twice creates **one** row and **one** notification
- [ ] Encrypted PDF dead-letters with a readable reason; no crashed execution
- [ ] Portal-link email produces a notice and **no outbound fetch**
- [ ] Non-certificate creates zero vendor and certificate rows
- [ ] Supersede sets `superseded_by`; the old row is marked, not deleted
- [ ] Coverage gap computes 14 days for `f13`
- [ ] Near-duplicate leaves `vendor_id` NULL
- [ ] Error Trigger workflow wired to this workflow's settings
- [ ] Workflow exported; secret scan clean

→ Continue to [Stage 6 — Watch & chase workflow](07-stage-6-watch-and-chase-workflow.md)
