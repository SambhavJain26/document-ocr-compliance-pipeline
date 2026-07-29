CREATE OR REPLACE VIEW v_today AS
SELECT (now() AT TIME ZONE COALESCE(
  (SELECT value FROM client_config WHERE key = 'timezone'), 'UTC'))::date AS today;

CREATE OR REPLACE VIEW v_current_certificate AS
SELECT DISTINCT ON (c.vendor_id) c.*
FROM certificates c
WHERE c.status IN ('ON_FILE','NEEDS_REVIEW','CANCELLED','NON_RENEWED')
ORDER BY c.vendor_id, c.certificate_date DESC NULLS LAST, c.received_at DESC;

CREATE OR REPLACE VIEW v_certificate_expiry AS
SELECT
  cov.certificate_id,
  MIN(cov.expiration_date) AS earliest_expiration,
  MAX(cov.expiration_date) AS latest_expiration,
  COUNT(*) AS coverage_line_count,
  BOOL_OR(cov.coverage_type = 'GENERAL_LIABILITY') AS has_gl,
  BOOL_OR(cov.coverage_type = 'WORKERS_COMP') AS has_wc,
  MAX(cov.each_occurrence) FILTER (WHERE cov.coverage_type = 'GENERAL_LIABILITY') AS gl_each_occurrence,
  MAX(cov.general_aggregate) FILTER (WHERE cov.coverage_type = 'GENERAL_LIABILITY') AS gl_general_aggregate,
  (ARRAY_AGG(cov.insurer_name ORDER BY cov.expiration_date))[1] AS earliest_insurer,
  (ARRAY_AGG(cov.policy_number ORDER BY cov.expiration_date))[1] AS earliest_policy_number,
  (ARRAY_AGG(cov.coverage_type ORDER BY cov.expiration_date))[1] AS earliest_coverage_type
FROM coverages cov
GROUP BY cov.certificate_id;

CREATE OR REPLACE VIEW v_thresholds AS
SELECT
  (SELECT value::int FROM client_config WHERE key = 'reminder_d14') AS d14,
  (SELECT value::int FROM client_config WHERE key = 'reminder_d30') AS d30,
  (SELECT value::int FROM client_config WHERE key = 'reminder_d60') AS d60,
  (SELECT value::int FROM client_config WHERE key = 'reattest_days') AS reattest;

CREATE OR REPLACE VIEW v_vendor_status AS
WITH t AS (SELECT today FROM v_today), r AS (SELECT * FROM v_thresholds)
SELECT
  v.id AS vendor_id, v.legal_name, COALESCE(v.display_name, v.legal_name) AS display_name,
  v.trade, v.wc_exempt, v.chase_paused, v.producer_email, v.producer_name,
  v.contact_email, v.last_attested_at,
  c.id AS certificate_id, c.status AS certificate_status, c.certificate_date,
  c.certificate_holder, c.holder_match, c.extraction_confidence,
  c.confidence_reason, c.extraction_method, c.validation_flags,
  c.cancellation_notice_wording, c.coverage_gap_days, c.stored_path,
  e.earliest_expiration, e.coverage_line_count, e.has_gl, e.has_wc,
  e.gl_each_occurrence, e.gl_general_aggregate, e.earliest_insurer,
  e.earliest_policy_number, t.today,
  (e.earliest_expiration - t.today) AS days_to_expiry,
  CASE
    WHEN v.chase_paused THEN 'PAUSED'
    WHEN c.id IS NULL THEN 'NEVER_RECEIVED'
    WHEN c.status = 'NEEDS_REVIEW' THEN 'NEEDS_REVIEW'
    WHEN c.status IN ('CANCELLED','NON_RENEWED') THEN 'EXPIRED'
    WHEN e.earliest_expiration IS NULL THEN 'NEEDS_REVIEW'
    WHEN e.earliest_expiration < t.today THEN 'EXPIRED'
    WHEN e.earliest_expiration <= t.today + r.d14 THEN 'D14'
    WHEN e.earliest_expiration <= t.today + r.d30 THEN 'D30'
    WHEN e.earliest_expiration <= t.today + r.d60 THEN 'D60'
    WHEN v.last_attested_at IS NULL OR v.last_attested_at < t.today - r.reattest THEN 'RE_ATTEST'
    ELSE 'CURRENT'
  END AS bucket,
  CASE
    WHEN c.id IS NULL THEN 'grey'
    WHEN c.status = 'NEEDS_REVIEW' THEN 'amber'
    WHEN c.status IN ('CANCELLED','NON_RENEWED') THEN 'red'
    WHEN e.earliest_expiration IS NULL THEN 'amber'
    WHEN e.earliest_expiration < t.today THEN 'red'
    WHEN e.earliest_expiration <= t.today + r.d30 THEN 'amber'
    ELSE 'green'
  END AS colour
FROM vendors v
CROSS JOIN t
CROSS JOIN r
LEFT JOIN v_current_certificate c ON c.vendor_id = v.id
LEFT JOIN v_certificate_expiry e ON e.certificate_id = c.id
WHERE v.active;
