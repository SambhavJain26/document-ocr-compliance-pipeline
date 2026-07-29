# Stage 6 — Watch & chase workflow

**Document 07 · Estimated time: 1 day · Cost: ~$0.30 of token spend**

Workflow `COI · 2 · Watch & Chase`, plus `COI · 4 · Escalation`. This is where the product stops being a filing cabinet and starts doing the job the client is actually paying for.

It also contains the demo's emotional peak: a prospect tapping **Approve** on their own phone and watching an email send. Everything before it is setup for that moment.

**Gate:** an approval email arrives on a phone you have never logged into n8n on, tapping Approve resumes the execution, and a real email is delivered.

---

## 6.1 Node graph

```
[Schedule 08:00]   [Manual Trigger]   ← demo uses this
        └────────┬────────┘
                 ▼
      [Postgres — Load Config]
                 ▼
      [Postgres — Chase Queue]         db/queries/q_chase_queue.sql
                 ▼
      [Switch — Bucket]
   ┌────┬────┬────┬────┬────┬────────┐
   ▼    ▼    ▼    ▼    ▼    ▼        ▼
NEVER EXPIRED D14 D30 D60 RE_ATTEST (fallback → NoOp)
   └────┴────┴────┴────┴────┴────────┘
                 ▼
      [06 Bucket Context]              Code: template selection + facts
                 ▼
      [07 Build Draft Request]
                 ▼
      [HTTP — OpenAI Responses]        short draft, ~150 tokens out
                 ▼
      [08 Parse Draft]
                 ▼
      [Postgres — Log Draft]           row exists BEFORE the human sees it
                 ▼
╔═════════════════════════════════════════════╗
║  [Gmail — Send and Wait for Response]       ║  ◄── THE GATE
║   Response Type: Approval                   ║
║   Limit Wait Time: 24 h                     ║
║   Workflow PAUSES here                      ║
╚═════════════════════════════════════════════╝
                 ▼
      [IF — approved]
        ┌────────┴────────┐
   true │                 │ false
        ▼                 ▼
 [Gmail — Send]    [Postgres — Log Declined]
        ▼
 [Postgres — Log Sent + follow_up_due]
```

---

## 6.2 Triggers

### `Schedule Trigger — Daily 08:00`

`n8n-nodes-base.scheduleTrigger` · Trigger Interval `Days` · Days Between Triggers `1` · Trigger at Hour `8` · Minute `0`.

Fires at 08:00 in `GENERIC_TIMEZONE`, which is why that env var matches `client_config.timezone`.

### `Manual Trigger`

`n8n-nodes-base.manualTrigger`. Both wire into the same next node.

**The demo runs this manually.** Do not attempt to make a scheduled run land during a call — you will spend the whole demo watching a clock instead of a prospect.

---

## 6.3 `Postgres — Chase Queue`

`db/queries/q_chase_queue.sql` from [Stage 2 §2.6](03-stage-2-data-layer.md).

Two things it already handles that you would otherwise rediscover as bugs:

- **`NOT EXISTS` on today's `outreach_log`** — a double-triggered scheduled workflow cannot email an agent twice. That failure looks like disorganisation to your client's own vendor, which is the opposite of what they are paying for.
- **`NOT chase_paused`** — a vendor a human has taken over is excluded at the query level, not filtered later. Excluding it at the source means no downstream node can accidentally reintroduce it.

Settings → Always Output Data **on**, so an empty queue completes cleanly rather than looking like a failure.

---

## 6.4 `Switch — Bucket`

`n8n-nodes-base.switch` · Mode `Rules` on `{{ $json.bucket }}`.

| Output | Value | Template |
|---|---|---|
| 0 | `NEVER_RECEIVED` | `never_received` |
| 1 | `EXPIRED` | `expired` |
| 2 | `D14` | `urgent` |
| 3 | `D30` | `standard` |
| 4 | `D60` | `early` |
| 5 | `RE_ATTEST` | `reattest` |
| Fallback | — | NoOp |

### `NEVER_RECEIVED` is first, and that is a bug fix

A vendor with no certificate has a NULL expiry date. Bucket on days-to-expiry alone and that vendor falls silently through to "no action" — meaning **the system ignores your client's most non-compliant vendors while diligently chasing the ones who are merely close to renewal.** That is the exact failure the product claims to prevent, and a prospect finds it within minutes of real use.

The ordering is already enforced in `v_vendor_status`'s CASE ([Stage 2 §2.3](03-stage-2-data-layer.md)); the Switch mirrors it. Both, deliberately — a Switch that disagrees with the view is a bug that only shows up in one of the two consumers.

---

## 6.5 `06 Bucket Context` — Code, Run Once for Each Item

Assembles the facts the drafting model may use. **The model receives facts, never a coverage conclusion**, and it receives only fields it is allowed to mention.

```javascript
/**
 * 06_bucket_context.js — Code node, "Run Once for Each Item"
 *
 * Builds the drafting brief. Deliberately narrow: the model gets a small,
 * curated fact set so it cannot mention something it should not. Anything
 * absent from this object cannot appear in the email.
 */
const j = $json;
const cfg = $('Postgres — Load Config').first().json.config;

const MON = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const fmt = (iso) => {
  if (!iso) return null;
  const [y, m, d] = iso.split('-').map(Number);
  return `${d} ${MON[m - 1]} ${y}`;
};

const TEMPLATES = {
  NEVER_RECEIVED: {
    key: 'never_received',
    intent: 'We have no certificate of insurance on file for this vendor at all. ' +
            'Ask the agency to send a current certificate naming the client as certificate holder.',
    subject: `Certificate of insurance request — ${j.display_name}`,
  },
  EXPIRED: {
    key: 'expired',
    intent: 'The most recent certificate on file shows coverage that has already ' +
            'passed its expiration date. Ask for a current replacement certificate.',
    subject: `Renewed certificate needed — ${j.display_name}`,
  },
  D14: {
    key: 'urgent',
    intent: 'Coverage expires within two weeks. Ask for the renewal certificate, ' +
            'noting the date, politely but with a clear timeframe.',
    subject: `Certificate expiring ${fmt(j.earliest_expiration)} — ${j.display_name}`,
  },
  D30: {
    key: 'standard',
    intent: 'Coverage expires within a month. Request the renewal certificate.',
    subject: `Certificate renewal — ${j.display_name}`,
  },
  D60: {
    key: 'early',
    intent: 'Coverage expires in around two months. A light early heads-up so the ' +
            'renewal certificate can be sent when it issues.',
    subject: `Upcoming certificate renewal — ${j.display_name}`,
  },
  RE_ATTEST: {
    key: 'reattest',
    intent: 'Routine quarterly check-in. Ask the agency to confirm the policy remains ' +
            'in force, or send a current certificate if anything has changed. ' +
            'This is a routine administrative confirmation, not a suggestion that ' +
            'anything is wrong.',
    subject: `Quarterly confirmation — ${j.display_name}`,
  },
};

const t = { ...TEMPLATES[j.bucket] };

// Attempt 2 is a follow-up, not a repeat. Sending the identical email a week
// later reads as a script, and an agent who works out they are talking to a
// script stops reading. One sentence of context is all it takes.
if (Number(j.attempt_number) >= 2) {
  t.intent +=
    ' This is a second request — the first went unanswered about a week ago. ' +
    'Keep it shorter and lighter than a first approach, reference that you ' +
    'wrote previously, and do not express annoyance.';
  t.subject = `Following up: ${t.subject}`;
}

// Curated fact set. Nothing here is a conclusion about coverage.
const facts = {
  vendor_name: j.legal_name,
  client_name: cfg.client_legal_name,
  producer_name: j.producer_name || null,
  policy_number: j.earliest_policy_number || null,
  carrier: j.earliest_insurer || null,
  expiration_date: fmt(j.earliest_expiration),
  days_to_expiry: j.days_to_expiry,
  has_certificate_on_file: Boolean(j.certificate_id),
};

const recipient = j.producer_email || j.contact_email;
const cc = (j.producer_email && j.contact_email && j.producer_email !== j.contact_email)
  ? j.contact_email : null;

return {
  json: {
    ...j,
    config: cfg,
    template_key: t.key,
    draft_intent: t.intent,
    draft_subject: t.subject,
    draft_facts: facts,
    recipient,
    cc,
    recipient_missing: !recipient,
  },
};
```

Route `recipient_missing = true` to a manager notice rather than to the model. Drafting an email you cannot address wastes a call and, worse, produces a queue entry that looks handled.

### Why the agent and not the vendor

The producer — the insurance agent — is the party who can actually produce a certificate. The vendor forwards the request to their agent anyway, adding a day and a chance of it being forgotten. **Address the agent, copy the vendor.** The vendor stays informed, which matters because it is their client relationship, but the request lands where the work happens.

---

## 6.6 `07 Build Draft Request` + `HTTP — OpenAI Responses`

Same endpoint, same credential, same model. Structured Outputs again — a two-field schema so the subject and body arrive separately rather than as a blob you have to split on a newline.

### `extraction/prompts/draft_email.system.md`

```
You draft short, professional emails on behalf of a US residential property
management company, requesting certificates of insurance from insurance
agencies.

VOICE
Plain, courteous, unfussy. The tone of an operations manager who sends this
email thirty times a year. Not salesy, not apologetic, not stiff.

HARD RULES

1. Under 110 words in the body. Shorter is better.

2. Use only the facts provided. Never invent a policy number, a date, a
   carrier, a contact name, or an amount. If a fact is null, write the email
   without it rather than guessing.

3. Never state or imply anything about whether coverage exists, is adequate,
   is valid, or is compliant. You are asking for a document. You are not
   assessing insurance. Do not use the words "compliant", "verified",
   "covered", or "valid".

4. Never threaten, never mention consequences, never reference contracts,
   dispatch eligibility, or removal from a vendor list. This is a paperwork
   request between people who work together.

5. Address the insurance agency. Refer to the vendor in the third person.

6. Do not include a signature block, a greeting line addressed to a name you
   were not given, or any placeholder such as [Name] or [Company]. The sending
   system adds the signature.

7. Ask for one thing: a current certificate naming the certificate holder
   provided. One clear request, one sentence.

8. Plain text only. No markdown, no bullet characters, no bold.

Return the subject and body separately.
```

### Draft response schema

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["subject", "body"],
  "properties": {
    "subject": { "type": "string", "description": "Under 70 characters." },
    "body":    { "type": "string", "description": "Plain text, under 110 words, no signature block." }
  }
}
```

### Payload

```javascript
const payload = {
  model: cfg.model_id,
  instructions: DRAFT_SYSTEM_PROMPT,
  input: [{
    role: 'user',
    content: [{
      type: 'input_text',
      text:
        `Situation: ${j.draft_intent}\n\n` +
        `Facts you may use:\n${JSON.stringify(j.draft_facts, null, 2)}\n\n` +
        `Write the email.`,
    }],
  }],
  text: {
    format: {
      type: 'json_schema', name: 'draft_email', strict: true,
      schema: DRAFT_SCHEMA,
    },
  },
  reasoning: { effort: 'low' },
  max_output_tokens: 600,
  store: false,
};
```

`08 Parse Draft` is `03_parse_response.js` with the terminal field mapped to `{ subject, body }`. On failure, fall back to a deterministic template rather than skipping the vendor — a plain templated email is a fine outcome; a silently skipped vendor is not.

```javascript
if (!parsed.ok) {
  return { json: { ...j,
    draft_subject: j.draft_subject,
    draft_body:
      `Hello,\n\nWe're following up on the certificate of insurance for ` +
      `${j.draft_facts.vendor_name}` +
      (j.draft_facts.policy_number ? ` (policy ${j.draft_facts.policy_number})` : '') +
      (j.draft_facts.expiration_date ? `, which shows an expiration date of ${j.draft_facts.expiration_date}` : '') +
      `.\n\nCould you send a current certificate naming ` +
      `${j.draft_facts.client_name} as certificate holder?\n\nThank you.`,
    draft_fallback_used: true,
  }};
}
```

---

## 6.7 `Postgres — Log Draft`

**Write the row before the human sees the email, not after they approve it.**

```sql
-- $8 = attempt_number, supplied by q_chase_queue.sql
INSERT INTO outreach_log (vendor_id, certificate_id, bucket,
                          drafted_subject, drafted_body, recipient, cc,
                          attempt_number)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
ON CONFLICT (vendor_id, bucket, (created_at::date)) DO NOTHING
RETURNING id;
```

Two reasons this ordering matters:

1. **The unique index does its job.** It only prevents a duplicate if a row exists at the moment the second run reaches this node. Logging after approval leaves a 24-hour window in which the same draft can be generated twice.
2. **A declined or abandoned draft is still a fact worth keeping.** "We drafted this and the manager declined it on 14 March" is exactly the kind of thing a client asks about six weeks later.

`DO NOTHING` returns no rows on conflict. Add an IF on the returned `id` and route the empty case to NoOp — that vendor was already contacted for this bucket today.

---

## 6.8 The approval gate

### `Gmail — Send and Wait for Response`

`n8n-nodes-base.gmail`

| Parameter | Value |
|---|---|
| Credential | `Gmail — COI` |
| Resource | `Message` |
| Operation | **Send and Wait for Response** |
| To | `={{ $json.config.approver_email }}` |
| Subject | `={{ 'Approve: ' + $json.draft_subject }}` |
| Message | see below |
| Response Type | **Approval** |
| Type of Approval | **Approve and Disapprove** |
| Options → Limit Wait Time | **on** |
| Options → Limit Type | `After Time Interval` |
| Options → Resume Amount | `24` · Unit `Hours` |
| Options → Append n8n Attribution | **off** |

Message body — this is what the prospect reads on their phone, so every word counts.

**Note the `$('06 Bucket Context')` prefixes.** This node's immediate input is `Postgres — Log Draft`, which returns only `{ id }` — a Postgres node replaces the item's json with its query result. A bare `$json.display_name` here renders empty, and you would find out by watching a prospect read a blank approval email on their phone.

```
={{ (() => { const c = $('06 Bucket Context').item.json; return
`A certificate request is ready to send.

VENDOR      ${c.display_name}
TO          ${c.recipient}
${c.cc ? `COPY TO     ${c.cc}\n` : ''}STATUS      ${
  c.bucket === 'NEVER_RECEIVED' ? 'No certificate on file'
  : c.bucket === 'EXPIRED'      ? `Expired ${Math.abs(c.days_to_expiry)} days ago`
  : c.bucket === 'RE_ATTEST'    ? 'Routine quarterly confirmation'
  : `Expires in ${c.days_to_expiry} days`
}

────────────────────────────────────────
SUBJECT: ${c.draft_subject}

${c.draft_body}
────────────────────────────────────────

Nothing is sent unless you approve.`; })() }}
```

> **The rule, applied everywhere downstream of a Postgres node:** bind the context once at the top of the expression (`const c = $('<Node Name>').item.json`) and read from it. Applies equally to `Postgres — Log Sent`, `Postgres — Log Declined`, and the escalation notice after `Postgres — Pause Chasing`. [§12.7](12-n8n-operations-cookbook.md).

### Why email is the default and Telegram is the bonus

The build plan reached this conclusion and it is worth restating because it is easy to talk yourself back out of it: **Telegram is more theatrical and email is more reliable.**

Telegram has low US business penetration. Asking a property manager to install an app before a sales call is real friction, and some will simply decline — which kills the demo's best moment. n8n's send-and-wait renders the same Approve/Decline buttons inside an ordinary email, in any mail client, with no install and no account. It is also what a real client would actually use day to day, so it survives into production instead of being a demo gimmick.

Build the Telegram branch as a parallel path selected by `client_config.approval_channel` for the minority who already use it. Never make the emotional peak of your demo depend on a prospect installing software.

### The two verified caveats

**① The button resolves against your n8n webhook URL.** This is the single most likely thing to break on the call. It is why [Stage 1 §1.8](02-stage-1-infrastructure.md) exists and why you test on a phone over mobile data. Re-verify the morning of every demo.

**② The node returns a minimal payload** — `{ data: { approved: true } }`. No `message_id`, no `chat_id`. Do not design anything that needs to edit or delete the prompt message afterwards.

### `IF — Approved`

Condition: `{{ $json.data.approved }}` is true (Boolean).

---

## 6.9 Sending

### `Gmail — Send`

| Parameter | Value |
|---|---|
| Resource | `Message` · Operation | `Send` |
| To | `={{ $('06 Bucket Context').item.json.recipient }}` |
| CC | `={{ $('06 Bucket Context').item.json.cc }}` |
| Subject | `={{ $('06 Bucket Context').item.json.draft_subject }}` |
| Email Type | `Text` |
| Message | draft body + signature (below) |
| Options → Reply To | `={{ $('06 Bucket Context').item.json.config.from_mailbox }}` |
| Settings → Retry On Fail | on · 3 tries · 5000 ms |

```
={{ $('06 Bucket Context').item.json.draft_body + `

—
${$('06 Bucket Context').item.json.config.client_legal_name}
Vendor documentation
${$('06 Bucket Context').item.json.config.from_mailbox}` }}
```

> **Reach back by node name — a bare `$json` here is wrong.** After `Send and Wait`, `$json` is the minimal approval payload `{ data: { approved: true } }`. There is no `config` on it, so `$json.config.from_mailbox` resolves to `undefined` and the vendor email goes out with a blank Reply-To and a blank signature — visibly broken, in your client's name, in a third party's inbox. The general rule: a bare `$json` after a gate or a second HTTP hop refers to *that* node's output, not the one you had in mind. [§12.7](12-n8n-operations-cookbook.md).

> **The From address must be the client's mailbox.** This is not a preference. A renewal request to an existing vendor is transactional relationship content, which is why it lands in CAN-SPAM's exempt category — and that exemption depends on the message not carrying misleading routing information. It is also a deliverability question: you have no SPF/DKIM relationship with the vendor's mail server, and mail from an unrelated domain about a policy held by a plumber for a property manager will be filtered. **Never send vendor mail from your own infrastructure under your own identity.**

`Email Type: Text`, not HTML. An insurance agency's mail client is often ancient, plain text always renders, and the message is six sentences.

### `Postgres — Log Sent`

```sql
UPDATE outreach_log
SET    approved        = true,
       approved_at     = now(),
       approved_by     = $2,
       sent_at         = now(),
       gmail_thread_id = $3,
       -- awaiting_reply is what keeps this vendor OUT of tomorrow's chase
       -- queue. Forget it and the agent gets an email every morning.
       awaiting_reply  = true,
       follow_up_due   = (SELECT today FROM v_today)
                       + (SELECT value::int FROM client_config WHERE key='follow_up_days')
WHERE  id = $1;
```

### `Postgres — Log Declined`

```sql
UPDATE outreach_log
SET    approved = false, approved_at = now(), approved_by = $2,
       awaiting_reply = false, closed_at = now(), close_reason = 'DECLINED'
WHERE  id = $1;
```

A declined draft gets no follow-up and no retry. The human said no; the system's job is to record that and stop.

Note `awaiting_reply = false`. A declined draft was never sent, so nothing is being waited on — leaving it true would wedge the vendor out of the chase queue permanently, which is a silent no-op that looks exactly like the system working.

---

## 6.10 `COI · 4 · Follow-up sweep`

A separate workflow, scheduled at **07:30 — before the 08:00 chase run, not after.**

That ordering is the whole design. The sweep either releases a vendor for their next request (which the 08:00 run then sends the same morning) or escalates them out. Running it *after* the chase would push every follow-up a day late.

```
[Schedule 07:30]
      ▼
[Postgres — Follow-ups Due]        db/queries/q_followups_due.sql
      ▼
[Switch — action]
   ┌──┴───┐
REOPEN  ESCALATE
   ▼        ▼
[Reopen] [Escalate + Pause]
              ▼
       [Notify Manager]
```

### Why this replaces "escalate on the first unanswered request"

The product claims — in the proposal, and out loud at 3:20 in the demo — that **two ignored requests escalate to a human**. An earlier design escalated after one. That would have made a line you say to a prospect's face literally untrue, which is not a corner worth cutting in a product whose entire positioning is honesty about its limits.

The sequence a vendor now experiences:

| Day | What happens |
|---|---|
| 0 | Request 1 drafted, approved by a human, sent. `awaiting_reply = true`, `follow_up_due = +7` |
| 1–6 | **Nothing.** The `awaiting_reply` guard keeps them out of the chase queue |
| 7, 07:30 | Sweep sees `attempt_number = 1 < max_chase_attempts`. Action `REOPEN` |
| 7, 08:00 | Chase run picks them up at `attempt_number = 2`, drafts a follow-up, **through the approval gate again** |
| 14, 07:30 | Sweep sees `attempt_number = 2`. Action `ESCALATE` — alert a person, pause chasing |

> **Days 1–6 are the part that was broken.** The old chase query excluded only vendors contacted *today*, so an expired vendor would have been emailed **every single morning** until they responded. Not a nuisance — a daily email to the same insurance agent, in your client's name, is the fastest possible way to make your client look incompetent to their own vendor. The `awaiting_reply` guard in `q_chase_queue.sql` is what fixes it.

### `Postgres — Reopen` (action = `REOPEN`)

```sql
UPDATE outreach_log
SET    awaiting_reply = false,
       closed_at      = now(),
       close_reason   = 'REOPENED'
WHERE  id = $1;
```

No notification. A vendor who has not replied in seven days is routine, and telling the manager about it would train them to ignore the alert that actually matters.

### `Postgres — Escalate + Pause` (action = `ESCALATE`)

```sql
BEGIN;

UPDATE outreach_log
SET    escalated      = true,
       escalated_at   = now(),
       awaiting_reply = false,
       closed_at      = now(),
       close_reason   = 'ESCALATED'
WHERE  id = $1;

UPDATE vendors
SET    chase_paused      = true,
       chase_paused_at   = now(),
       chase_paused_by   = 'system:escalation',
       chase_paused_note = 'Two requests unanswered. Handed to a person.'
WHERE  id = $2;

COMMIT;
```

### The escalation message

```
={{ `🔔 <b>Needs a person</b> — ${$json.display_name}\n\n` +
    `Requested on ${new Date($json.sent_at).toISOString().slice(0,10)} ` +
    `to ${$json.recipient}. No certificate has arrived.\n\n` +
    `Automated reminders for this vendor are now paused. ` +
    `They'll resume once a certificate arrives or someone clears the pause.` }}
```

### The pause is the point

**Two ignored requests escalate to a human. They do not escalate to more automation.**

A system that keeps emailing a vendor after a person has taken the conversation over makes your client look disorganised to their own vendor — which is precisely the opposite of what they are paying for. It also makes the automation visible in the worst way: the vendor works out they are talking to a script, and stops reading.

The pause clears automatically when a certificate arrives. Add **both** of these to the intake workflow's success path:

```sql
-- 1. Clear the pause and record the attestation
UPDATE vendors
SET    chase_paused = false, chase_paused_at = NULL,
       chase_paused_by = NULL, chase_paused_note = NULL,
       last_attested_at = (SELECT today FROM v_today)
WHERE  id = $1 AND chase_paused;

-- 2. Close any open request — db/queries/q_close_outreach_on_certificate.sql
UPDATE outreach_log
SET    awaiting_reply = false, closed_at = now(),
       close_reason   = 'CERTIFICATE_RECEIVED'
WHERE  vendor_id = $1 AND awaiting_reply;
```

The second one matters as much as the first. Without it, a vendor who *did* send their certificate still has an `awaiting_reply` row, and the 07:30 sweep escalates them seven days later for ignoring a request they answered. Alerting a manager about a vendor who complied is precisely the confident-wrong-alert failure that destroys trust in an automated system.

---

## 6.11 Manual status override

Mid-term cancellation is undetectable from a certificate — by you, and by every enterprise platform. What the system *can* do is capture the fact once a person learns it.

A small n8n Form Trigger workflow, `COI · 5 · Status Override`:

| Field | Type | Options |
|---|---|---|
| Vendor | Dropdown | populated from `vendors` |
| New status | Dropdown | `CANCELLED`, `NON_RENEWED`, `Clear override` |
| Who is recording this | Text | required |
| What did you learn, and from whom? | Textarea | required |

```sql
UPDATE certificates
SET    status = $2, status_set_by = $3, status_note = $4, status_set_at = now()
WHERE  id = (SELECT id FROM v_current_certificate WHERE vendor_id = $1);
```

The dashboard renders the row red with the note visible: *"Cancelled — agent confirmed non-payment cancellation 12 Mar, recorded by J. Alvarez."*

**Requiring the note and the attribution is deliberate.** A status change with no provenance is a rumour in a database, and six months later nobody can tell whether it was a phone call with the carrier or somebody's hunch.

---

## 6.11b `COI · 7 · Retention purge`

`client_config.pdf_retention_months` was seeded but nothing read it. That made it a setting you would describe to a prospect — *"we keep the originals for 24 months, and it's configurable"* — that did nothing. Either enforce it or stop offering it; enforcing it is twelve nodes.

Monthly, first of the month at 03:00:

```
[Schedule — Monthly 03:00]
      ▼
[Postgres — Purge Candidates]     db/queries/q_retention_purge.sql
      ▼
[Delete File From Disk]           On Error: Continue
      ▼
[Postgres — Mark Purged]
      ▼
[Notify Manager — Retention Summary]
```

```sql
-- Mark Purged. The row survives; only the document goes.
UPDATE certificates
SET    stored_path_purged_at = now()
WHERE  id = $1;
```

**Keep the row, delete the file.** The register, the extracted data, the validation flags and the outreach history all remain — the audit trail is the product, and a client asking *"what did we know and when?"* about a 2027 dispute must still get an answer. What goes is the one thing you promised to delete: the original PDF.

The dashboard renders a purged row's source link as `document not retained` rather than a broken link. Add to `08_render_dashboard.js`:

```javascript
const pdfLink = r.stored_path_purged_at
  ? '<span class="src muted" title="Original removed under the retention policy">not retained</span>'
  : r.certificate_id
    ? `<a class="src" ...>source&nbsp;PDF</a>`
    : '<span class="src muted">—</span>';
```

> A broken PDF link on a screen a prospect is looking at reads as *the system lost my document*. `not retained` reads as *the system did what it said it would*. Same underlying state, opposite impression.

---

## 6.12 Testing this stage

```bash
make demo-reset
# Upload f02 (expiring 20d), f03 (expired), and leave 3 vendors with nothing.
```

| # | Test | Expected |
|---|---|---|
| 1 | Run Workflow 2 manually | Queue contains Mercer (`EXPIRED`), Kessler (`D30`), and every `NEVER_RECEIVED` vendor |
| 2 | Inspect a draft | Under 110 words · correct policy number · **no** "compliant"/"verified"/"covered"/"valid" · no `[placeholder]` |
| 3 | Inspect the `NEVER_RECEIVED` draft | Different template · does **not** reference a policy number or expiry date |
| 4 | Approval email on your phone | Arrives · both buttons present · link starts `https://n8n.yourdomain.com/webhook-waiting/` |
| 5 | Tap **Approve** | Execution resumes · email delivered · `sent_at` and `follow_up_due` set |
| 6 | Tap **Decline** on a second draft | `approved = false` · **no** email sent |
| 7 | Re-run the workflow same day | Zero items — the same-day guard holds |
| 7b | **Re-run the next day** (advance `sent_at` by 1 day) | **Zero items** — the `awaiting_reply` guard holds. This is the daily-email bug; if the vendor reappears here, it is not fixed |
| 8 | Back-date `follow_up_due` on an `attempt_number = 1` row, run Workflow 4 | Action `REOPEN` · row closed · **no** manager alert · **no** escalation |
| 8b | Run Workflow 2 immediately after | Same vendor reappears at `attempt_number = 2` · draft says "following up" · goes through the approval gate again |
| 8c | Back-date the attempt-2 `follow_up_due`, run Workflow 4 | Action `ESCALATE` · manager alert · `escalated = true` · `chase_paused = true` |
| 9 | Re-run Workflow 2 | The paused vendor produces nothing |
| 10 | Upload a certificate for the paused vendor | Pause clears · `last_attested_at` set · **any `awaiting_reply` row closed** with `CERTIFICATE_RECEIVED` |
| 10b | Send request 1, upload the certificate, then run Workflow 4 | **No escalation.** A vendor who complied must never be escalated for ignoring you |
| 13 | Change `reminder_d30` to `45`, reload the dashboard | Amber band widens immediately — proves the config key is actually read |
| 14 | Set `pdf_retention_months = 0`, run Workflow 7 | PDF deleted from disk · `stored_path_purged_at` set · row survives · dashboard shows `not retained` |
| 11 | Set a vendor's `producer_email` and `contact_email` to NULL, re-run | Manager notice, **no** model call |
| 12 | Wipe `client_config.model_id` to a bad value | Draft falls back to the deterministic template; vendor is **not** skipped |

### The forbidden-word check on drafts

```sql
SELECT id, vendor_id, drafted_body
FROM   outreach_log
WHERE  drafted_body ~* '\y(compliant|verified|covered|coverage is valid|non-compliant)\y';
```

Must return zero rows. If it does not, the draft prompt's rule 3 needs strengthening — and check whether `06 Bucket Context` is leaking a field it should not.

---

## Stage 6 exit checklist

- [ ] Both triggers wired into one path
- [ ] `NEVER_RECEIVED` is the first Switch branch and receives its own template
- [ ] Switch has a wired fallback
- [ ] Drafts are under 110 words, contain the right policy number, and no placeholders
- [ ] Forbidden-word query over `outreach_log` returns zero rows
- [ ] Approval email received **on a phone never logged into n8n**, over mobile data
- [ ] Approve sends a real email; Decline sends nothing
- [ ] `outreach_log` row is written **before** the approval prompt
- [ ] Re-running the same day produces zero duplicates
- [ ] **Re-running the next day also produces zero** — the `awaiting_reply` guard, not just the same-day one
- [ ] Sweep runs at **07:30, before** the 08:00 chase
- [ ] Attempt 1 unanswered → `REOPEN`, no alert; attempt 2 unanswered → `ESCALATE` + pause
- [ ] The attempt-2 draft reads as a follow-up, not a repeat, and goes through the approval gate
- [ ] A vendor who sends a certificate is **not** escalated afterwards
- [ ] Escalation pauses chasing; a new certificate clears the pause
- [ ] Changing `reminder_d30` visibly changes the amber band
- [ ] Retention purge deletes the file, keeps the row, renders `not retained`
- [ ] Missing recipient produces a manager notice and no model call
- [ ] Model failure falls back to a template rather than skipping the vendor
- [ ] Status override form writes status, note, and attribution
- [ ] Workflows exported to `n8n/workflows/`

→ Continue to [Stage 7 — Dashboard](08-stage-7-dashboard.md)
