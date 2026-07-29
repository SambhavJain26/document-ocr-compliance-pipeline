# Stage 2 — Data layer

**Document 03 · Estimated time: 3–4 hours · Cost: $0**

The database is the product's memory and its audit trail. Two rules shape everything below:

1. **Nothing is deleted.** Superseded certificates are marked, never removed. When a client asks "what did we know and when did we know it?", the answer must exist.
2. **The schema encodes the honesty constraint.** Column names carry it (`addl_insd_asserted`, `cancellation_notice_wording`) so that a developer eighteen months from now cannot casually write code that overclaims.

**Gate:** `make db-verify` reports 9 application tables, 5 views, and correct seed counts.

---

## 2.1 Migration mechanics

Numbered, forward-only SQL files applied in filename order and recorded in a tracking table. No migration framework — it is four files and a shell script, and adding Flyway or Alembic here would be more moving parts than the thing they manage.

### `db/migrations/000_migrations_table.sql`

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
  filename    TEXT PRIMARY KEY,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  checksum    TEXT
);
```

### `db/scripts/apply.sh`

```bash
#!/usr/bin/env bash
# Applies every db/migrations/*.sql not yet recorded, in filename order.
# Idempotent: safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a; source .env; set +a

COMPOSE="docker compose -f infra/docker-compose.yml"
PSQL="$COMPOSE exec -T postgres psql -v ON_ERROR_STOP=1 -U ${POSTGRES_USER} -d ${POSTGRES_DB}"

# Bootstrap the tracking table.
$PSQL -q -f - < db/migrations/000_migrations_table.sql

for f in $(ls db/migrations/*.sql | sort); do
  base=$(basename "$f")
  [ "$base" = "000_migrations_table.sql" ] && continue

  already=$($PSQL -tAc "SELECT 1 FROM schema_migrations WHERE filename='$base'")
  if [ "$already" = "1" ]; then
    printf "  \033[90m·\033[0m %s (already applied)\n" "$base"
    continue
  fi

  sum=$(sha256sum "$f" | cut -d' ' -f1)
  printf "  \033[36m▸\033[0m applying %s ... " "$base"
  $PSQL -q -f - < "$f"
  $PSQL -q -c "INSERT INTO schema_migrations (filename, checksum) VALUES ('$base','$sum')"
  printf "\033[32mok\033[0m\n"
done

echo "Migrations up to date."
```

**Forward-only.** To change something, add `005_whatever.sql`. Never edit an applied file — the checksum column exists so you can detect that someone did.

---

## 2.2 `db/migrations/001_schema.sql` — the complete DDL

```sql
-- ═══════════════════════════════════════════════════════════════════
--  Vendor COI Chasing — core schema
--
--  NAMING DISCIPLINE (read before adding a column):
--    *_asserted  → a checkbox state on a form. NOT a fact about coverage.
--    *_wording   → verbatim text copied from a document. NOT a promise.
--  A column named `additional_insured` or `notice_guaranteed_days` would
--  be a defect, because the name invites downstream code to treat a form
--  marking as a coverage fact. See docs/00 §"The one constraint".
-- ═══════════════════════════════════════════════════════════════════

-- ─── Reference / configuration ─────────────────────────────────────

CREATE TABLE client_config (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL,
  description TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE client_config IS
  'Single-tenant key/value config. Model IDs live here so a retired model '
  'is a one-row UPDATE, not an edit across four workflows.';

-- Accepted certificate holder entities. A PM company managing for 40 owners
-- routinely receives certificates naming individual owner LLCs. Matching
-- against a single company name would flag all of those as defects.
CREATE TABLE holder_entities (
  id         SERIAL PRIMARY KEY,
  legal_name TEXT NOT NULL,
  normalised TEXT NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  note       TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ux_holder_entities_normalised ON holder_entities (normalised);

-- Per-trade insurance minimums. A roofer and a landscaper are not held to
-- the same number; one global minimum produces false flags in both directions.
CREATE TABLE trade_requirements (
  trade                 TEXT PRIMARY KEY,
  min_each_occurrence   NUMERIC(14,2),
  min_general_aggregate NUMERIC(14,2),
  wc_required           BOOLEAN NOT NULL DEFAULT true,
  note                  TEXT
);

-- ─── Vendors ───────────────────────────────────────────────────────

CREATE TABLE vendors (
  id                SERIAL PRIMARY KEY,
  legal_name        TEXT NOT NULL,
  display_name      TEXT,          -- what the client calls them, if different
  normalised_name   TEXT NOT NULL, -- lowercased, punctuation and suffixes stripped
  trade             TEXT REFERENCES trade_requirements(trade),

  wc_exempt         BOOLEAN NOT NULL DEFAULT false,
  wc_exempt_note    TEXT,

  chase_paused      BOOLEAN NOT NULL DEFAULT false,
  chase_paused_at   TIMESTAMPTZ,
  chase_paused_by   TEXT,
  chase_paused_note TEXT,

  last_attested_at  DATE,          -- last time coverage was re-confirmed

  contact_name      TEXT,
  contact_email     TEXT,
  contact_phone     TEXT,
  producer_name     TEXT,
  producer_email    TEXT,
  producer_phone    TEXT,

  active            BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Deliberately NOT a UNIQUE constraint on normalised_name.
-- "Mercer Plumbing" and "Mercer Plumbing & Heating" may be two real,
-- different companies. A unique constraint turns that ambiguity into
-- either a crash or a silent wrong merge — and a silent wrong merge files
-- one company's certificate against another company's record. Near-matches
-- are detected in code (validation rule 13) and routed to a human.
CREATE INDEX ix_vendors_normalised ON vendors (normalised_name);
CREATE INDEX ix_vendors_active     ON vendors (active) WHERE active;

-- ─── Vendor name aliases ───────────────────────────────────────────
-- "Mercer Plumbing" on the client's list; "M. Mercer & Sons Plumbing Inc"
-- on the certificate. Seeded at onboarding, appended on human review.
CREATE TABLE vendor_aliases (
  id         SERIAL PRIMARY KEY,
  vendor_id  INT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  alias      TEXT NOT NULL,
  normalised TEXT NOT NULL,
  source     TEXT NOT NULL DEFAULT 'manual',  -- 'manual' | 'review'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ux_vendor_aliases_normalised ON vendor_aliases (normalised);

-- ─── Certificates ──────────────────────────────────────────────────

CREATE TABLE certificates (
  id                    SERIAL PRIMARY KEY,
  vendor_id             INT REFERENCES vendors(id) ON DELETE SET NULL,

  source                TEXT NOT NULL,          -- 'email' | 'form' | 'backfill'
  source_ref            TEXT,                   -- gmail message id / form submission id
  original_filename     TEXT,
  content_sha256        TEXT NOT NULL,          -- idempotency key
  stored_path           TEXT,                   -- /data/certs/YYYY/MM/<sha>.pdf
  stored_path_purged_at TIMESTAMPTZ,            -- set by the retention job; row is kept
  byte_size             INT,
  page_count            INT,

  certificate_date      DATE,
  certificate_holder    TEXT,
  holder_match          BOOLEAN,
  holder_matched_entity TEXT,

  extraction_confidence TEXT,                   -- HIGH | MEDIUM | LOW
  confidence_reason     TEXT,
  extraction_method     TEXT,                   -- 'text' | 'vision'
  model_id              TEXT,
  input_tokens          INT,
  output_tokens         INT,
  latency_ms            INT,

  raw_extraction        JSONB,                  -- full model output, always retained
  validation_flags      JSONB NOT NULL DEFAULT '[]'::jsonb,

  status                TEXT NOT NULL,          -- see CHECK below
  status_set_by         TEXT NOT NULL DEFAULT 'system',
  status_note           TEXT,
  status_set_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

  cancellation_notice_wording TEXT,             -- verbatim. Not a promise.
  description_of_operations   TEXT,

  superseded_by         INT REFERENCES certificates(id),
  coverage_gap_days     INT,                    -- >0 when a gap preceded this cert

  received_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_cert_status CHECK (status IN (
    'ON_FILE',        -- extracted cleanly, no hard flags
    'NEEDS_REVIEW',   -- quarantined: LOW confidence or hard validation flag
    'SUPERSEDED',     -- replaced by a newer certificate
    'CANCELLED',      -- human-set only: someone learned the policy was cancelled
    'NON_RENEWED',    -- human-set only
    'REJECTED'        -- not a certificate; no vendor record created
  )),
  CONSTRAINT ck_cert_confidence CHECK (
    extraction_confidence IS NULL
    OR extraction_confidence IN ('HIGH','MEDIUM','LOW')
  )
);

-- Idempotency: the same PDF arriving twice (re-delivered email, vendor
-- forwards it again, you re-run the demo) must not create a second row.
CREATE UNIQUE INDEX ux_certificates_sha ON certificates (content_sha256);

CREATE INDEX ix_certificates_vendor  ON certificates (vendor_id);
CREATE INDEX ix_certificates_status  ON certificates (status);
CREATE INDEX ix_certificates_active  ON certificates (vendor_id)
  WHERE status IN ('ON_FILE','NEEDS_REVIEW');

COMMENT ON COLUMN certificates.cancellation_notice_wording IS
  'Verbatim text from Description of Operations about notice of cancellation. '
  'Recording that a sentence appears on a form. NOT a guarantee of notice — '
  'since the 2010 ACORD revision, notice runs to the insured, not the holder.';

-- ─── Coverages ─────────────────────────────────────────────────────

CREATE TABLE coverages (
  id                 SERIAL PRIMARY KEY,
  certificate_id     INT NOT NULL REFERENCES certificates(id) ON DELETE CASCADE,
  coverage_type      TEXT NOT NULL,   -- GENERAL_LIABILITY | AUTO | UMBRELLA | WORKERS_COMP | OTHER
  insurer_name       TEXT,
  naic               TEXT,
  policy_number      TEXT,
  effective_date     DATE,
  expiration_date    DATE,
  each_occurrence    NUMERIC(14,2),
  general_aggregate  NUMERIC(14,2),

  -- These are checkbox states on a form. They are assertions, not coverage.
  addl_insd_asserted BOOLEAN,
  subr_wvd_asserted  BOOLEAN,

  CONSTRAINT ck_coverage_type CHECK (coverage_type IN (
    'GENERAL_LIABILITY','AUTO','UMBRELLA','WORKERS_COMP','OTHER'
  ))
);

CREATE INDEX ix_coverages_cert ON coverages (certificate_id);
CREATE INDEX ix_coverages_exp  ON coverages (expiration_date);

COMMENT ON COLUMN coverages.addl_insd_asserted IS
  'Whether the ADDL INSD box carries a mark. Real additional-insured status '
  'requires a carrier endorsement (CG 20 10 / CG 20 37). This column records '
  'a tick on a form and nothing more.';

-- ─── Outreach ──────────────────────────────────────────────────────

CREATE TABLE outreach_log (
  id              SERIAL PRIMARY KEY,
  vendor_id       INT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  certificate_id  INT REFERENCES certificates(id) ON DELETE SET NULL,
  bucket          TEXT NOT NULL,   -- NEVER_RECEIVED | EXPIRED | D14 | D30 | D60 | RE_ATTEST

  -- Which request this is in the sequence for this vendor+bucket.
  -- 1 = first request, 2 = the follow-up nudge. Escalation happens when the
  -- LAST permitted attempt goes unanswered, so the product's claim
  -- ("two ignored requests escalate to a human") is literally true.
  attempt_number  INT NOT NULL DEFAULT 1,

  drafted_subject TEXT,
  drafted_body    TEXT,
  recipient       TEXT,
  cc              TEXT,

  -- `approved` records that a HUMAN approved SENDING AN EMAIL.
  -- It is never a statement about a vendor, and it never renders to a screen.
  approved        BOOLEAN,
  approved_at     TIMESTAMPTZ,
  approved_by     TEXT,

  sent_at         TIMESTAMPTZ,
  send_error      TEXT,
  gmail_thread_id TEXT,

  -- True from send until the sweep either re-opens the vendor for the next
  -- attempt or escalates. This is what stops the chase queue re-emailing the
  -- same agent every single morning.
  awaiting_reply  BOOLEAN NOT NULL DEFAULT false,
  follow_up_due   DATE,
  closed_at       TIMESTAMPTZ,
  close_reason    TEXT,          -- 'REOPENED' | 'ESCALATED' | 'CERTIFICATE_RECEIVED' | 'DECLINED'

  escalated       BOOLEAN NOT NULL DEFAULT false,
  escalated_at    TIMESTAMPTZ,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_on      DATE NOT NULL DEFAULT ((now() AT TIME ZONE 'America/New_York')::date),

  CONSTRAINT ck_outreach_bucket CHECK (bucket IN (
    'NEVER_RECEIVED','EXPIRED','D14','D30','D60','RE_ATTEST'
  )),
  CONSTRAINT ck_outreach_attempt CHECK (attempt_number >= 1)
);

CREATE INDEX ix_outreach_vendor    ON outreach_log (vendor_id);
CREATE INDEX ix_outreach_followup  ON outreach_log (follow_up_due)
  WHERE awaiting_reply;
CREATE INDEX ix_outreach_awaiting  ON outreach_log (vendor_id, bucket)
  WHERE awaiting_reply;

-- One outreach per vendor per bucket per day. Prevents a double-run of the
-- scheduled workflow producing two chase emails to the same agent.
CREATE UNIQUE INDEX ux_outreach_daily
  ON outreach_log (vendor_id, bucket, created_on);

-- ─── Dead letter ───────────────────────────────────────────────────
-- Anything that entered the system and could not be processed. The rule is
-- that nothing is ever silently dropped: if a document arrives and produces
-- no row anywhere, that is a bug.
CREATE TABLE dead_letter (
  id              SERIAL PRIMARY KEY,
  source          TEXT,        -- 'email' | 'form'
  source_ref      TEXT,
  original_filename TEXT,
  content_sha256  TEXT,
  reason_code     TEXT NOT NULL,
  reason_detail   TEXT,
  raw_payload     JSONB,
  resolved        BOOLEAN NOT NULL DEFAULT false,
  resolved_note   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_dl_reason CHECK (reason_code IN (
    'NOT_A_PDF',
    'PDF_ENCRYPTED',
    'PDF_UNREADABLE',
    'EMPTY_ATTACHMENT',
    'NO_ATTACHMENT_TEXT_REPLY',
    'NO_ATTACHMENT_PORTAL_LINK',
    'MODEL_ERROR',
    'MODEL_REFUSED',
    'JSON_PARSE_FAILED',
    'NOT_A_COI',
    'UNKNOWN'
  ))
);

CREATE INDEX ix_dead_letter_open ON dead_letter (created_at) WHERE NOT resolved;
```

### Where this schema goes beyond the build plan, and why

| Addition | Reason |
|---|---|
| `certificates.content_sha256` + unique index | Idempotency. The build plan deferred this to production, but you re-run the same fixtures dozens of times during Stage 8 and a duplicate-row bug will waste an afternoon. Four lines now. |
| `dead_letter` table | The build plan's Tier-1 "reject" behaviour had nowhere to write. Without it, a rejected document produces a Telegram message and no record — which violates "nothing is silently dropped". |
| `vendor_aliases` | The build plan flags name mismatch as a production edge case. It shows up in the demo the moment you seed real prospect vendor names and a fixture uses the legal name. Cheap now. |
| `certificates.superseded_by` | The plan says mark old certificates `SUPERSEDED` but not what replaced them. Without the pointer the audit trail is incomplete. |
| `certificates.coverage_gap_days` | Validation rule 9's output needs somewhere to live that the dashboard can read without re-deriving it. |
| Token/latency columns | You need real cost-per-certificate numbers to answer a prospect's "what does this cost to run?". Free to capture. |
| `ux_outreach_daily` | Prevents a double-triggered scheduled workflow emailing an agent twice. That failure looks like incompetence to the client's own vendor. |
| `ck_*` CHECK constraints | Status typos become errors at write time instead of rows the dashboard silently omits. |

---

## 2.3 `db/migrations/002_views.sql` — the three views that carry the logic

Bucketing and status derivation live in SQL, not in a Code node. Two reasons: date arithmetic in a model or in JavaScript is where off-by-ones breed, and having one definition means the dashboard and the chase workflow cannot disagree about whether a vendor is amber.

```sql
-- ═══════════════════════════════════════════════════════════════════
--  Views. These are the single source of truth for vendor status.
--  Both Workflow 2 (chase) and Workflow 3 (dashboard) read from them,
--  so the two can never disagree about what "expiring" means.
--
--  TIMEZONE: every view takes "today" from client_config.timezone rather
--  than CURRENT_DATE, so a day count is correct for the client's calendar
--  regardless of where the server sits.
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW v_today AS
SELECT (now() AT TIME ZONE COALESCE(
          (SELECT value FROM client_config WHERE key = 'timezone'),
          'UTC'))::date AS today;

-- ── The current certificate for each vendor ────────────────────────
-- "Current" = the most recent non-superseded, non-rejected certificate.
-- NEEDS_REVIEW certificates appear here so the dashboard can show them,
-- but v_vendor_status never treats their dates as fact.
CREATE OR REPLACE VIEW v_current_certificate AS
SELECT DISTINCT ON (c.vendor_id)
       c.*
FROM   certificates c
WHERE  c.status IN ('ON_FILE','NEEDS_REVIEW','CANCELLED','NON_RENEWED')
ORDER  BY c.vendor_id,
          c.certificate_date DESC NULLS LAST,
          c.received_at      DESC;

-- ── Earliest expiring coverage line per certificate ────────────────
-- A certificate with four coverage lines expiring across three months is
-- only as current as its earliest line. Reporting the GL date alone hides
-- a workers' comp policy that lapsed six weeks ago.
CREATE OR REPLACE VIEW v_certificate_expiry AS
SELECT cov.certificate_id,
       MIN(cov.expiration_date)                                  AS earliest_expiration,
       MAX(cov.expiration_date)                                  AS latest_expiration,
       COUNT(*)                                                  AS coverage_line_count,
       BOOL_OR(cov.coverage_type = 'GENERAL_LIABILITY')          AS has_gl,
       BOOL_OR(cov.coverage_type = 'WORKERS_COMP')               AS has_wc,
       MAX(cov.each_occurrence)   FILTER (WHERE cov.coverage_type='GENERAL_LIABILITY') AS gl_each_occurrence,
       MAX(cov.general_aggregate) FILTER (WHERE cov.coverage_type='GENERAL_LIABILITY') AS gl_general_aggregate,
       (ARRAY_AGG(cov.insurer_name  ORDER BY cov.expiration_date))[1] AS earliest_insurer,
       (ARRAY_AGG(cov.policy_number ORDER BY cov.expiration_date))[1] AS earliest_policy_number,
       (ARRAY_AGG(cov.coverage_type ORDER BY cov.expiration_date))[1] AS earliest_coverage_type
FROM   coverages cov
GROUP  BY cov.certificate_id;

-- ── The master status view ─────────────────────────────────────────
-- Reminder thresholds are read from client_config, not hardcoded. Changing
-- the cadence for a client is then an UPDATE, not a view rewrite — and the
-- seeded values are guaranteed to be the ones actually in force.
CREATE OR REPLACE VIEW v_thresholds AS
SELECT
  (SELECT value::int FROM client_config WHERE key='reminder_d14') AS d14,
  (SELECT value::int FROM client_config WHERE key='reminder_d30') AS d30,
  (SELECT value::int FROM client_config WHERE key='reminder_d60') AS d60,
  (SELECT value::int FROM client_config WHERE key='reattest_days') AS reattest;

CREATE OR REPLACE VIEW v_vendor_status AS
WITH t AS (SELECT today FROM v_today),
     r AS (SELECT * FROM v_thresholds)
SELECT
  v.id                       AS vendor_id,
  v.legal_name,
  COALESCE(v.display_name, v.legal_name) AS display_name,
  v.trade,
  v.wc_exempt,
  v.chase_paused,
  v.producer_email,
  v.producer_name,
  v.contact_email,
  v.last_attested_at,

  c.id                       AS certificate_id,
  c.status                   AS certificate_status,
  c.certificate_date,
  c.certificate_holder,
  c.holder_match,
  c.extraction_confidence,
  c.confidence_reason,
  c.extraction_method,
  c.validation_flags,
  c.cancellation_notice_wording,
  c.coverage_gap_days,
  c.stored_path,

  e.earliest_expiration,
  e.coverage_line_count,
  e.has_gl,
  e.has_wc,
  e.gl_each_occurrence,
  e.gl_general_aggregate,
  e.earliest_insurer,
  e.earliest_policy_number,

  t.today,

  -- Days until the earliest coverage line expires. NULL when nothing on file.
  (e.earliest_expiration - t.today) AS days_to_expiry,

  -- ── Bucket. Order of the CASE arms IS the business rule. ──────────
  -- NEVER_RECEIVED is first and deliberately so: a vendor with no
  -- certificate has a NULL expiry, and any bucketing driven by the day
  -- count alone lets that vendor fall through to "no action". That would
  -- mean the system ignores the MOST non-compliant vendors while
  -- diligently chasing the ones merely close to renewal — the exact
  -- failure this product claims to prevent.
  CASE
    WHEN v.chase_paused                              THEN 'PAUSED'
    WHEN c.id IS NULL                                THEN 'NEVER_RECEIVED'
    WHEN c.status = 'NEEDS_REVIEW'                   THEN 'NEEDS_REVIEW'
    WHEN c.status IN ('CANCELLED','NON_RENEWED')     THEN 'EXPIRED'
    WHEN e.earliest_expiration IS NULL               THEN 'NEEDS_REVIEW'
    WHEN e.earliest_expiration <  t.today            THEN 'EXPIRED'
    WHEN e.earliest_expiration <= t.today + r.d14    THEN 'D14'
    WHEN e.earliest_expiration <= t.today + r.d30    THEN 'D30'
    WHEN e.earliest_expiration <= t.today + r.d60    THEN 'D60'
    WHEN v.last_attested_at IS NULL
      OR v.last_attested_at < t.today - r.reattest   THEN 'RE_ATTEST'
    ELSE 'CURRENT'
  END AS bucket,

  -- ── Display colour. Presentation only; never a verdict. ───────────
  CASE
    WHEN c.id IS NULL                            THEN 'grey'
    WHEN c.status = 'NEEDS_REVIEW'               THEN 'amber'
    WHEN c.status IN ('CANCELLED','NON_RENEWED') THEN 'red'
    WHEN e.earliest_expiration IS NULL           THEN 'amber'
    WHEN e.earliest_expiration <  t.today        THEN 'red'
    WHEN e.earliest_expiration <= t.today + r.d30 THEN 'amber'
    ELSE 'green'
  END AS colour

FROM       vendors v
CROSS JOIN t
CROSS JOIN r
LEFT JOIN  v_current_certificate c ON c.vendor_id = v.id
LEFT JOIN  v_certificate_expiry  e ON e.certificate_id = c.id
WHERE      v.active;
```

### Reading the bucket CASE

Arm order is load-bearing. Walk it once so you understand what each arm protects:

| Arm | Guards against |
|---|---|
| `chase_paused` first | Emailing a vendor after a human took the conversation over. Makes your client look disorganised to their own vendor. |
| `c.id IS NULL` → `NEVER_RECEIVED` | The build plan's flagged bug. A NULL expiry silently falling through to no-action. |
| `NEEDS_REVIEW` before any date arm | A quarantined extraction's dates being treated as fact by the chase logic. |
| `CANCELLED / NON_RENEWED` → `EXPIRED` | A human-known cancellation showing green because the printed expiry is still in the future. |
| `earliest_expiration IS NULL` → `NEEDS_REVIEW` | A certificate that parsed but produced no usable coverage dates. Not silently "current". |
| Date arms tightest-first | A vendor 10 days out landing in the 60-day bucket. |

---

## 2.4 `db/migrations/003_seed_config.sql`

```sql
INSERT INTO client_config (key, value, description) VALUES
  -- identity
  ('client_legal_name',      'Harbourline Property Management LLC', 'Primary certificate holder name'),
  ('timezone',               'America/New_York',                    'Drives all day counts and schedules'),

  -- thresholds
  ('min_each_occurrence',    '1000000',    'Default GL each-occurrence minimum'),
  ('min_general_aggregate',  '2000000',    'Default GL aggregate minimum'),
  ('holder_match_threshold', '0.80',       'Token-set ratio at or above which holder is a match'),
  ('vendor_match_exact',     '0.95',       'At or above: same vendor'),
  ('vendor_match_review',    '0.80',       'Between review and exact: POSSIBLE_DUPLICATE_VENDOR'),

  -- cadence. These three are READ BY v_vendor_status — changing one changes
  -- behaviour. (A config key nothing reads is worse than no key at all.)
  ('reminder_d60',           '60',         'Days before expiry: earliest heads-up'),
  ('reminder_d30',           '30',         'Days before expiry: standard request'),
  ('reminder_d14',           '14',         'Days before expiry: urgent request'),
  ('reattest_days',          '90',         'Quarterly re-confirmation interval'),
  ('follow_up_days',         '7',          'Days to wait for a reply before the next attempt'),
  ('max_chase_attempts',     '2',          'Requests sent before handing the vendor to a person'),

  -- routing
  ('approval_channel',       'email',      'email | telegram'),
  ('approver_email',         'CHANGE_ME@example.com', 'Who receives Approve/Decline'),
  ('from_mailbox',           'CHANGE_ME@example.com', 'From address on vendor emails — MUST be the client mailbox'),
  ('telegram_chat_id',       'CHANGE_ME',  'Manager alert destination'),

  -- model
  ('openai_endpoint',        'https://api.openai.com/v1/responses', 'Responses API'),
  ('model_id',               'gpt-5.4-mini-2026-03-17', 'PINNED SNAPSHOT — never a floating alias'),
  ('model_id_escalation',    'gpt-5.6-terra',           'Only for a specific repeatedly-failing document'),
  ('reasoning_effort_text',  'low',        'Text branch: transcription, not judgement'),
  ('reasoning_effort_vision','medium',     'Vision branch: reading a skewed scan is the whole job'),
  ('pdf_detail',             'high',       'input_file detail for the vision branch'),
  ('max_output_tokens',      '3000',       'Generous headroom for a multi-coverage certificate'),

  -- retention & access
  ('pdf_retention_months',   '24',         'How long original PDFs are kept'),
  ('dashboard_token',        'CHANGE_ME',  'Must equal DASHBOARD_TOKEN in .env')
ON CONFLICT (key) DO NOTHING;
```

Three values must be edited before Stage 5: `approver_email`, `from_mailbox`, `dashboard_token`. `verify.sh` fails while any still reads `CHANGE_ME`.

### `db/migrations/004_seed_reference.sql`

```sql
-- ── Trade requirements ─────────────────────────────────────────────
-- The DEFAULT row is the fallback when a vendor's trade has no row.
INSERT INTO trade_requirements (trade, min_each_occurrence, min_general_aggregate, wc_required, note) VALUES
  ('DEFAULT',      1000000, 2000000, true,  'Fallback for any trade without its own row'),
  ('Roofing',      2000000, 4000000, true,  'Height work; higher limits are standard'),
  ('Electrical',   1000000, 2000000, true,  'Fire risk'),
  ('Plumbing',     1000000, 2000000, true,  'Water damage risk'),
  ('HVAC',         1000000, 2000000, true,  NULL),
  ('General Contracting', 2000000, 4000000, true, 'Structural work'),
  ('Landscaping',   500000, 1000000, false, 'Frequently sole proprietors'),
  ('Cleaning',      500000, 1000000, false, 'Frequently sole proprietors'),
  ('Pest Control',  500000, 1000000, true,  'Chemical handling'),
  ('Painting',      500000, 1000000, true,  NULL),
  ('Handyman',      500000, 1000000, false, 'Often WC-exempt sole proprietors')
ON CONFLICT (trade) DO NOTHING;

-- ── Accepted certificate holders ───────────────────────────────────
-- Demo values. Replace with the client's real entities at onboarding.
INSERT INTO holder_entities (legal_name, normalised, is_primary, note) VALUES
  ('Harbourline Property Management LLC', 'harbourline property management', true,  'Management company'),
  ('Harbourline Residential Holdings LLC','harbourline residential holdings', false,'Owner LLC'),
  ('Sable Court Properties LLC',          'sable court properties',           false,'Owner LLC')
ON CONFLICT (normalised) DO NOTHING;
```

> `normalised` values here must match exactly what `normalise.js` (Stage 4 §4.6) produces. `verify.sh` re-derives them and fails on a mismatch, so you cannot drift.

---

## 2.5 Vendor seeding

**Seed the prospect's real vendor names wherever you can get them.** Ask when scheduling the call:

> *"Send me the names of your regular vendors so I can set the demo up against your actual list — nothing else needed, just names and roughly what each one does."*

A prospect seeing their own vendor names on screen, four of them grey, is looking at a picture of their business rather than a demo of your software. It also removes the "whose vendors are those?" reaction that makes a staged demo visible. Fall back to the fictional set only if they do not reply.

### `db/seeds/vendors.csv`

```csv
legal_name,display_name,trade,contact_email,producer_name,producer_email,wc_exempt,notes
Mercer Plumbing LLC,Mercer Plumbing,Plumbing,office@mercerplumbing.example,Kestrel Insurance Partners,certs@kestrelins.example,false,Fixtures 3/12/13
Kessler Heating & Air Inc,Kessler HVAC,HVAC,dispatch@kesslerhvac.example,Bramble & Co Insurance,certs@brambleco.example,false,Fixture 2 — demo hero
Vaughn Electric Co,Vaughn Electric,Electrical,admin@vaughnelectric.example,Kestrel Insurance Partners,certs@kestrelins.example,false,Fixture 1
Alder Landscaping,Alder Landscaping,Landscaping,alder@alderlandscaping.example,Pinecrest Agency,certs@pinecrest.example,true,Fixture 15 — WC exempt sole proprietor
Rowan Roofing LLC,Rowan Roofing,Roofing,info@rowanroofing.example,Bramble & Co Insurance,certs@brambleco.example,false,Fixture 7 — limits below minimum
Calder Painting Services,Calder Painting,Painting,hello@calderpainting.example,Pinecrest Agency,certs@pinecrest.example,false,Fixture 5 — inverted dates
Thorne Pest Control,Thorne Pest,Pest Control,service@thornepest.example,Kestrel Insurance Partners,certs@kestrelins.example,false,Fixture 9 — no GL line
Bexley Cleaning Co,Bexley Cleaning,Cleaning,team@bexleycleaning.example,Pinecrest Agency,certs@pinecrest.example,true,Fixture 6 — wrong holder
Ashgrove General Contracting,Ashgrove GC,General Contracting,office@ashgrovegc.example,Bramble & Co Insurance,certs@brambleco.example,false,Fixture 8 — four expiry dates
Linden Glass & Glazing,Linden Glass,General Contracting,quotes@lindenglass.example,Kestrel Insurance Partners,certs@kestrelins.example,false,Fixture 16 — owner LLC holder
Harrow Appliance Repair,Harrow Appliance,Handyman,fix@harrowappliance.example,Pinecrest Agency,certs@pinecrest.example,true,Fixture 20 — cancellation wording
Fenwick Flooring,Fenwick Flooring,General Contracting,sales@fenwickflooring.example,Bramble & Co Insurance,certs@brambleco.example,false,Fixture 10 — multi-attachment
Selby Locksmiths,Selby Locksmiths,Handyman,keys@selbylocks.example,Kestrel Insurance Partners,certs@kestrelins.example,true,Fixture 10 — multi-attachment
Draycott Tree Services,Draycott Tree,Landscaping,office@draycotttree.example,Pinecrest Agency,certs@pinecrest.example,false,Fixture 18 — encrypted PDF
Whitlock Gutter & Drain,Whitlock Gutter,Roofing,admin@whitlockgutter.example,Bramble & Co Insurance,certs@brambleco.example,false,Fixture 19 — portal-link email
Orme Concrete Works,Orme Concrete,General Contracting,office@ormeconcrete.example,Kestrel Insurance Partners,certs@kestrelins.example,false,NEVER_RECEIVED
Padstow Window Cleaning,Padstow Windows,Cleaning,hello@padstowwindows.example,Pinecrest Agency,certs@pinecrest.example,true,NEVER_RECEIVED
Quill Handyman Services,Quill Handyman,Handyman,quill@quillhandyman.example,Pinecrest Agency,certs@pinecrest.example,true,NEVER_RECEIVED
```

Eighteen vendors. **Four end the demo grey:** Orme, Padstow, Quill, and Draycott — the last because its only certificate is the encrypted fixture, which dead-letters rather than filing.

Four grey rows at the top of an otherwise working register is the picture that sells. Keep the count at four when you swap in a prospect's real vendor list: seed every name they give you, and simply leave four without a fixture.

### `db/scripts/seed-vendors.sh`

```bash
#!/usr/bin/env bash
# Loads db/seeds/vendors.csv, deriving normalised_name the same way the
# application does. Re-runnable: existing vendors are updated, not duplicated.
set -euo pipefail
cd "$(dirname "$0")/../.."
set -a; source .env; set +a

COMPOSE="docker compose -f infra/docker-compose.yml"
PSQL="$COMPOSE exec -T postgres psql -v ON_ERROR_STOP=1 -U ${POSTGRES_USER} -d ${POSTGRES_DB}"

$PSQL <<'SQL'
CREATE TEMP TABLE vendor_import (
  legal_name TEXT, display_name TEXT, trade TEXT, contact_email TEXT,
  producer_name TEXT, producer_email TEXT, wc_exempt BOOLEAN, notes TEXT
);
SQL

$PSQL -c "\copy vendor_import FROM 'db/seeds/vendors.csv' WITH (FORMAT csv, HEADER true)" \
  < db/seeds/vendors.csv || true

# The \copy above needs the file inside the container; simpler to stream it:
cat db/seeds/vendors.csv | $PSQL <<'SQL'
CREATE TEMP TABLE vendor_import (
  legal_name TEXT, display_name TEXT, trade TEXT, contact_email TEXT,
  producer_name TEXT, producer_email TEXT, wc_exempt BOOLEAN, notes TEXT
);
\copy vendor_import FROM STDIN WITH (FORMAT csv, HEADER true)

-- normalise_name(): must stay byte-identical to n8n/code/lib/normalise.js.
-- Stage 8 has a test that runs both over the same 30 strings and diffs them.
INSERT INTO vendors (legal_name, display_name, normalised_name, trade,
                     contact_email, producer_name, producer_email, wc_exempt)
SELECT
  i.legal_name,
  i.display_name,
  btrim(regexp_replace(
    regexp_replace(
      regexp_replace(lower(i.legal_name),
        '\s+(llc|l\.l\.c\.|inc|inc\.|incorporated|corp|corp\.|corporation|co|co\.|company|ltd|ltd\.|limited|lp|llp|pllc|pc|dba)\b', '', 'g'),
      '[^a-z0-9 ]', ' ', 'g'),
    '\s+', ' ', 'g')),
  COALESCE(i.trade, 'DEFAULT'),
  i.contact_email, i.producer_name, i.producer_email, COALESCE(i.wc_exempt, false)
FROM vendor_import i
ON CONFLICT DO NOTHING;
SQL

echo "Vendors seeded."
```

> The normalisation regex is duplicated between SQL and JavaScript. That duplication is deliberate — seeding happens in SQL, matching happens in a Code node, and neither can call the other. Stage 8's `test_normalise.js` runs 30 strings through both and fails on any divergence. **If you change one, change both.**

---

## 2.6 Named queries

Keep every non-trivial query in `db/queries/` as a file, and paste it into the Postgres node. The file is the source of truth; the node is a copy. This is how you diff a query change six weeks later.

### `db/queries/q_dashboard.sql`

```sql
-- Feeds Workflow 3. One row per active vendor, already sorted for display.
SELECT
  vendor_id, display_name, legal_name, trade,
  certificate_id, certificate_status, certificate_date, certificate_holder,
  holder_match, extraction_confidence, confidence_reason, extraction_method,
  validation_flags, cancellation_notice_wording, coverage_gap_days, stored_path,
  earliest_expiration, coverage_line_count, has_gl, has_wc,
  gl_each_occurrence, gl_general_aggregate,
  earliest_insurer, earliest_policy_number,
  days_to_expiry, bucket, colour, today, chase_paused, wc_exempt
FROM v_vendor_status
ORDER BY
  -- Vendors you have nothing for sort to the TOP. They are the ones worth
  -- looking at first: "expiring soon" is a calendar problem, "never sent
  -- anything" is a different problem entirely.
  CASE bucket
    WHEN 'NEVER_RECEIVED' THEN 0
    WHEN 'EXPIRED'        THEN 1
    WHEN 'NEEDS_REVIEW'   THEN 2
    WHEN 'D14'            THEN 3
    WHEN 'D30'            THEN 4
    WHEN 'D60'            THEN 5
    WHEN 'RE_ATTEST'      THEN 6
    WHEN 'PAUSED'         THEN 7
    ELSE 8
  END,
  earliest_expiration NULLS FIRST,
  display_name;
```

### `db/queries/q_chase_queue.sql`

```sql
-- Feeds Workflow 2. Only vendors that need contacting today.
--
-- THE `awaiting_reply` GUARD IS LOAD-BEARING. Excluding only "contacted today"
-- would chase an expired vendor EVERY MORNING for as long as they stayed
-- expired — a daily email to the same insurance agent, in your client's name.
-- That is not a nuisance; it is the single fastest way to make your client
-- look incompetent to their own vendor.
--
-- `attempt_number` is the next request in the sequence, so the drafting step
-- can word a follow-up differently from a first approach.
SELECT s.*,
       COALESCE((
         SELECT MAX(o.attempt_number) FROM outreach_log o
         WHERE o.vendor_id = s.vendor_id AND o.bucket = s.bucket
           AND o.sent_at IS NOT NULL AND NOT o.escalated
       ), 0) + 1 AS attempt_number
FROM   v_vendor_status s
WHERE  s.bucket IN ('NEVER_RECEIVED','EXPIRED','D14','D30','D60','RE_ATTEST')
  AND  NOT s.chase_paused
  -- not already drafted for this bucket today (double-run guard)
  AND  NOT EXISTS (
         SELECT 1 FROM outreach_log o
         WHERE  o.vendor_id = s.vendor_id
           AND  o.bucket    = s.bucket
         AND  o.created_on = s.today
       )
  -- not currently waiting on a reply to an earlier request
  AND  NOT EXISTS (
         SELECT 1 FROM outreach_log o
         WHERE  o.vendor_id = s.vendor_id
           AND  o.bucket    = s.bucket
           AND  o.awaiting_reply
       )
  -- attempts not already exhausted for this bucket
  AND  COALESCE((
         SELECT MAX(o.attempt_number) FROM outreach_log o
         WHERE o.vendor_id = s.vendor_id AND o.bucket = s.bucket
           AND o.sent_at IS NOT NULL AND NOT o.escalated
       ), 0) < (SELECT value::int FROM client_config WHERE key='max_chase_attempts')
ORDER BY
  CASE s.bucket
    WHEN 'NEVER_RECEIVED' THEN 0
    WHEN 'EXPIRED'        THEN 1
    WHEN 'D14'            THEN 2
    WHEN 'D30'            THEN 3
    WHEN 'D60'            THEN 4
    ELSE 5
  END,
  s.earliest_expiration NULLS FIRST;
```

### `db/queries/q_followups_due.sql`

```sql
-- Feeds Workflow 4, the 07:30 sweep. A request was sent, the reply window has
-- passed, and no newer certificate arrived since.
--
-- `action` decides what the sweep does with each row:
--   REOPEN    — attempts remain; release the vendor so the 08:00 chase run
--               sends the next request the same morning
--   ESCALATE  — the last permitted attempt went unanswered; alert a person
--               and pause automated chasing for this vendor
--
-- This is what makes "two ignored requests escalate to a human" literally
-- true rather than approximately true. It is a line you say out loud in the
-- demo, so the code has to mean it.
SELECT o.id                AS outreach_id,
       o.vendor_id,
       o.bucket,
       o.recipient,
       o.sent_at,
       o.follow_up_due,
       o.attempt_number,
       v.display_name,
       v.legal_name,
       v.producer_email,
       (SELECT today FROM v_today) AS today,
       CASE WHEN o.attempt_number >=
                 (SELECT value::int FROM client_config WHERE key='max_chase_attempts')
            THEN 'ESCALATE' ELSE 'REOPEN'
       END AS action
FROM   outreach_log o
JOIN   vendors v ON v.id = o.vendor_id
WHERE  o.awaiting_reply
  AND  o.sent_at IS NOT NULL
  AND  o.approved IS TRUE
  AND  NOT o.escalated
  AND  o.follow_up_due <= (SELECT today FROM v_today)
  AND  NOT EXISTS (
         SELECT 1 FROM certificates c
         WHERE  c.vendor_id = o.vendor_id
           AND  c.received_at > o.sent_at
           AND  c.status = 'ON_FILE'
       )
ORDER BY o.follow_up_due;
```

### `db/queries/q_close_outreach_on_certificate.sql`

Called from the intake workflow when a certificate lands. Closes any open request so the vendor is not chased for something they have already sent.

```sql
-- $1 = vendor_id
UPDATE outreach_log
SET    awaiting_reply = false,
       closed_at      = now(),
       close_reason   = 'CERTIFICATE_RECEIVED'
WHERE  vendor_id = $1 AND awaiting_reply
RETURNING id;
```

### `db/queries/q_retention_purge.sql`

`client_config.pdf_retention_months` is a commitment you make to prospects — *"we keep the original certificates for 24 months"*. Nothing read it until now, which meant describing a setting that did nothing.

```sql
-- Certificates whose retained PDF is older than the configured window.
-- The ROW IS KEPT. Only the stored PDF goes: the register, the extracted
-- data, and the outreach history remain, because the audit trail is the
-- product. Only the document you promised to delete is deleted.
SELECT c.id, c.stored_path, v.display_name, c.received_at
FROM   certificates c
LEFT   JOIN vendors v ON v.id = c.vendor_id
WHERE  c.stored_path IS NOT NULL
  AND  c.stored_path_purged_at IS NULL
  AND  c.received_at < now() - (
         (SELECT value FROM client_config WHERE key='pdf_retention_months')
         || ' months')::interval
ORDER BY c.received_at
LIMIT  200;
```

### `db/queries/q_upsert_certificate.sql`

The intake workflow's write. One statement, parameterised, so a partial write is impossible.

```sql
-- $1 vendor_id           $2 source            $3 source_ref
-- $4 original_filename   $5 content_sha256    $6 stored_path
-- $7 byte_size           $8 page_count        $9 certificate_date
-- $10 certificate_holder $11 holder_match     $12 holder_matched_entity
-- $13 confidence         $14 confidence_reason $15 extraction_method
-- $16 model_id           $17 input_tokens     $18 output_tokens
-- $19 latency_ms         $20 raw_extraction (jsonb)
-- $21 validation_flags (jsonb)                $22 status
-- $23 cancellation_notice_wording             $24 description_of_operations
-- $25 coverage_gap_days

INSERT INTO certificates (
  vendor_id, source, source_ref, original_filename, content_sha256, stored_path,
  byte_size, page_count, certificate_date, certificate_holder, holder_match,
  holder_matched_entity, extraction_confidence, confidence_reason,
  extraction_method, model_id, input_tokens, output_tokens, latency_ms,
  raw_extraction, validation_flags, status,
  cancellation_notice_wording, description_of_operations, coverage_gap_days
) VALUES (
  $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,
  $20::jsonb,$21::jsonb,$22,$23,$24,$25
)
ON CONFLICT (content_sha256) DO UPDATE SET
  -- Same PDF seen again. Refresh the derived fields (the model or the rules
  -- may have improved) but never duplicate the row and never lose the
  -- original receipt timestamp.
  validation_flags      = EXCLUDED.validation_flags,
  extraction_confidence = EXCLUDED.extraction_confidence,
  confidence_reason     = EXCLUDED.confidence_reason,
  raw_extraction        = EXCLUDED.raw_extraction,
  status                = EXCLUDED.status,
  status_set_at         = now()
RETURNING id, (xmax = 0) AS was_insert;
```

`xmax = 0` is the standard Postgres idiom for "this row was inserted, not updated". The intake workflow uses it to decide whether to send a "new certificate processed" notification or stay quiet about a duplicate.

### `db/queries/q_supersede.sql`

```sql
-- Called after a successful insert when the vendor already had a certificate.
-- $1 new certificate id   $2 vendor_id
UPDATE certificates
SET    status        = 'SUPERSEDED',
       superseded_by = $1,
       status_set_at = now(),
       status_set_by = 'system'
WHERE  vendor_id = $2
  AND  id <> $1
  AND  status IN ('ON_FILE','NEEDS_REVIEW')
RETURNING id;
```

---

## 2.7 The timezone pattern — read this once, then stop worrying

Three clocks exist and each has one job:

| Clock | Set to | Used for |
|---|---|---|
| Postgres container `TZ` | `UTC` | Storage. `now()`, `TIMESTAMPTZ` |
| n8n container `TZ` / `GENERIC_TIMEZONE` | `America/New_York` | Schedule Trigger fires at 08:00 *local* |
| `client_config.timezone` | `America/New_York` | Every day count the client sees |

`v_today` converts `now()` into the client's calendar date once, and every other view joins to it. So a certificate expiring 14 March reads "expires in 20 days" on 22 February in New York, regardless of the server's location or the developer's laptop.

**Never write `CURRENT_DATE` in a query that produces a user-facing day count.** `CURRENT_DATE` is the server's date. At 21:00 in New York the server is already on tomorrow, and every count on the dashboard is off by one — a bug that appears only in the evening and vanishes overnight, which is a genuinely miserable thing to chase. `verify.sh` greps `db/queries/` for `CURRENT_DATE` and fails if it finds one.

---

## 2.8 `db/scripts/verify.sh` — the Stage 2 gate

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/../.."
set -a; source .env; set +a

COMPOSE="docker compose -f infra/docker-compose.yml"
Q() { $COMPOSE exec -T postgres psql -tAq -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "$1"; }

FAIL=0
ok()  { printf "  \033[32m✓\033[0m %s\n" "$1"; }
bad() { printf "  \033[31m✗\033[0m %s\n" "$1"; FAIL=1; }

chk() { # name expected actual
  if [ "$2" = "$3" ]; then ok "$1 = $3"; else bad "$1: expected $2, got $3"; fi
}

echo "── Objects ───────────────────────────────────────"
# schema_migrations is migration infrastructure, not application schema — excluded.
chk "tables" 9 "$(Q "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' AND table_name <> 'schema_migrations'")"
chk "views"  5 "$(Q "SELECT count(*) FROM information_schema.views  WHERE table_schema='public'")"

for t in client_config holder_entities trade_requirements vendors vendor_aliases \
         certificates coverages outreach_log dead_letter; do
  n=$(Q "SELECT to_regclass('public.$t') IS NOT NULL")
  [ "$n" = "t" ] && ok "table $t" || bad "table $t missing"
done

echo
echo "── Seeds ─────────────────────────────────────────"
chk "client_config rows"   26 "$(Q "SELECT count(*) FROM client_config")"
chk "trade_requirements"   11 "$(Q "SELECT count(*) FROM trade_requirements")"
chk "holder_entities"       3 "$(Q "SELECT count(*) FROM holder_entities")"
chk "vendors"              18 "$(Q "SELECT count(*) FROM vendors")"
chk "wc_exempt vendors"     6 "$(Q "SELECT count(*) FROM vendors WHERE wc_exempt")"

echo
echo "── Config placeholders ───────────────────────────"
ph=$(Q "SELECT count(*) FROM client_config WHERE value LIKE 'CHANGE_ME%'")
[ "$ph" = "0" ] && ok "no CHANGE_ME values remain" || bad "$ph config values still read CHANGE_ME"

echo
echo "── Timezone discipline ───────────────────────────"
if grep -rn "CURRENT_DATE" db/queries/ db/migrations/ 2>/dev/null | grep -v '^\s*--'; then
  bad "CURRENT_DATE found — use v_today instead (see §2.7)"
else
  ok "no CURRENT_DATE in queries or migrations"
fi

echo
echo "── View sanity ───────────────────────────────────"
today=$(Q "SELECT today FROM v_today")
[ -n "$today" ] && ok "v_today = $today" || bad "v_today returned nothing"

rows=$(Q "SELECT count(*) FROM v_vendor_status")
chk "v_vendor_status rows" 18 "$rows"

nr=$(Q "SELECT count(*) FROM v_vendor_status WHERE bucket='NEVER_RECEIVED'")
[ "$nr" = "18" ] && ok "all 18 vendors are NEVER_RECEIVED (no certs yet)" \
                 || bad "expected 18 NEVER_RECEIVED, got $nr"

echo
echo "── Normalisation parity ──────────────────────────"
sqln=$(Q "SELECT normalised_name FROM vendors WHERE legal_name='Kessler Heating & Air Inc'")
[ "$sqln" = "kessler heating air" ] && ok "SQL normalisation: '$sqln'" \
  || bad "SQL normalisation gave '$sqln', expected 'kessler heating air'"

echo
if [ "$FAIL" -eq 0 ]; then
  printf "\033[32mStage 2 gate PASSED\033[0m\n"
else
  printf "\033[31mStage 2 gate FAILED\033[0m\n"
fi
exit $FAIL
```

Add to the Makefile:

```makefile
db-seed:  ## Seed vendors and reference data
	@bash db/scripts/seed-vendors.sh
```

Run the stage:

```bash
make db-apply
make db-seed
make db-verify
```

---

## 2.9 `db/scripts/reset-demo.sh` — you will need this mid-call

```bash
#!/usr/bin/env bash
# Returns the database to its demo opening state: 18 vendors, zero documents.
# Deliberately never touches vendors, client_config, holder_entities,
# trade_requirements, or the n8n database.
set -euo pipefail
cd "$(dirname "$0")/../.."
set -a; source .env; set +a

docker compose -f infra/docker-compose.yml exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" <<'SQL'
BEGIN;
TRUNCATE coverages, certificates, outreach_log, dead_letter RESTART IDENTITY CASCADE;
UPDATE vendors SET
  chase_paused = false, chase_paused_at = NULL,
  chase_paused_by = NULL, chase_paused_note = NULL,
  last_attested_at = NULL;
COMMIT;

SELECT bucket, count(*) FROM v_vendor_status GROUP BY bucket ORDER BY 1;
SQL

# Retained PDFs from previous runs.
docker compose -f infra/docker-compose.yml exec -T n8n \
  sh -c 'rm -rf /data/certs/* 2>/dev/null || true'

echo "Demo state restored."
```

Time it. It must complete in under two seconds — you may run it while a prospect is talking.

```bash
chmod +x db/scripts/*.sh
time make demo-reset
```

---

## Stage 2 exit checklist

- [ ] `make db-apply` applies all migrations; re-running is a no-op
- [ ] `make db-seed` loads 18 vendors; re-running does not duplicate
- [ ] `make db-verify` exits 0: 9 application tables, 5 views, all seed counts correct
- [ ] **Every `client_config` key is read by something.** `reminder_d14/30/60` by `v_thresholds`, `max_chase_attempts` by the chase and sweep queries, `pdf_retention_months` by the purge job. A key nothing reads is a setting you would describe to a client that does nothing.
- [ ] `approver_email`, `from_mailbox`, `dashboard_token` set to real values
- [ ] `v_vendor_status` returns 18 rows, all `NEVER_RECEIVED`, all `grey`
- [ ] No `CURRENT_DATE` anywhere in `db/queries/` or `db/migrations/`
- [ ] `make demo-reset` completes in under 2 seconds
- [ ] All five queries saved in `db/queries/`

→ Continue to [Stage 3 — Fixture generation](04-stage-3-fixture-generation.md)
