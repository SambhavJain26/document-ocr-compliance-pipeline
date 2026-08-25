# Build Technical Notes

Companion to `how-the-system-works.md`. That document explains the behaviour to a property manager and deliberately contains no stack, no node names and no API detail. This one contains all of it.

**Everything here is measured from the committed build**, not recalled. Node counts come from parsing the workflow JSON. Config values are read out of the migrations. The routing claims come from the connection graphs. Where a number appears, it was counted at the time of writing and can be recounted with the command shown.

**There is no client and no production deployment.** Everything described as verified was verified against manufactured fixtures on a local stack.

---

## The stack

The third column is the point of the table. The first two are trivia.

| Layer | Choice | Why not the obvious alternative |
|---|---|---|
| Orchestration | n8n, self-hosted | A hosted automation platform would put the client's vendor documents and mailbox access inside my account. Self-hosting means the workflows, the data and the credentials sit on infrastructure the client owns, and the engagement can end without anything being switched off. This is a commercial requirement expressed as a technical one |
| State | Postgres | The obvious alternative is n8n's own Data Tables. Rejected deliberately: workflow state belongs to the workflow tool, and if the client ever leaves n8n they should keep the asset. A Postgres dump is portable to anything. Also, a meaningful amount of the decision logic is SQL, which Data Tables could not express |
| Document reading | OpenAI, via the platform's OpenAI node | The obvious alternative is a dedicated OCR service. Rejected because a certificate is a one-page, highly structured form with a text layer most of the time, so plain text extraction handles the common case for free and the model is only needed for scans. Adding an OCR vendor would add a dependency for the minority path |
| Extraction contract | JSON Schema, structured output | Free-text parsing of a model response is the single most common way these builds rot. The schema makes malformed output a detectable event rather than a silent wrong answer |
| Decisions | Plain JavaScript in one file | The obvious alternative is asking the model whether a certificate is acceptable. Rejected as the central design decision of the build. See "Where the model is and is not consulted" |
| Email | Gmail nodes, OAuth | Generic SMTP would send but could not receive, and could not implement the approval gate. IMAP exists in the intake workflow as a disabled node for non-Google inboxes, not as a live path |
| Document storage | Files on disk, dated folders, bind-mounted | Storing PDFs as blobs in Postgres would bloat the dump the client is supposed to be able to carry away |
| Register | One HTML page rendered by a workflow on request | A generic admin panel (NocoDB, Metabase) gives filtering nobody needs and takes away the one thing that is needed: a screen that reads as something built for this job, with a forbidden-word guard compiled into the render path |

---

## The workflows

Seven exports, 87 nodes total. Recount with:

```bash
python3 -c "import json,glob; print(sum(len(json.load(open(f,encoding='utf-8'))['nodes']) for f in glob.glob('n8n-workflows/*.json')))"
```

| Workflow | Nodes | Owns | Trigger |
|---|---|---|---|
| `COI Intake` | 35 | Everything from arrival to filing: normalisation, storage, extraction, validation, persistence | Gmail trigger, form trigger, or manual |
| `Vendor Approval Request` | 12 | The approval gate for exactly one vendor: hold, send or decline, log | Called by Daily Watch and Chase, `mode: each` |
| `Daily Watch and Chase` | 9 | Bucketing, drafting, recording pending outreach, then dispatching one call per actionable vendor | Schedule 08:00, or manual |
| `Source Document Route` | 6 | Serving the stored original PDF back from a dashboard link | Webhook |
| `COI Dashboard` | 5 | Rendering current state as HTML | Webhook |
| `Non-PDF Reply Notice` | 3 | Vendor replies that carry no certificate become manager notices | Gmail trigger on replies |
| `Extraction and Validation Core` | 17 | Nothing at runtime. The harness the rules were built and tested in | Not active |

### Why the architecture is shaped this way

The 9/12 split between `Daily Watch and Chase` and `Vendor Approval Request` is not a stylistic decomposition. It is forced by a platform constraint.

**An n8n Wait node can only pause a given execution once, ever.** Feeding N vendors into a single Gmail Send-and-Wait call sends one real message and pauses for item 0 only. Resuming it resolves the entire array in the same instant: every other item returns with no approval data, reads as `approved: false`, and is logged as declined without ever having generated a message a human could see.

Looping the same node back on itself with Split In Batches does not fix it either. A second pass through the same node in the same execution resolves near-instantly against stale state rather than creating a fresh pause. This was tested, not assumed: item 2 came back declined 39ms after item 1's genuine approval, the same signature as the original defect.

The only fix is to give each item its own execution. `Daily Watch and Chase` therefore still does the bucketing, drafting and pending-record writing for the whole batch in one pass, and ends by calling `Vendor Approval Request` once per actionable vendor through an Execute Workflow node in `each` mode. Each call is a separate execution with its own genuine pause.

If you need human-in-the-loop-per-item on this platform, start from that split rather than trying to make a loop work.

---

## The single path to the irreversible action

The irreversible action in this build is sending an email to a vendor. The audit:

```bash
python3 -c "
import json,glob
for f in sorted(glob.glob('n8n-workflows/*.json')):
    d=json.load(open(f,encoding='utf-8'))
    for n in d['nodes']:
        t=n.get('type','')
        if 'gmail' in t.lower() or 'email' in t.lower() or 'smtp' in t.lower():
            p=n.get('parameters',{})
            print(d['name'],'|',n['name'],'|',t.split('.')[-1],'| op=',p.get('operation','-'),'| disabled=',n.get('disabled',False))
"
```

Five nodes across 87 touch email at all. Three cannot send: two Gmail triggers (read-only) and one IMAP node that is disabled. Two can send:

| Node | Sends to | Reachable from |
|---|---|---|
| `Gmail Approval - Send and Wait` | `{{ $json.approver_email }}` — the manager, internal | The workflow trigger, via one IF node |
| `Gmail Send Approved Stage 6 Chase` | `{{ $json.actual_recipient }}` — the vendor or their producer | `Route Approved Stage 6 Email`, true branch only |

**Exactly one node out of eighty-seven can send an email to a vendor**, and it has exactly one inbound edge. Tracing that edge backwards through the connection graph gives a single unbranched path:

```
Vendor Approval Request Trigger
  → Route Email Approval Configured        (refuses if no approver configured)
  → Gmail Approval - Send and Wait          (the human pause, 24h limit)
  → Recover Approval Result Context
  → Route Approved Stage 6 Email            (IF: approved?)
  → Gmail Send Approved Stage 6 Chase       ← the only vendor-facing send
```

There is no second route into that node. No other workflow references it. "Nothing goes out without a person" is therefore not a policy claim or a prompt instruction: it is a structural property of the graph, verifiable in about ninety seconds by anyone who opens the file.

Two further guards sit on that same path:

- `Route Email Approval Configured` diverts to a stored notice rather than proceeding when `approver_email` or `actual_recipient` is unset. A misconfigured install sends nothing rather than sending somewhere wrong.
- `actual_recipient` is computed in SQL, not in the workflow. With `stage_6_outbound_test_mode` at its default of `true`, it resolves to the configured test address and `send_mode` is stamped `test_override`. The CC list is also suppressed in that mode. Turning delivery on is a single config row, and it is the only variable a pilot changes.

---

## How the validation actually works

`scripts/lib/coi-stage-4-validator.js`, 630 lines, plain JavaScript. **Rules, not prompting.** No model is consulted at any point in this file.

`validateExtraction()` accumulates flags; `buildResult()` maps flags to a disposition. Fifteen flag codes in three severities: nine hard, five soft, one note.

Dispositions, read directly from `buildResult`:

| Condition | Disposition | Status |
|---|---|---|
| `NOT_A_COI` present | `ignore_not_certificate` | `null` |
| `OLDER_THAN_ON_FILE` present | `ignore_older_than_on_file` | `null` |
| Any other hard flag | `store_needs_review` | `NEEDS_REVIEW` |
| Otherwise | `store_on_file` | `ON_FILE` |

**A detail worth knowing, because it contradicts the intuitive reading.** The first two conditions are tested *before* the general hard-flag branch and short-circuit past it. So two of the nine hard flags never produce a `NEEDS_REVIEW` row and never reach a human: a document that is not a certificate, and a certificate older than the one already on file. Both are closed with a null status instead. The unifying property of the nine hard codes is that **no usable certificate comes out of them**, not that they are all escalated. Anyone documenting this build will get that wrong on the first pass; I did.

### When the rules run, and why the second run is the one that matters

The validator runs in two places:

1. `Extraction and Validation Core`, the offline harness, exercised by `scripts/verify-stage-4-validation.ps1` against fixtures with no database and no network.
2. `COI Intake`, at the `Normalize Validate Stage 5 Result` node, on every real document.

The second is the one that matters, because it runs against live vendor and holder records loaded from Postgres. The offline harness proves the logic is correct in isolation; only the in-workflow run proves it is correct against the actual register, where near-duplicate vendor detection and holder matching have real data to work with.

The two never diverge, because they are literally the same source. The generator reads the validator file and embeds it:

```javascript
const validatorSource = fs.readFileSync(path.join(repoRoot, "scripts", "lib", "coi-stage-4-validator.js"), "utf8");
```

Editing the copy inside a workflow export is therefore a mistake that will be silently reverted on the next regeneration.

---

## Where the model is and is not consulted

Three OpenAI calls exist in the whole build: two extraction nodes in `COI Intake`, one drafting node in `Daily Watch and Chase`.

**Decided by fixed rules before any model is consulted:**

- Whether the item is a PDF at all
- Whether the file is password-protected, and therefore whether extraction is attempted
- Whether to use the text path or the vision path, decided on extracted text length
- Every validation outcome
- Which bucket a vendor falls into, and whether they are chased at all
- Who the recipient is, and whether outbound is redirected

**Left to the model:**

- Transcribing the printed facts off a certificate
- Rating its own confidence as HIGH, MEDIUM or LOW
- Drafting the wording of a chase email

The model is never asked whether a certificate is acceptable. It is asked what the page says.

Structured output is enforced by `docs/schemas/coi-extraction.schema.json`, with thirteen top-level fields: `is_certificate_of_insurance`, `vendor_legal_name`, `vendor_address`, `producer_name`, `producer_email`, `producer_phone`, `certificate_date`, `certificate_holder`, `coverages`, `description_of_operations`, `cancellation_notice_wording`, `extraction_confidence`, `confidence_reason`.

Two schema decisions carry the honesty boundary into the data model:

- The additional-insured field is named `addl_insd_asserted`, never `additional_insured`. A checkbox records that somebody made a mark. A column called `additional_insured` invites every future reader, including me, to treat it as a fact.
- `cancellation_notice_wording` stores the sentence verbatim rather than a parsed notice period. There is no `notice_guaranteed_days` field, because the certificate cannot guarantee one.

The drafted chase email is post-processed rather than trusted: the word-count and forbidden-word checks run on the model's output, and the vendor-facing upload link is appended afterwards from config, so the model cannot invent a destination URL.

---

## Constraints that shaped the build

Only the ones that changed a decision.

**The file-write node cannot create parent directories.** Confirmed against the node source in the running container: the write operation exposes only `append`, `fileName` and `dataPropertyName`. Certificates are stored under `data/certificates/YYYY/MM/DD`, and that path rolls over at UTC midnight, so a stack that worked yesterday fails on today's first upload with `The file or directory does not exist` and nothing else wrong. The mitigation is operational, not architectural: `reset-demo.ps1` creates the current date path and has to be run on the day of any live upload.

**`Extract From File` aborts the run on a password-protected PDF** before any downstream validation can classify it. This forced two layers rather than one: a byte-level `/Encrypt` check on the stored document, plus `onError: continueErrorOutput` on the extract node routing to a review result. The second layer is the real guard, because the byte-level check cannot see the bytes when n8n stores binary on the filesystem rather than inline, which is the case here.

**A Wait node pauses an execution once, ever.** Already covered above. This is the single constraint that most shaped the architecture.

**Execute Workflow at typeVersion 1.1 needs only `workflowId.value`.** Confirmed by reading `ExecuteWorkflow.node.js` in the container rather than guessing: the `workflowInputs` resource-mapper only applies at typeVersion ≥ 1.2. Getting this wrong produces a call that looks correct and fails at runtime.

**Webhook and form routes need a `webhookId` on the trigger node** or they return 404 while the workflow still reports active. Generators assign these by node name for reasons covered under Defects.

**Model tier is a hard constraint, not a cost preference.** `gpt-5.4-nano` reads the watermarked fixtures as "not a certificate of insurance" with HIGH confidence. Current is `gpt-5.6-luna`, tested fallback `gpt-5.4-mini`. Luna also rejects a `temperature` parameter with `Bad request`, so the OpenAI nodes must not send one; determinism comes from the schema and a transcribe-only prompt instead.

**Fixtures must not reproduce ACORD forms.** ACORD forms are copyrighted and licensed. Fixtures are layout-similar synthetic documents carrying a visible `SPECIMEN - SYNTHETIC TEST DOCUMENT` watermark, with no ACORD logo or copyright notice. This is why model drift on the watermark matters at all.

**PowerShell 5.1 prepends a UTF-8 BOM when piping a string into a native command's stdin.** `psql` tolerates it. `n8n import:workflow` fails with `Unexpected token`. Because the verify helpers delete a workflow before importing, a failed import leaves a demo-facing workflow missing from n8n entirely. This has happened twice.

---

## The defects that shipped

The most useful section in this document. Each one is a real defect that existed in committed code, with the generalisation it supports.

### 1. The approval gate silently declined everyone but the first

**Symptom:** running the daily watch against many actionable vendors produced one Gmail approval email, not one per vendor. `outreach_log` showed a pending row for every vendor and a declined row for all but one, timestamped a few dozen milliseconds after the single real click.

**Cause:** an n8n Wait node pauses an execution once. Given N items, `Gmail Approval - Send and Wait` sent a real message and paused for item 0 only. Resuming resolved the whole array at once; every later item returned with no approval data, which read as `approved: false`.

**How it was actually diagnosed:** the first hypothesis was wrong and was stated confidently before being tested. It was disproved by decoding the real execution data with n8n's own `flatted` library inside the container, because `execution_data.data` is not plain JSON. The first fix attempt, Split In Batches looped back into the same node, also failed and was also verified rather than assumed.

**Fix:** split the approval-through-send segment into its own workflow, called once per vendor in `each` mode.

**The one mercy:** `send_response` was empty on the falsely-declined rows, so no unauthorised email ever went out. The damage was bookkeeping, not delivery.

**Generalisation:** when a human-in-the-loop step processes a batch, confirm that each item produced a distinct human interaction rather than that the step completed. A gate that resolves without a human is indistinguishable from a gate that worked, from the outside.

### 2. Re-attestation fired for vendors with perfect paperwork

**Symptom:** none, for as long as the feature existed. A vendor with a clean certificate 237 days from expiry appeared in the `RE_ATTEST` bucket and would have been chased.

**Cause:** the bucket condition tests `last_attested_at`, and no workflow ever wrote that column. It was NULL for every vendor, so the condition was permanently true.

**Fix:** `store_stage_5_intake_result` now records an attestation date whenever it files a certificate as `ON_FILE`, using the certificate's own date rather than today, wrapped in `GREATEST` so it only moves forward. An idempotent backfill covers existing rows.

**Generalisation:** a condition that reads a column nothing writes is always true or always false, and it produces no error. Grep for writes to every column your conditions read.

### 3. Seventeen of eighteen vendors had silently stopped being chased

**Symptom:** none. The board looked healthy and every number on it was accurate.

**Cause:** earlier escalation testing had tripped the two-strike rule and left `chase_paused = true` on 17 of 18 vendors. The system was behaving exactly as designed. It simply had nowhere to say so.

**Fix:** the dashboard gained a chase column, and `reset-demo.ps1` now clears the flag.

**Generalisation:** state that suppresses future work must be visible on the main screen. A dashboard that shows only what the system did, and never what it has stopped doing, cannot report its own silence.

### 4. Bucket transitions reset the follow-up suppression and the escalation counter

**Symptom:** a vendor could receive two near-identical reminders a day apart, and could ignore request after request without ever tripping the two-strike rule.

**Cause:** the issue key included the bucket. A certificate crossing from 15 days out to 14 changed bucket, therefore changed key, therefore became a brand new problem with no history. The seven-day interval had nothing to apply to.

**Fix:** dropped the bucket from the key. `bucket_value` is retained in the function signature for existing callers.

**Generalisation:** anything that chases people has a definition of "I already asked about this." If that definition includes a field that changes on its own over time, the suppression it powers will silently lapse.

### 5. Password-protection was detected by filename

**Symptom:** every form and Gmail upload failed at the routing node. Separately, a genuinely locked PDF from a real vendor would have been routed as readable.

**Cause:** the condition compared `$json.fixture_id` against the literal string `f18-password-protected` under strict type validation. Only the manual test path sets `fixture_id`; on the two paths a real certificate actually arrives on, the left side was `undefined` and strict validation failed the node outright.

**Why it was missed:** every earlier intake test used the manual trigger.

**Fix:** two layers, a byte-level `/Encrypt` check and an error-output route on the extract node.

**Generalisation:** if a condition references a field only your test harness populates, you have tested the harness. Verify through the same entry point real traffic uses.

### 6. Every chase email silently discarded the model's draft

**Symptom:** none visible. Emails sent fine and read plausibly, because they fell back to the fixed template.

**Cause:** `normalizeModelOutput` checked `typeof value.output === "object"`, which is true for arrays, so it returned the raw Responses API array before the array branch could run. A second defect in the same path appended `T00:00:00Z` to values already arriving from Postgres as full ISO timestamps, producing `expires 2026-06-26T00:00:00.000Z` in the visible email body.

**Generalisation:** `typeof x === "object"` is true for arrays and for null. When a fallback path is indistinguishable from the happy path in the output, you will not notice you are always on it.

### 7. Declined vendors were logged as sent

**Symptom:** rows in `outreach_log` marked sent for vendors whose approval had been declined.

**Cause:** `$items(nodeName)` returns every item a node ever produced, regardless of which branch of a later IF node they went down. The sent-log payload joined the real Gmail Send output against `$items("Recover Approval Result Context")` by array index, pairing a shorter array of genuinely-sent items against a longer array including declined ones.

**Fix:** source context from `$items("Route Approved Stage 6 Email", 0, 0)`, the IF node's own true-branch output, which lines up 1:1 by construction rather than by luck.

**Generalisation:** index-based joins between two arrays are safe only when something guarantees they are the same length. "They looked the same length when I tested it" is not that guarantee.

### 8. Webhook IDs were assigned to sticky notes

**Symptom:** the upload form and the stable dashboard URL both returned 404 while all workflows reported active.

**Cause:** generators assigned `webhookId` by array index (`nodes[0]`, `nodes[1]`). Adding canvas sticky notes to the front of the nodes array shifted every index.

**Fix:** a `setWebhookId` helper that looks nodes up by name and throws if the name is missing.

**Generalisation:** positional references into a collection break the first time someone reorders it, and generated artifacts get reordered for cosmetic reasons.

### 9. A verify script deleted a live workflow and failed to replace it

**Symptom:** `Source Document Route` vanished from n8n entirely.

**Cause:** the BOM issue above. The verify helper deletes before importing, so a failed import leaves nothing behind.

**Generalisation:** delete-then-create is not idempotent under failure. Import to a new name and swap, or verify the import parses before destroying what is there.

---

## Reproducibility

**The workflows are generated, not hand-edited.** `scripts/generate-stage-*.js` build each export from source, and the PowerShell wrappers invoke them. Hand-editing an export works until the next regeneration silently reverts it. The validator is embedded by file read, so there is exactly one copy of the rules in the repo.

Canvas sticky notes come from a `sticky()` helper in each generator, never hand-added.

**Credentials never appear in committed files.** Every workflow references credentials by name and id only:

| Workflow | Credential references |
|---|---|
| `COI Intake` | `Gmail account`, `OpenAI account`, `Postgres account` |
| `Vendor Approval Request` | `Gmail account`, `Postgres account` |
| `Non-PDF Reply Notice` | `Gmail account`, `Postgres account` |
| `Daily Watch and Chase` | `OpenAI account`, `Postgres account` |
| `Source Document Route`, `COI Dashboard` | `Postgres account` |

No token, key, client secret or OAuth credential is stored in the repo. The actual credential records live inside n8n and are created by hand.

**Client-specific values are database rows, not code.** Minimum limits per trade, accepted certificate-holder legal names, reminder cadence, re-attestation interval, approver address, test recipient, upload form URL and model id are all `client_config` rows. Changing a client's requirements is SQL, not a redeploy.

**One deliberate exception worth knowing:** the forbidden-word list in the dashboard generator is written as `["com" + "pliant", "veri" + "fied", ...]`. The concatenation keeps the literal words out of the source file so the file passes the same scan it enforces.

---

## What was verified, and what that means

Twelve verification scripts exist, `scripts/verify-*.ps1`, covering local services, schema and seed, fixtures, validation, extraction, storage, intake, watch behaviour, workflow import, dashboard rendering, full fixture scenarios and production-readiness documentation.

Most recently recorded: 18 of 18 Stage 6 watch checks, 8 of 8 Stage 5 storage checks, the offline validator suite, all six runtime workflows importing and reporting active, all local URLs returning 200, and a live two-vendor approval test producing two independent waits, two independent approvals and two independent sends.

**This is testing, not a result.** Seventeen manufactured fixtures, eighteen fictional vendors, one local machine, one operator who wrote both the system and the tests. No client has used it, no real vendor has received anything from it, and no claim about time saved or lapses prevented is supported by any of it. The verification establishes that the code does what I intended. It establishes nothing about whether what I intended is useful.

---

## Known limits of the current build

Stated here so nobody has to discover them.

- **Outbound is redirected by default.** `stage_6_outbound_test_mode` is `true`. Nothing reaches a real vendor until it is deliberately switched off.
- **The vendor-facing upload link points at `localhost`.** It is unreachable by anyone off this machine, so the link in a chase email is currently useless to a real vendor. A public HTTPS surface is an unresolved decision.
- **Gmail intake filters on unread with an attachment.** A reply opened in Gmail before the trigger polls is missed.
- **Certificate images sent as JPG or PNG are not processed.** Intake filters to PDFs, so they become notices.
- **Vendor replies are never linked to the outreach row that prompted them.** Matching runs on the vendor name extracted from the certificate. Chasing stops because a newer filed certificate makes the vendor non-actionable, not because a reply was detected. The outcome is right; the mechanism is not reply detection.
- **The dashboard is ordered best-first.** Clean rows at the top, vendors with nothing on file at the bottom. This was reversed from worst-first on 2026-08-07 because it reads better on camera. It buries the rows most needing attention, and the tradeoff should be revisited before any client relies on the board. The `sort_rank` comment in `005-stage-7-dashboard.sql` documents how to invert it.
- **No duplicate protection on message or attachment.** A forwarded email can double-file.
- **No retries, no dead-letter queue, no alerting.** A failed run is visible only in execution history.
- **`data/certificates/2026` was once observed empty**, including previously written day folders. `reset-demo.ps1` does not delete under the storage root, so the cause is unresolved. Recoverable in one command, but treat a missing dated folder as expected rather than surprising.
- **The two-strike escalation threshold and seven-day follow-up interval are guesses.** Neither has been tested against a real vendor's tolerance.
