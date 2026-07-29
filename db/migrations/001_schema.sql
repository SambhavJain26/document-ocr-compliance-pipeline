CREATE TABLE client_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE holder_entities (
  id SERIAL PRIMARY KEY,
  legal_name TEXT NOT NULL,
  normalised TEXT NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_holder_entities_normalised ON holder_entities (normalised);

CREATE TABLE trade_requirements (
  trade TEXT PRIMARY KEY,
  min_each_occurrence NUMERIC(14,2),
  min_general_aggregate NUMERIC(14,2),
  wc_required BOOLEAN NOT NULL DEFAULT true,
  note TEXT
);

CREATE TABLE vendors (
  id SERIAL PRIMARY KEY,
  legal_name TEXT NOT NULL,
  display_name TEXT,
  normalised_name TEXT NOT NULL,
  trade TEXT REFERENCES trade_requirements(trade),
  wc_exempt BOOLEAN NOT NULL DEFAULT false,
  wc_exempt_note TEXT,
  chase_paused BOOLEAN NOT NULL DEFAULT false,
  chase_paused_at TIMESTAMPTZ,
  chase_paused_by TEXT,
  chase_paused_note TEXT,
  last_attested_at DATE,
  contact_name TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  producer_name TEXT,
  producer_email TEXT,
  producer_phone TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_vendors_normalised ON vendors (normalised_name);
CREATE INDEX ix_vendors_active ON vendors (active) WHERE active;

CREATE TABLE vendor_aliases (
  id SERIAL PRIMARY KEY,
  vendor_id INT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  alias TEXT NOT NULL,
  normalised TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'manual',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_vendor_aliases_normalised ON vendor_aliases (normalised);

CREATE TABLE certificates (
  id SERIAL PRIMARY KEY,
  vendor_id INT REFERENCES vendors(id) ON DELETE SET NULL,
  source TEXT NOT NULL,
  source_ref TEXT,
  original_filename TEXT,
  content_sha256 TEXT NOT NULL,
  stored_path TEXT,
  stored_path_purged_at TIMESTAMPTZ,
  byte_size INT,
  page_count INT,
  certificate_date DATE,
  certificate_holder TEXT,
  holder_match BOOLEAN,
  holder_matched_entity TEXT,
  extraction_confidence TEXT,
  confidence_reason TEXT,
  extraction_method TEXT,
  model_id TEXT,
  input_tokens INT,
  output_tokens INT,
  latency_ms INT,
  raw_extraction JSONB,
  validation_flags JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL,
  status_set_by TEXT NOT NULL DEFAULT 'system',
  status_note TEXT,
  status_set_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  cancellation_notice_wording TEXT,
  description_of_operations TEXT,
  superseded_by INT REFERENCES certificates(id),
  coverage_gap_days INT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_cert_status CHECK (status IN
    ('ON_FILE','NEEDS_REVIEW','SUPERSEDED','CANCELLED','NON_RENEWED','REJECTED')),
  CONSTRAINT ck_cert_confidence CHECK
    (extraction_confidence IS NULL OR extraction_confidence IN ('HIGH','MEDIUM','LOW'))
);
CREATE UNIQUE INDEX ux_certificates_sha ON certificates (content_sha256);
CREATE INDEX ix_certificates_vendor ON certificates (vendor_id);
CREATE INDEX ix_certificates_status ON certificates (status);
CREATE INDEX ix_certificates_active ON certificates (vendor_id)
  WHERE status IN ('ON_FILE','NEEDS_REVIEW');
COMMENT ON COLUMN certificates.cancellation_notice_wording IS
  'Verbatim document text; it is not a promise of cancellation notice.';

CREATE TABLE coverages (
  id SERIAL PRIMARY KEY,
  certificate_id INT NOT NULL REFERENCES certificates(id) ON DELETE CASCADE,
  coverage_type TEXT NOT NULL,
  insurer_name TEXT,
  naic TEXT,
  policy_number TEXT,
  effective_date DATE,
  expiration_date DATE,
  each_occurrence NUMERIC(14,2),
  general_aggregate NUMERIC(14,2),
  addl_insd_asserted BOOLEAN,
  subr_wvd_asserted BOOLEAN,
  CONSTRAINT ck_coverage_type CHECK
    (coverage_type IN ('GENERAL_LIABILITY','AUTO','UMBRELLA','WORKERS_COMP','OTHER'))
);
CREATE INDEX ix_coverages_cert ON coverages (certificate_id);
CREATE INDEX ix_coverages_exp ON coverages (expiration_date);
COMMENT ON COLUMN coverages.addl_insd_asserted IS
  'A marked form checkbox, not a coverage or endorsement determination.';

CREATE TABLE outreach_log (
  id SERIAL PRIMARY KEY,
  vendor_id INT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  certificate_id INT REFERENCES certificates(id) ON DELETE SET NULL,
  bucket TEXT NOT NULL,
  attempt_number INT NOT NULL DEFAULT 1,
  drafted_subject TEXT,
  drafted_body TEXT,
  recipient TEXT,
  cc TEXT,
  approved BOOLEAN,
  approved_at TIMESTAMPTZ,
  approved_by TEXT,
  sent_at TIMESTAMPTZ,
  send_error TEXT,
  gmail_thread_id TEXT,
  awaiting_reply BOOLEAN NOT NULL DEFAULT false,
  follow_up_due DATE,
  closed_at TIMESTAMPTZ,
  close_reason TEXT,
  escalated BOOLEAN NOT NULL DEFAULT false,
  escalated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_on DATE NOT NULL DEFAULT ((now() AT TIME ZONE 'America/New_York')::date),
  CONSTRAINT ck_outreach_bucket CHECK
    (bucket IN ('NEVER_RECEIVED','EXPIRED','D14','D30','D60','RE_ATTEST')),
  CONSTRAINT ck_outreach_attempt CHECK (attempt_number >= 1)
);
CREATE INDEX ix_outreach_vendor ON outreach_log (vendor_id);
CREATE INDEX ix_outreach_followup ON outreach_log (follow_up_due) WHERE awaiting_reply;
CREATE INDEX ix_outreach_awaiting ON outreach_log (vendor_id, bucket) WHERE awaiting_reply;
CREATE UNIQUE INDEX ux_outreach_daily ON outreach_log (vendor_id, bucket, created_on);

CREATE TABLE dead_letter (
  id SERIAL PRIMARY KEY,
  source TEXT,
  source_ref TEXT,
  original_filename TEXT,
  content_sha256 TEXT,
  reason_code TEXT NOT NULL,
  reason_detail TEXT,
  raw_payload JSONB,
  resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_dl_reason CHECK (reason_code IN
    ('NOT_A_PDF','PDF_ENCRYPTED','PDF_UNREADABLE','EMPTY_ATTACHMENT',
     'NO_ATTACHMENT_TEXT_REPLY','NO_ATTACHMENT_PORTAL_LINK','MODEL_ERROR',
     'MODEL_REFUSED','JSON_PARSE_FAILED','NOT_A_COI','UNKNOWN'))
);
CREATE INDEX ix_dead_letter_open ON dead_letter (created_at) WHERE NOT resolved;
