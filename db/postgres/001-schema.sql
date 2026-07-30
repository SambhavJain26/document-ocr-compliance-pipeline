BEGIN;

CREATE OR REPLACE FUNCTION normalize_vendor_name(input_text TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
RETURNS NULL ON NULL INPUT
AS $$
  SELECT trim(both '-' from regexp_replace(lower(input_text), '[^a-z0-9]+', '-', 'g'));
$$;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION set_vendor_normalised_name()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.normalised_name = normalize_vendor_name(NEW.legal_name);
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS vendors (
  id                 SERIAL PRIMARY KEY,
  legal_name         TEXT NOT NULL,
  normalised_name    TEXT NOT NULL UNIQUE,
  trade              TEXT,
  wc_exempt          BOOLEAN NOT NULL DEFAULT false,
  chase_paused       BOOLEAN NOT NULL DEFAULT false,
  last_attested_at   DATE,
  contact_email      TEXT,
  producer_name      TEXT,
  producer_email     TEXT,
  producer_phone     TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vendors_legal_name_not_blank CHECK (btrim(legal_name) <> ''),
  CONSTRAINT vendors_normalised_name_not_blank CHECK (btrim(normalised_name) <> '')
);

DROP TRIGGER IF EXISTS vendors_set_normalised_name ON vendors;
CREATE TRIGGER vendors_set_normalised_name
BEFORE INSERT OR UPDATE OF legal_name ON vendors
FOR EACH ROW
EXECUTE FUNCTION set_vendor_normalised_name();

DROP TRIGGER IF EXISTS vendors_set_updated_at ON vendors;
CREATE TRIGGER vendors_set_updated_at
BEFORE UPDATE ON vendors
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS certificates (
  id                           SERIAL PRIMARY KEY,
  vendor_id                    INT REFERENCES vendors(id),
  source                       TEXT,
  source_ref                   TEXT,
  original_filename            TEXT,
  stored_path                  TEXT,
  certificate_date             DATE,
  certificate_holder           TEXT,
  holder_match                 BOOLEAN,
  extraction_confidence        TEXT,
  extraction_method            TEXT,
  raw_extraction               JSONB,
  validation_flags             JSONB NOT NULL DEFAULT '[]'::jsonb,
  status                       TEXT,
  cancellation_notice_wording  TEXT,
  status_set_by                TEXT,
  status_note                  TEXT,
  received_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT certificates_source_check CHECK (source IS NULL OR source IN ('email', 'form')),
  CONSTRAINT certificates_extraction_confidence_check CHECK (extraction_confidence IS NULL OR extraction_confidence IN ('HIGH', 'MEDIUM', 'LOW')),
  CONSTRAINT certificates_extraction_method_check CHECK (extraction_method IS NULL OR extraction_method IN ('text', 'vision')),
  CONSTRAINT certificates_status_check CHECK (status IS NULL OR status IN ('ON_FILE', 'NEEDS_REVIEW', 'SUPERSEDED', 'CANCELLED', 'NON_RENEWED')),
  CONSTRAINT certificates_validation_flags_array CHECK (jsonb_typeof(validation_flags) = 'array')
);

CREATE INDEX IF NOT EXISTS certificates_vendor_id_idx ON certificates(vendor_id);
CREATE INDEX IF NOT EXISTS certificates_status_idx ON certificates(status);

CREATE TABLE IF NOT EXISTS coverages (
  id                    SERIAL PRIMARY KEY,
  certificate_id        INT REFERENCES certificates(id) ON DELETE CASCADE,
  coverage_type         TEXT,
  insurer_name          TEXT,
  naic                  TEXT,
  policy_number         TEXT,
  effective_date        DATE,
  expiration_date       DATE,
  each_occurrence       NUMERIC,
  general_aggregate     NUMERIC,
  addl_insd_asserted    BOOLEAN,
  subr_wvd_asserted     BOOLEAN,
  CONSTRAINT coverages_coverage_type_check CHECK (coverage_type IS NULL OR coverage_type IN ('GENERAL_LIABILITY', 'AUTO', 'UMBRELLA', 'WORKERS_COMP', 'OTHER')),
  CONSTRAINT coverages_each_occurrence_non_negative CHECK (each_occurrence IS NULL OR each_occurrence >= 0),
  CONSTRAINT coverages_general_aggregate_non_negative CHECK (general_aggregate IS NULL OR general_aggregate >= 0)
);

CREATE INDEX IF NOT EXISTS coverages_certificate_id_idx ON coverages(certificate_id);
CREATE INDEX IF NOT EXISTS coverages_expiration_date_idx ON coverages(expiration_date);

CREATE TABLE IF NOT EXISTS outreach_log (
  id              SERIAL PRIMARY KEY,
  vendor_id       INT REFERENCES vendors(id),
  certificate_id  INT REFERENCES certificates(id),
  bucket          TEXT,
  drafted_body    TEXT,
  approved        BOOLEAN,
  approved_at     TIMESTAMPTZ,
  sent_at         TIMESTAMPTZ,
  recipient       TEXT,
  follow_up_due   DATE,
  escalated       BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT outreach_log_bucket_check CHECK (bucket IS NULL OR bucket IN ('NEVER_RECEIVED', 'EXPIRED', '14d', '30d', '60d', 'RE_ATTEST'))
);

CREATE INDEX IF NOT EXISTS outreach_log_vendor_id_idx ON outreach_log(vendor_id);
CREATE INDEX IF NOT EXISTS outreach_log_follow_up_due_idx ON outreach_log(follow_up_due);

CREATE TABLE IF NOT EXISTS client_config (
  key    TEXT PRIMARY KEY,
  value  TEXT,
  CONSTRAINT client_config_key_not_blank CHECK (btrim(key) <> '')
);

CREATE TABLE IF NOT EXISTS holder_entities (
  id           SERIAL PRIMARY KEY,
  legal_name   TEXT NOT NULL UNIQUE,
  is_primary   BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT holder_entities_legal_name_not_blank CHECK (btrim(legal_name) <> '')
);

CREATE UNIQUE INDEX IF NOT EXISTS holder_entities_one_primary_idx
ON holder_entities(is_primary)
WHERE is_primary = true;

CREATE TABLE IF NOT EXISTS trade_requirements (
  trade                  TEXT PRIMARY KEY,
  min_each_occurrence    NUMERIC,
  min_general_aggregate  NUMERIC,
  wc_required            BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT trade_requirements_trade_not_blank CHECK (btrim(trade) <> ''),
  CONSTRAINT trade_requirements_each_occurrence_non_negative CHECK (min_each_occurrence IS NULL OR min_each_occurrence >= 0),
  CONSTRAINT trade_requirements_general_aggregate_non_negative CHECK (min_general_aggregate IS NULL OR min_general_aggregate >= 0)
);

COMMIT;
