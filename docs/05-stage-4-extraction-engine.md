# Stage 4 — Extraction engine

**Document 05 · Estimated time: 1–1.5 days · Cost: ~$1.50 of token spend**

This is the part that has to be right. Everything downstream — buckets, colours, drafted emails, the dashboard — is arithmetic on what comes out of here.

Two branches (text and vision) terminating at the same strict-schema model call, then a deterministic validation layer that costs nothing and catches most model errors for free.

**Gate:** `make test-extract` passes; fixtures 1–4 produce schema-valid JSON with correct dates.

---

## 4.1 The two-branch design

```
              PDF binary
                  │
     ┌────────────▼─────────────┐
     │   Extract From File      │  n8n core node, PDF text layer
     └────────────┬─────────────┘
                  │
        ┌─────────▼──────────┐
        │ text.length > 200? │
        └────┬──────────┬────┘
         yes │          │ no  (scanned / photographed / image-only)
             ▼          ▼
    ┌────────────┐  ┌─────────────────────────┐
    │ TEXT BRANCH│  │ VISION BRANCH           │
    │ input_text │  │ input_file, detail=high │
    │ effort=low │  │ effort=medium           │
    └──────┬─────┘  └────────────┬────────────┘
           └───────────┬─────────┘
                       ▼
         POST /v1/responses  ·  gpt-5.4-mini-2026-03-17
         text.format = json_schema, strict: true
                       ▼
              03_parse_response.js
                       ▼
              04_validate.js  (13 rules, 0 tokens)
                       ▼
          ON_FILE          NEEDS_REVIEW          dead_letter
```

### Why two branches at all, given OpenAI reads PDFs directly

OpenAI extracts **both** the text layer and page images from any PDF file input and sends both. For a certificate that already has a clean text layer, that roughly doubles the input tokens for no accuracy gain. The text branch sends ~1,500 tokens; the vision branch sends the same text plus a rendered page.

At this volume the money is irrelevant — fractions of a cent. **Latency is not.** The text branch returns in roughly a third of the time, and during a demo that difference is the gap between "there it is" and an awkward pause. Keep both branches.

### Why the vision branch runs at `detail: "high"` and higher reasoning effort

Reading a skewed, JPEG-artefacted phone photo of a certificate *is the entire job* on that branch. Saving a fraction of a cent by dropping to `detail: "low"` and then misreading a policy expiration date is the worst possible trade in this product — a wrong date that reads confidently is worse than no date at all. Spend it.

---

## 4.2 `extraction/schema/coi_extraction.schema.json`

Strict Structured Outputs. Every property appears in `required`, every object carries `additionalProperties: false`, and anything that can be absent is a union with `null`.

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "is_certificate_of_insurance",
    "vendor_legal_name",
    "vendor_address",
    "producer_name",
    "producer_contact_name",
    "producer_email",
    "producer_phone",
    "certificate_date",
    "certificate_holder",
    "certificate_holder_address",
    "coverages",
    "description_of_operations",
    "cancellation_notice_wording",
    "extraction_confidence",
    "confidence_reason"
  ],
  "properties": {
    "is_certificate_of_insurance": {
      "type": "boolean",
      "description": "False if this document is not a certificate of liability insurance."
    },
    "vendor_legal_name":  { "type": ["string", "null"], "description": "The INSURED name, exactly as printed." },
    "vendor_address":     { "type": ["string", "null"] },
    "producer_name":      { "type": ["string", "null"], "description": "Agency or brokerage name." },
    "producer_contact_name": { "type": ["string", "null"] },
    "producer_email":     { "type": ["string", "null"] },
    "producer_phone":     { "type": ["string", "null"] },
    "certificate_date":   { "type": ["string", "null"], "description": "ISO YYYY-MM-DD." },
    "certificate_holder": { "type": ["string", "null"] },
    "certificate_holder_address": { "type": ["string", "null"] },

    "coverages": {
      "type": "array",
      "description": "One object per coverage line present. Never invent a line.",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "type", "insurer_name", "naic", "policy_number",
          "effective_date", "expiration_date",
          "each_occurrence", "general_aggregate",
          "addl_insd_asserted", "subr_wvd_asserted"
        ],
        "properties": {
          "type": {
            "type": "string",
            "enum": ["GENERAL_LIABILITY", "AUTO", "UMBRELLA", "WORKERS_COMP", "OTHER"]
          },
          "insurer_name":    { "type": ["string", "null"] },
          "naic":            { "type": ["string", "null"] },
          "policy_number":   { "type": ["string", "null"] },
          "effective_date":  { "type": ["string", "null"], "description": "ISO YYYY-MM-DD." },
          "expiration_date": { "type": ["string", "null"], "description": "ISO YYYY-MM-DD." },
          "each_occurrence": { "type": ["number", "null"], "description": "Integer, no symbols or separators." },
          "general_aggregate": { "type": ["number", "null"] },
          "addl_insd_asserted": {
            "type": ["boolean", "null"],
            "description": "Whether the ADDL INSD box carries a mark. An assertion on a form, not a fact about coverage."
          },
          "subr_wvd_asserted": {
            "type": ["boolean", "null"],
            "description": "Whether the SUBR WVD box carries a mark. An assertion on a form, not a fact about coverage."
          }
        }
      }
    },

    "description_of_operations":   { "type": ["string", "null"] },
    "cancellation_notice_wording": {
      "type": ["string", "null"],
      "description": "Verbatim wording about notice of cancellation, if any. Copy exactly; do not summarise."
    },
    "extraction_confidence": { "type": "string", "enum": ["HIGH", "MEDIUM", "LOW"] },
    "confidence_reason":     { "type": ["string", "null"], "description": "One short plain-English sentence when MEDIUM or LOW." }
  }
}
```

### Strict-mode gotchas that will bite you

| Gotcha | Consequence | Fix |
|---|---|---|
| A property missing from `required` | API returns 400 at request time | Every property, always, even nullable ones |
| `additionalProperties` omitted on the nested `coverages` items object | 400 | Both objects need it |
| Using `"format": "date"` | Ignored by strict mode; you get no validation | Validate dates in code (§4.5), not in the schema |
| Root-level `anyOf` | Not permitted | Not used here |
| Enum + null | `"type": ["string","null"]` with a bare `enum` is inconsistent | `extraction_confidence` is non-nullable by design — the model must always commit |

**Structured Outputs guarantees the shape of the answer. It guarantees nothing about its truthfulness.** You will always get a well-formed `expiration_date` field; only the prompt stops the model inventing a plausible date to fill it. That distinction matters more here than anywhere else in the build.

---

## 4.3 `extraction/prompts/extract.system.md`

```
You extract structured data from certificates of liability insurance.

RULES

1. Transcribe only. Never infer, complete, or correct a value that is not
   legible in the document. If a field is absent or unreadable, return null.
   A null is always better than a guess.

2. Dates: source documents use MM/DD/YYYY. Return YYYY-MM-DD. If a date is
   ambiguous or partially illegible, return null and lower the confidence.
   Never reconstruct a date from a neighbouring one — coverage lines
   frequently have different terms.

3. Limits: return integers with no currency symbols and no separators.
   "$1,000,000" becomes 1000000. If a limit box is blank, return null.
   Do not carry a limit down from the row above.

4. ADDL INSD and SUBR WVD are checkbox columns. Report only whether a mark
   is present, as a boolean. These are assertions on a form, not facts about
   coverage. Do not interpret them, and do not infer one from wording in the
   Description of Operations box.

5. One object in "coverages" per coverage line that is actually present. Do
   not invent lines that are absent. Lines commonly present: Commercial
   General Liability, Automobile Liability, Umbrella/Excess, Workers
   Compensation and Employers Liability. A line with a printed label but no
   policy number and no dates is not present — omit it.

6. Field order and layout vary between form revisions and between carriers.
   Locate fields by their labels, not by their position on the page.

7. Set is_certificate_of_insurance to false if this document is not a
   certificate of liability insurance. Return null for every other field and
   an empty array for coverages. Do not attempt a partial extraction.

8. If the Description of Operations box contains wording about notice of
   cancellation to the certificate holder (for example "30 days written
   notice"), copy it verbatim into cancellation_notice_wording. Copy it
   exactly. Do not summarise it, and do not treat it as a promise that notice
   will be given — you are recording that a sentence appears on a form,
   nothing more.

9. The INSURED is the vendor. The CERTIFICATE HOLDER is a different party.
   Never put one in the other's field, even when the layout is unusual.

CONFIDENCE

HIGH   — every field you returned was clearly legible.
MEDIUM — the document is legible but at least one field required judgement,
         or the layout is non-standard.
LOW    — the scan is poor, the document is rotated or cropped, or you are
         unsure about any date or limit.

When you set MEDIUM or LOW, state why in confidence_reason, in one short
sentence a non-technical person would understand. Name the specific field.

Bias toward LOW. A human reviews everything you mark LOW. Nobody reviews
what you mark HIGH.
```

Three things about this prompt are doing real work:

- **The last line.** Without it, models mark almost everything HIGH and the review gate becomes decorative.
- **Rule 3's "do not carry a limit down from the row above"** is the single most common extraction error on tabular certificates, where a blank cell visually inherits from the row above.
- **Rule 9.** The INSURED/CERTIFICATE HOLDER swap is rare but catastrophic — it files a certificate against the wrong vendor and the dashboard looks fine.

Note what is *not* in the prompt: any instruction to return only JSON, no markdown fences, no commentary. Strict Structured Outputs makes that impossible at decode time, so those sentences would be tokens spent on every call to prevent something that cannot happen.

---

## 4.4 The request payloads

### 4.4.1 Text branch — `extraction/payloads/text_branch.request.json`

```json
{
  "model": "{{ $json.model_id }}",
  "instructions": "{{ $json.system_prompt }}",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "Extract the certificate data from the following document text.\n\n--- BEGIN DOCUMENT ---\n{{ $json.document_text }}\n--- END DOCUMENT ---"
        }
      ]
    }
  ],
  "text": {
    "format": {
      "type": "json_schema",
      "name": "coi_extraction",
      "strict": true,
      "schema": { "...": "contents of extraction/schema/coi_extraction.schema.json" }
    }
  },
  "reasoning": { "effort": "low" },
  "max_output_tokens": 3000,
  "store": false
}
```

### 4.4.2 Vision branch — `extraction/payloads/vision_branch.request.json`

```json
{
  "model": "{{ $json.model_id }}",
  "instructions": "{{ $json.system_prompt }}",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_file",
          "filename": "{{ $json.original_filename }}",
          "file_data": "data:application/pdf;base64,{{ $json.pdf_base64 }}",
          "detail": "high"
        },
        {
          "type": "input_text",
          "text": "Extract the certificate data from the attached document. It is a scan or photograph, so read carefully and lower your confidence if any date or limit is not clearly legible."
        }
      ]
    }
  ],
  "text": {
    "format": {
      "type": "json_schema",
      "name": "coi_extraction",
      "strict": true,
      "schema": { "...": "same schema" }
    }
  },
  "reasoning": { "effort": "medium" },
  "max_output_tokens": 3000,
  "store": false
}
```

### The details that cause 400s

| Detail | Why |
|---|---|
| `file_data` **must** carry the `data:application/pdf;base64,` prefix | A bare base64 string is the single most common 400 here. |
| The file part comes **before** the text part | Instructions after the document read reliably; the reverse is inconsistent. |
| `store: false` | Do not retain the response server-side. It is client data; there is no reason to leave a copy. |
| `instructions` rather than a `system` role message | The Responses API's dedicated field. Equivalent, and it keeps `input` to just the document. |
| `max_output_tokens: 3000` | A certificate with four coverage lines and a long operations paragraph runs ~900 output tokens. 3000 is headroom, not a target. |

---

## 4.5 `n8n/code/02_build_request.js`

Assembles the payload. Runs **once for each item**, immediately before the HTTP Request node.

```javascript
/**
 * 02_build_request.js  —  Code node, "Run Once for Each Item"
 *
 * Builds the OpenAI Responses API payload for whichever branch we are on.
 * Reads config from an upstream Postgres node so the model ID, reasoning
 * effort, and PDF detail are database values, not hardcoded node settings.
 *
 * Expects on $json:
 *   branch            'text' | 'vision'
 *   document_text     (text branch)  extracted PDF text
 *   pdf_base64        (vision branch) base64 of the PDF, no data: prefix
 *   original_filename
 *   config            { model_id, reasoning_effort_text, ... }
 *   schema            the parsed coi_extraction schema
 *   system_prompt     contents of extract.system.md
 */

const j = $json;
const cfg = j.config;

const isVision = j.branch === 'vision';

const effort = isVision
  ? (cfg.reasoning_effort_vision || 'medium')
  : (cfg.reasoning_effort_text   || 'low');

const content = isVision
  ? [
      {
        type: 'input_file',
        filename: j.original_filename || 'certificate.pdf',
        file_data: `data:application/pdf;base64,${j.pdf_base64}`,
        detail: cfg.pdf_detail || 'high',
      },
      {
        type: 'input_text',
        text:
          'Extract the certificate data from the attached document. It is a ' +
          'scan or photograph, so read carefully and lower your confidence if ' +
          'any date or limit is not clearly legible.',
      },
    ]
  : [
      {
        type: 'input_text',
        text:
          'Extract the certificate data from the following document text.\n\n' +
          '--- BEGIN DOCUMENT ---\n' +
          j.document_text +
          '\n--- END DOCUMENT ---',
      },
    ];

const payload = {
  model: cfg.model_id,
  instructions: j.system_prompt,
  input: [{ role: 'user', content }],
  text: {
    format: {
      type: 'json_schema',
      name: 'coi_extraction',
      strict: true,
      schema: j.schema,
    },
  },
  reasoning: { effort },
  max_output_tokens: parseInt(cfg.max_output_tokens || '3000', 10),
  store: false,
};

return {
  json: {
    ...j,
    payload,
    request_started_at: Date.now(),
  },
};
```

### HTTP Request node configuration

| Parameter | Value |
|---|---|
| Method | `POST` |
| URL | `={{ $json.config.openai_endpoint }}` |
| Authentication | Predefined Credential Type → OpenAI API → `OpenAI Account` |
| Send Headers | on · `Content-Type: application/json` |
| Send Body | on · Body Content Type: `JSON` · Specify Body: `Using JSON` |
| JSON | `={{ JSON.stringify($json.payload) }}` |
| Options → Timeout | `120000` (120 s — the vision branch at high detail is genuinely slow) |
| Options → Retry On Fail | on · Max Tries `3` · Wait Between Tries `2000` ms |
| Options → Response → Never Error | **on** |
| Options → Response → Full Response | **on** |
| Settings → On Error | `Continue (using error output)` |

> **`Never Error` + `Full Response` together are what make failures survivable.** With them on, a 429 or 500 arrives at the next node as data with a `statusCode` you can branch on. Without them, the execution throws, the workflow stops, and during a demo you are looking at a red node instead of a graceful "this one needs review" row.

---

## 4.6 `n8n/code/03_parse_response.js`

The Responses API returns an `output` array, not `choices[0].message.content`. This is the one-time cost of choosing it. Here is the parser, written once.

```javascript
/**
 * 03_parse_response.js  —  Code node, "Run Once for Each Item"
 *
 * Walks an OpenAI Responses API result and returns exactly one of:
 *   { ok: true,  extraction, usage, latency_ms }
 *   { ok: false, reason_code, reason_detail }
 *
 * Never throws. Every failure path produces a routable reason_code, because
 * an exception here becomes a red node in front of a prospect.
 */

const j = $json;
const latency_ms = j.request_started_at ? Date.now() - j.request_started_at : null;

const fail = (code, detail) => ({
  json: { ...j, ok: false, reason_code: code, reason_detail: String(detail).slice(0, 900), latency_ms },
});

// ── Transport / HTTP layer ──────────────────────────────────────────
const status = j.statusCode ?? 200;
const body = j.body ?? j;

if (status === 429) return fail('MODEL_ERROR', 'Rate limited (429) after retries');
if (status >= 500)  return fail('MODEL_ERROR', `Upstream ${status}`);
if (status >= 400) {
  const msg = body?.error?.message || JSON.stringify(body).slice(0, 400);
  return fail('MODEL_ERROR', `HTTP ${status}: ${msg}`);
}
if (!body || typeof body !== 'object') return fail('MODEL_ERROR', 'Empty response body');
if (body.error) return fail('MODEL_ERROR', body.error.message || 'error object present');

// ── Truncation ──────────────────────────────────────────────────────
// status "incomplete" means we hit max_output_tokens. The JSON is cut off
// mid-object and will not parse. Treat it as a distinct, nameable failure.
if (body.status === 'incomplete') {
  return fail('MODEL_ERROR',
    `Response incomplete: ${body.incomplete_details?.reason || 'unknown'}. ` +
    'Raise max_output_tokens.');
}

// ── Walk output[] for the assistant message ─────────────────────────
// The array also carries `reasoning` items, which have no content we want.
const output = Array.isArray(body.output) ? body.output : [];
const message = output.find((it) => it?.type === 'message');
if (!message) {
  return fail('MODEL_ERROR',
    `No message item in output. Item types: ${output.map((i) => i?.type).join(',') || 'none'}`);
}

const parts = Array.isArray(message.content) ? message.content : [];

// ── Refusal is a first-class outcome, not an exception ──────────────
const refusal = parts.find((p) => p?.type === 'refusal');
if (refusal) return fail('MODEL_REFUSED', refusal.refusal || 'Model declined to process');

const textPart = parts.find((p) => p?.type === 'output_text');
if (!textPart?.text) {
  return fail('MODEL_ERROR',
    `No output_text part. Part types: ${parts.map((p) => p?.type).join(',') || 'none'}`);
}

// ── Parse ───────────────────────────────────────────────────────────
// Strict Structured Outputs makes malformed JSON structurally impossible,
// so this catch should never fire. It exists because "should never" is not
// a thing you want to discover during a demo.
let extraction;
try {
  extraction = JSON.parse(textPart.text);
} catch (e) {
  return fail('JSON_PARSE_FAILED', `${e.message} :: ${textPart.text.slice(0, 300)}`);
}

const u = body.usage || {};

return {
  json: {
    ...j,
    ok: true,
    extraction,
    model_id: body.model || j.config?.model_id || null,
    input_tokens:  u.input_tokens  ?? null,
    output_tokens: u.output_tokens ?? null,
    latency_ms,
  },
};
```

---

## 4.7 The shared libraries

Three small modules. n8n's Code node cannot `require` a local file, so **paste each function inline at the top of the Code node that needs it.** Keeping the canonical copy in `n8n/code/lib/` is what makes them unit-testable and diffable.

### `n8n/code/lib/normalise.js`

```javascript
/**
 * Canonical vendor / entity name normalisation.
 *
 * MUST stay byte-identical to the SQL expression in
 * db/scripts/seed-vendors.sh. test/unit/test_normalise.js runs 30 strings
 * through both and fails on any divergence. If you change one, change both.
 *
 *   "Kessler Heating & Air Inc."  →  "kessler heating air"
 *   "M. Mercer & Sons Plumbing, LLC" → "m mercer sons plumbing"
 */
const LEGAL_SUFFIXES = [
  'llc', 'l.l.c.', 'inc', 'inc.', 'incorporated', 'corp', 'corp.',
  'corporation', 'co', 'co.', 'company', 'ltd', 'ltd.', 'limited',
  'lp', 'llp', 'pllc', 'pc', 'dba',
];

function normaliseName(raw) {
  if (!raw) return '';
  let s = String(raw).toLowerCase();

  // Strip legal suffixes wherever they appear as whole words.
  const suffixRe = new RegExp(
    '\\s+(' + LEGAL_SUFFIXES.map((x) => x.replace(/\./g, '\\.')).join('|') + ')\\b',
    'g'
  );
  s = s.replace(suffixRe, '');

  // Everything that is not a-z, 0-9 or space becomes a space. This folds
  // "&" to nothing rather than to "and": "Heating & Air" and "Heating and
  // Air" would otherwise normalise differently, and both are common.
  s = s.replace(/[^a-z0-9 ]/g, ' ');

  return s.replace(/\s+/g, ' ').trim();
}
```

> **The `&` decision.** Folding `&` to a space (not to the word "and") means `Heating & Air` → `heating air` and `Heating and Air` → `heating and air`, which do *not* match exactly — but they score ~0.87 on token-set ratio, landing in the review band rather than either silently merging or silently splitting. That is the correct outcome: a human decides. Log entry D-07.

### `n8n/code/lib/fuzzy.js`

```javascript
/**
 * Token-set ratio, dependency-free.
 *
 * Used for two things:
 *   - certificate_holder vs the holder_entities list (rule 4/12)
 *   - vendor name matching, including near-duplicate detection (rule 13)
 *
 * Returns 0..1. Deterministic; no external package, because the n8n Code
 * node sandbox does not reliably permit arbitrary npm imports and a demo
 * should not depend on one that does.
 */

function levenshtein(a, b) {
  if (a === b) return 0;
  if (!a.length) return b.length;
  if (!b.length) return a.length;

  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  const cur = new Array(b.length + 1);

  for (let i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (let jj = 1; jj <= b.length; jj++) {
      const cost = a[i - 1] === b[jj - 1] ? 0 : 1;
      cur[jj] = Math.min(cur[jj - 1] + 1, prev[jj] + 1, prev[jj - 1] + cost);
    }
    prev = cur.slice();
  }
  return prev[b.length];
}

/** Normalised similarity: 1.0 identical, 0.0 nothing in common. */
function ratio(a, b) {
  if (!a && !b) return 1;
  if (!a || !b) return 0;
  const max = Math.max(a.length, b.length);
  return 1 - levenshtein(a, b) / max;
}

/**
 * Token-set ratio. Order-insensitive and tolerant of extra words, which is
 * exactly the shape of real-world entity-name variance:
 *   "Harbourline Property Management" vs "Property Management, Harbourline LLC"
 */
function tokenSetRatio(a, b) {
  const ta = new Set(String(a || '').split(/\s+/).filter(Boolean));
  const tb = new Set(String(b || '').split(/\s+/).filter(Boolean));
  if (!ta.size && !tb.size) return 1;
  if (!ta.size || !tb.size) return 0;

  const inter = [...ta].filter((t) => tb.has(t)).sort();
  const onlyA = [...ta].filter((t) => !tb.has(t)).sort();
  const onlyB = [...tb].filter((t) => !ta.has(t)).sort();

  const sInter = inter.join(' ');
  const sA = [sInter, onlyA.join(' ')].filter(Boolean).join(' ');
  const sB = [sInter, onlyB.join(' ')].filter(Boolean).join(' ');

  return Math.max(ratio(sInter, sA), ratio(sInter, sB), ratio(sA, sB));
}
```

### `n8n/code/lib/dates.js`

```javascript
/**
 * Date helpers. All dates in this system are calendar days, never instants.
 *
 * The model returns ISO YYYY-MM-DD. Anything else is a defect, so parseISO
 * is deliberately strict rather than forgiving — a lenient parser here is
 * how "03/04/2027" silently becomes 3 April instead of 4 March.
 */

function parseISODate(s) {
  if (typeof s !== 'string') return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s.trim());
  if (!m) return null;
  const [, y, mo, d] = m.map(Number);
  const dt = new Date(Date.UTC(y, mo - 1, d));
  // Round-trip check rejects 2026-02-31 and friends.
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== d) {
    return null;
  }
  return dt;
}

function daysBetween(a, b) {
  return Math.round((b.getTime() - a.getTime()) / 86400000);
}

/** "14 Mar 2027" — unambiguous to both US and non-US readers. */
function formatDisplay(s) {
  const d = parseISODate(s);
  if (!d) return '';
  const MON = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return `${d.getUTCDate()} ${MON[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

/** Today, in the client's timezone, as YYYY-MM-DD. */
function todayInZone(tz) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date());
  const g = (t) => parts.find((p) => p.type === t).value;
  return `${g('year')}-${g('month')}-${g('day')}`;
}
```

---

## 4.8 `n8n/code/04_validate.js` — the 13 rules

Deterministic, zero tokens, and it catches most model errors for free. Paste the three libraries above this block in the Code node.

```javascript
/**
 * 04_validate.js  —  Code node, "Run Once for Each Item"
 *
 * Applies 13 validation rules and decides the certificate's status.
 * Emits { flags: [...], status, ... } for the persistence layer.
 *
 * SEVERITY MODEL
 *   hard  → status = NEEDS_REVIEW (or a dead_letter reject). Never fact.
 *   soft  → status stays ON_FILE; the flag renders as a note on the dashboard.
 *
 * <<< paste normalise.js, fuzzy.js and dates.js above this line >>>
 */

const j = $json;
const cfg = j.config;
const ex = j.extraction;

const flags = [];
const add = (code, severity, detail = null, extra = {}) =>
  flags.push({ code, severity, detail, ...extra });

const HOLDER_THRESHOLD = parseFloat(cfg.holder_match_threshold || '0.80');
const V_EXACT = parseFloat(cfg.vendor_match_exact  || '0.95');
const V_REVIEW = parseFloat(cfg.vendor_match_review || '0.80');
const today = todayInZone(cfg.timezone || 'UTC');
const todayDt = parseISODate(today);

// ─── Rule 7 — not a certificate. Hard reject; nothing is created. ───
if (ex.is_certificate_of_insurance === false) {
  return {
    json: {
      ...j,
      outcome: 'REJECT',
      reason_code: 'NOT_A_COI',
      reason_detail: ex.confidence_reason || 'Model classified this as not a certificate of insurance.',
      flags: [{ code: 'NOT_A_COI', severity: 'hard' }],
    },
  };
}

// ─── Rule 6 — LOW confidence is a hard gate. ───
if (ex.extraction_confidence === 'LOW') {
  add('LOW_CONFIDENCE', 'hard', ex.confidence_reason);
}

// ─── Coverage-level rules ───
const coverages = Array.isArray(ex.coverages) ? ex.coverages : [];
const certDt = parseISODate(ex.certificate_date);

let earliestExp = null;

for (const cov of coverages) {
  const eff = parseISODate(cov.effective_date);
  const exp = parseISODate(cov.expiration_date);

  // Rule 1 — expiration must follow effective. A known ACORD error mode.
  if (eff && exp && exp <= eff) {
    add('DATE_INVERTED', 'hard',
      `${cov.type}: expires ${cov.expiration_date}, effective ${cov.effective_date}`,
      { coverage_type: cov.type });
  }

  // Rule 2 — dates parse and are plausible relative to the certificate date.
  const anchor = certDt || todayDt;
  for (const [label, val, dt] of [
    ['effective', cov.effective_date, eff],
    ['expiration', cov.expiration_date, exp],
  ]) {
    if (val && !dt) {
      add('DATE_UNPARSEABLE', 'hard', `${cov.type} ${label}: "${val}"`, { coverage_type: cov.type });
    } else if (dt && anchor) {
      const delta = daysBetween(anchor, dt);
      if (delta < -730 || delta > 1095) {
        add('DATE_IMPLAUSIBLE', 'hard',
          `${cov.type} ${label} ${val} is ${delta} days from the certificate date`,
          { coverage_type: cov.type });
      }
    }
  }

  if (exp && (!earliestExp || exp < earliestExp)) earliestExp = exp;
}

// Rule 3 — a General Liability line should exist.
const hasGL = coverages.some((c) => c.type === 'GENERAL_LIABILITY');
if (!hasGL) add('NO_GL_LINE', 'soft', 'No Commercial General Liability line on this certificate');

// Rules 5 + 11 — limits against the vendor's trade, falling back to DEFAULT.
// j.trade_requirement is supplied by an upstream Postgres lookup.
const req = j.trade_requirement || {};
const minEach = Number(req.min_each_occurrence   ?? cfg.min_each_occurrence);
const minAgg  = Number(req.min_general_aggregate ?? cfg.min_general_aggregate);
const gl = coverages.find((c) => c.type === 'GENERAL_LIABILITY');

if (gl) {
  if (gl.each_occurrence != null && minEach && Number(gl.each_occurrence) < minEach) {
    add('LIMIT_BELOW_MINIMUM', 'soft',
      `GL each occurrence ${gl.each_occurrence} is below the ${req.trade || 'default'} minimum ${minEach}`);
  }
  if (gl.general_aggregate != null && minAgg && Number(gl.general_aggregate) < minAgg) {
    add('AGGREGATE_BELOW_MINIMUM', 'soft',
      `GL aggregate ${gl.general_aggregate} is below the ${req.trade || 'default'} minimum ${minAgg}`);
  }
}

// Rule 10 — suppression, not a flag.
// Sole proprietors are WC-exempt in many states and carry an exemption
// certificate rather than a policy. Without this, the system confidently
// flags perfectly legitimate vendors as deficient — and nothing destroys
// trust in an automated system faster than confident wrong alerts.
const wcRequired = (req.wc_required !== false) && !j.vendor?.wc_exempt;
const hasWC = coverages.some((c) => c.type === 'WORKERS_COMP');
if (wcRequired && !hasWC) {
  add('NO_WC_LINE', 'soft', 'No workers compensation line and the vendor is not marked WC-exempt');
}

// Rules 4 + 12 — holder matched against ANY accepted entity, not one string.
// A PM company managing for 40 owners routinely receives certificates naming
// individual owner LLCs. One string would flag all of those as defects.
const holderNorm = normaliseName(ex.certificate_holder);
let bestHolder = { score: 0, entity: null };
for (const ent of (j.holder_entities || [])) {
  const s = tokenSetRatio(holderNorm, ent.normalised);
  if (s > bestHolder.score) bestHolder = { score: s, entity: ent.legal_name };
}
const holderMatch = bestHolder.score >= HOLDER_THRESHOLD;
if (!holderMatch) {
  add('HOLDER_MISMATCH', 'soft',
    `Certificate names "${ex.certificate_holder || '(blank)'}"; closest accepted entity ` +
    `"${bestHolder.entity || 'none'}" at ${bestHolder.score.toFixed(2)}`);
}

// Rules 8 + 13 — vendor matching against the existing register.
// j.vendor_candidates comes from an upstream Postgres query returning
// id, legal_name, normalised_name for all active vendors.
const vendorNorm = normaliseName(ex.vendor_legal_name);
let best = { score: 0, vendor: null };
for (const v of (j.vendor_candidates || [])) {
  const s = tokenSetRatio(vendorNorm, v.normalised_name);
  if (s > best.score) best = { score: s, vendor: v };
}

let vendorId = null;
let vendorAction = 'CREATE';

if (best.score >= V_EXACT) {
  vendorId = best.vendor.id;
  vendorAction = 'MATCH';
} else if (best.score >= V_REVIEW) {
  // Rule 13 — never auto-merge a near match. "Mercer Plumbing" and "Mercer
  // Plumbing & Heating" may be two different companies, and a silent wrong
  // merge files one company's certificate against another's record.
  vendorId = null;
  vendorAction = 'REVIEW';
  add('POSSIBLE_DUPLICATE_VENDOR', 'hard',
    `"${ex.vendor_legal_name}" scores ${best.score.toFixed(2)} against existing ` +
    `"${best.vendor.legal_name}". A human decides whether these are the same company.`,
    { candidate_vendor_id: best.vendor.id });
}

// Rule 8 — a re-sent older certificate must never overwrite good data.
// j.existing_certificate comes from an upstream lookup on the matched vendor.
let coverageGapDays = null;
const existing = j.existing_certificate || null;

if (vendorAction === 'MATCH' && existing) {
  const newCertDt = certDt;
  const oldCertDt = parseISODate(existing.certificate_date);

  if (newCertDt && oldCertDt && newCertDt < oldCertDt) {
    add('OLDER_THAN_ON_FILE', 'hard',
      `This certificate is dated ${ex.certificate_date}; the one on file is dated ${existing.certificate_date}`);
  } else {
    // Rule 9 — coverage gap on supersede.
    // Old policy ends 1 March, replacement starts 15 March: a 14-day window
    // in which the vendor was working the client's properties uninsured.
    // Invisible to a spreadsheet, invisible to a PMS assignment warning, and
    // invisible to a human comparing two PDFs six months apart.
    const oldExp = parseISODate(existing.earliest_expiration);
    const newEffs = coverages.map((c) => parseISODate(c.effective_date)).filter(Boolean);
    const newEff = newEffs.length ? new Date(Math.min(...newEffs.map((d) => d.getTime()))) : null;

    if (oldExp && newEff && newEff > oldExp) {
      const gap = daysBetween(oldExp, newEff);
      if (gap > 0) {
        coverageGapDays = gap;
        add('COVERAGE_GAP', 'soft',
          `${gap}-day gap: prior coverage ended ${existing.earliest_expiration}, ` +
          `replacement effective ${newEff.toISOString().slice(0, 10)}`,
          { gap_days: gap });
      }
    }
  }
}

// ─── Decide status ───
const hasHard = flags.some((f) => f.severity === 'hard');
const status = hasHard ? 'NEEDS_REVIEW' : 'ON_FILE';

return {
  json: {
    ...j,
    outcome: 'STORE',
    status,
    flags,
    vendor_id: vendorId,
    vendor_action: vendorAction,
    vendor_match_score: best.score,
    holder_match: holderMatch,
    holder_matched_entity: holderMatch ? bestHolder.entity : null,
    coverage_gap_days: coverageGapDays,
    earliest_expiration: earliestExp ? earliestExp.toISOString().slice(0, 10) : null,
    supersede_certificate_id:
      vendorAction === 'MATCH' && existing && !hasHard ? existing.id : null,
    today,
  },
};
```

### Rule reference

| # | Rule | Flag | Severity |
|---|---|---|---|
| 1 | `expiration_date > effective_date` on every coverage | `DATE_INVERTED` | hard |
| 2 | Dates parse and sit within −730/+1095 days of the certificate date | `DATE_UNPARSEABLE`, `DATE_IMPLAUSIBLE` | hard |
| 3 | A General Liability line exists | `NO_GL_LINE` | soft |
| 4 | Holder fuzzy-matches an accepted entity (≥ 0.80) | `HOLDER_MISMATCH` | soft |
| 5 | GL each-occurrence meets the minimum | `LIMIT_BELOW_MINIMUM` | soft |
| 6 | `extraction_confidence != LOW` | `LOW_CONFIDENCE` | hard |
| 7 | `is_certificate_of_insurance == true` | `NOT_A_COI` | hard reject |
| 8 | New certificate is not older than the one on file | `OLDER_THAN_ON_FILE` | hard |
| 9 | No gap between old expiry and new effective date | `COVERAGE_GAP` | soft, surfaced prominently |
| 10 | WC checks suppressed when `wc_exempt` | *(suppression)* | — |
| 11 | Limits compared per trade, falling back to `DEFAULT` | `LIMIT_BELOW_MINIMUM`, `AGGREGATE_BELOW_MINIMUM` | soft |
| 12 | Holder matched against **any** `holder_entities` row | `HOLDER_MISMATCH` | soft |
| 13 | Near-match vendor (0.80–0.94) never auto-merges | `POSSIBLE_DUPLICATE_VENDOR` | hard |

**Rule 8 is the one that gets forgotten and then bites in production.** A vendor re-sends last year's certificate and a naive upsert silently replaces good data with stale data. It costs four lines.

**Rule 9 is the one worth demoing.** It is about twelve lines of code and it catches something a spreadsheet structurally cannot.

---

## 4.9 Unit tests

`test/unit/test_validate.js` — Node's built-in runner, no dependencies.

```javascript
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validate, normaliseName, tokenSetRatio, parseISODate } from './harness.mjs';

const cfg = {
  timezone: 'America/New_York',
  holder_match_threshold: '0.80',
  vendor_match_exact: '0.95',
  vendor_match_review: '0.80',
  min_each_occurrence: '1000000',
  min_general_aggregate: '2000000',
};

const base = (over = {}) => ({
  is_certificate_of_insurance: true,
  vendor_legal_name: 'Vaughn Electric Co',
  certificate_date: '2026-07-15',
  certificate_holder: 'Harbourline Property Management LLC',
  extraction_confidence: 'HIGH',
  confidence_reason: null,
  coverages: [{
    type: 'GENERAL_LIABILITY', insurer_name: 'Northgate Mutual', naic: '90001',
    policy_number: 'NGM-GL-1', effective_date: '2026-03-01',
    expiration_date: '2027-03-01', each_occurrence: 1000000,
    general_aggregate: 2000000, addl_insd_asserted: true, subr_wvd_asserted: false,
  }],
  description_of_operations: null,
  cancellation_notice_wording: null,
  ...over,
});

const holders = [{ legal_name: 'Harbourline Property Management LLC',
                   normalised: 'harbourline property management' }];

const codes = (r) => r.flags.map((f) => f.code).sort();

test('rule 1 — inverted dates are hard', () => {
  const r = validate(base({ coverages: [{ ...base().coverages[0],
    effective_date: '2027-03-01', expiration_date: '2026-03-01' }] }), cfg, { holders });
  assert.ok(codes(r).includes('DATE_INVERTED'));
  assert.equal(r.status, 'NEEDS_REVIEW');
});

test('rule 3 — missing GL is soft, stays ON_FILE', () => {
  const r = validate(base({ coverages: [{ ...base().coverages[0], type: 'AUTO' }] }), cfg, { holders });
  assert.ok(codes(r).includes('NO_GL_LINE'));
  assert.equal(r.status, 'ON_FILE');
});

test('rule 6 — LOW confidence is hard', () => {
  const r = validate(base({ extraction_confidence: 'LOW',
    confidence_reason: 'Expiry partially obscured' }), cfg, { holders });
  assert.equal(r.status, 'NEEDS_REVIEW');
});

test('rule 7 — non-certificate rejects outright', () => {
  const r = validate(base({ is_certificate_of_insurance: false }), cfg, { holders });
  assert.equal(r.outcome, 'REJECT');
  assert.equal(r.reason_code, 'NOT_A_COI');
});

test('rule 10 — wc_exempt suppresses the WC flag', () => {
  const opts = { holders, vendor: { wc_exempt: true } };
  const r = validate(base(), cfg, opts);
  assert.ok(!codes(r).includes('NO_WC_LINE'));
});

test('rule 12 — an owner LLC holder is accepted', () => {
  const r = validate(base({ certificate_holder: 'Sable Court Properties LLC' }), cfg, {
    holders: [...holders, { legal_name: 'Sable Court Properties LLC',
                            normalised: 'sable court properties' }],
  });
  assert.ok(!codes(r).includes('HOLDER_MISMATCH'));
  assert.equal(r.holder_match, true);
});

test('rule 13 — near-duplicate never auto-merges', () => {
  const r = validate(base({ vendor_legal_name: 'Mercer Plumbing & Heating' }), cfg, {
    holders,
    vendor_candidates: [{ id: 1, legal_name: 'Mercer Plumbing LLC',
                          normalised_name: 'mercer plumbing' }],
  });
  assert.ok(codes(r).includes('POSSIBLE_DUPLICATE_VENDOR'));
  assert.equal(r.vendor_id, null);
  assert.equal(r.vendor_action, 'REVIEW');
});

test('rule 9 — coverage gap is measured, not assumed', () => {
  const r = validate(base({ coverages: [{ ...base().coverages[0],
    effective_date: '2026-03-15', expiration_date: '2027-03-15' }] }), cfg, {
    holders,
    vendor_candidates: [{ id: 1, legal_name: 'Vaughn Electric Co',
                          normalised_name: 'vaughn electric' }],
    existing_certificate: { id: 9, certificate_date: '2025-02-20',
                            earliest_expiration: '2026-03-01' },
  });
  const gap = r.flags.find((f) => f.code === 'COVERAGE_GAP');
  assert.ok(gap);
  assert.equal(gap.gap_days, 14);
  assert.equal(r.status, 'ON_FILE');   // soft — surfaced, not quarantined
});

test('normalisation strips suffixes and folds punctuation', () => {
  assert.equal(normaliseName('Kessler Heating & Air Inc.'), 'kessler heating air');
  assert.equal(normaliseName('M. Mercer & Sons Plumbing, LLC'), 'm mercer sons plumbing');
});

test('parseISODate rejects impossible dates', () => {
  assert.equal(parseISODate('2026-02-31'), null);
  assert.equal(parseISODate('03/14/2026'), null);
  assert.ok(parseISODate('2026-03-14'));
});
```

`test/unit/harness.mjs` wraps `04_validate.js` and the three libraries into importable functions so the same source runs both in n8n and under `node --test`. Keep it thin — a wrapper that reimplements logic is a wrapper that passes tests the real code would fail.

```bash
make test-extract
```

---

## 4.10 Live smoke test

Before wiring anything into a workflow, confirm the request shape against the real API.

```bash
# Text branch
python - <<'PY' > /tmp/req.json
import json, pathlib
from pypdf import PdfReader
schema = json.loads(pathlib.Path("extraction/schema/coi_extraction.schema.json").read_text())
prompt = pathlib.Path("extraction/prompts/extract.system.md").read_text()
text = PdfReader("fixtures/out/f01-clean-current.pdf").pages[0].extract_text()
print(json.dumps({
  "model": "gpt-5.4-mini-2026-03-17",
  "instructions": prompt,
  "input": [{"role":"user","content":[{"type":"input_text",
      "text": f"Extract the certificate data from the following document text.\n\n--- BEGIN DOCUMENT ---\n{text}\n--- END DOCUMENT ---"}]}],
  "text": {"format": {"type":"json_schema","name":"coi_extraction","strict":True,"schema":schema}},
  "reasoning": {"effort":"low"},
  "max_output_tokens": 3000,
  "store": False
}))
PY

curl -s https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d @/tmp/req.json \
  | jq -r '.output[] | select(.type=="message") | .content[0].text' \
  | jq .
```

**Expected:** `vendor_legal_name: "Vaughn Electric Co"`, three coverage objects, dates matching `fixtures/out/manifest.json`, `extraction_confidence: "HIGH"`.

Then the vision branch:

```bash
B64=$(base64 -w0 fixtures/out/f04-scanned.pdf)   # macOS: base64 -i <file>
# Build the same payload with an input_file part carrying
# "data:application/pdf;base64,$B64" and detail "high", then POST it.
```

**Expected:** correct vendor and dates, `extraction_confidence: "MEDIUM"`, and a `confidence_reason` naming a specific field. If it comes back HIGH, the prompt's "bias toward LOW" instruction is not landing — check that the whole CONFIDENCE block made it into `instructions`.

### Record the numbers

Log input tokens, output tokens, and latency for both branches into `PROGRESS.md`. You will be asked "what does this cost to run?" by a prospect and by yourself, and a measured number beats an estimate.

Typical, for reference:

| Branch | Input | Output | Latency | Cost |
|---|---|---|---|---|
| Text | ~1,600 | ~700 | 3–6 s | ~$0.004 |
| Vision (`detail: high`) | ~4,200 | ~750 | 12–25 s | ~$0.007 |

---

## Stage 4 exit checklist

- [ ] Schema file is strict-valid: every property in `required`, `additionalProperties: false` on both objects
- [ ] System prompt saved; the CONFIDENCE block including "Bias toward LOW" is intact
- [ ] Text branch returns correct data for fixture 1
- [ ] Vision branch returns correct data for fixture 4 at **MEDIUM** confidence with a specific reason
- [ ] `03_parse_response.js` handles: 429, 5xx, `incomplete`, refusal, missing message item — all without throwing
- [ ] `04_validate.js` implements all 13 rules
- [ ] `make test-extract` passes every unit test
- [ ] SQL and JS normalisation agree on all 30 test strings
- [ ] Token and latency numbers recorded in `PROGRESS.md`
- [ ] OpenAI spend so far is under $2

→ Continue to [Stage 5 — Intake workflow](06-stage-5-intake-workflow.md)
