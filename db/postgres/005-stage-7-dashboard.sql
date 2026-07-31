BEGIN;

INSERT INTO client_config(key, value) VALUES
  ('stage_7_dashboard_as_of_date', '')
ON CONFLICT (key) DO NOTHING;

-- Dropped first because the returned row type changes when dashboard columns
-- are added; CREATE OR REPLACE cannot alter OUT parameters.
DROP FUNCTION IF EXISTS stage_7_dashboard_rows(DATE);

CREATE OR REPLACE FUNCTION stage_7_dashboard_rows(as_of_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
  vendor_id INT,
  vendor_legal_name TEXT,
  trade TEXT,
  certificate_id INT,
  certificate_status TEXT,
  insurer_name TEXT,
  policy_number TEXT,
  gl_each_occurrence NUMERIC,
  expiration_date DATE,
  days_to_expiry INT,
  display_status TEXT,
  display_tone TEXT,
  source_url_path TEXT,
  validation_flags JSONB,
  flag_codes TEXT[],
  coverage_gap_count_marker INT,
  cancellation_notice_wording TEXT,
  status_note TEXT,
  status_set_by TEXT,
  last_chased_at TIMESTAMPTZ,
  chase_follow_up_due DATE,
  chase_count INT,
  chase_paused BOOLEAN,
  display_chase TEXT,
  sort_rank INT
)
LANGUAGE sql
STABLE
AS $$
WITH latest_on_file AS (
  SELECT DISTINCT ON (c.vendor_id)
    c.*
  FROM certificates c
  WHERE c.status = 'ON_FILE'
  ORDER BY c.vendor_id, c.certificate_date DESC NULLS LAST, c.received_at DESC, c.id DESC
),
latest_manual AS (
  SELECT DISTINCT ON (c.vendor_id)
    c.*
  FROM certificates c
  WHERE c.status IN ('CANCELLED', 'NON_RENEWED')
  ORDER BY c.vendor_id, c.received_at DESC, c.id DESC
),
latest_review AS (
  SELECT DISTINCT ON (c.vendor_id)
    c.*
  FROM certificates c
  WHERE c.status = 'NEEDS_REVIEW'
  ORDER BY c.vendor_id, c.certificate_date DESC NULLS LAST, c.received_at DESC, c.id DESC
),
selected_cert AS (
  SELECT
    v.id AS vendor_id,
    CASE
      WHEN lm.id IS NOT NULL THEN lm.id
      WHEN lr.id IS NOT NULL
        AND (
          lo.id IS NULL
          OR coalesce(lr.certificate_date, lr.received_at::DATE, '0001-01-01'::DATE)
             >= coalesce(lo.certificate_date, lo.received_at::DATE, '0001-01-01'::DATE)
        ) THEN lr.id
      ELSE lo.id
    END AS certificate_id
  FROM vendors v
  LEFT JOIN latest_on_file lo ON lo.vendor_id = v.id
  LEFT JOIN latest_manual lm ON lm.vendor_id = v.id
  LEFT JOIN latest_review lr ON lr.vendor_id = v.id
),
outreach_summary AS (
  SELECT
    o.vendor_id,
    max(o.sent_at) AS last_chased_at,
    max(o.follow_up_due) FILTER (WHERE o.sent_at IS NOT NULL) AS chase_follow_up_due,
    count(*) FILTER (WHERE o.sent_at IS NOT NULL)::INT AS chase_count
  FROM outreach_log o
  GROUP BY o.vendor_id
),
chosen AS (
  SELECT
    v.id AS vendor_id,
    v.legal_name AS vendor_legal_name,
    v.trade,
    v.chase_paused,
    c.id AS certificate_id,
    c.status AS certificate_status,
    c.stored_path,
    coalesce(c.validation_flags, '[]'::jsonb) AS validation_flags,
    c.cancellation_notice_wording,
    c.status_note,
    c.status_set_by
  FROM vendors v
  LEFT JOIN selected_cert sc ON sc.vendor_id = v.id
  LEFT JOIN certificates c ON c.id = sc.certificate_id
),
earliest_coverage AS (
  SELECT DISTINCT ON (cv.certificate_id)
    cv.certificate_id,
    cv.insurer_name,
    cv.policy_number,
    cv.expiration_date
  FROM coverages cv
  WHERE cv.expiration_date IS NOT NULL
  ORDER BY cv.certificate_id, cv.expiration_date ASC, cv.id ASC
),
gl_coverage AS (
  SELECT DISTINCT ON (cv.certificate_id)
    cv.certificate_id,
    cv.each_occurrence
  FROM coverages cv
  WHERE cv.coverage_type = 'GENERAL_LIABILITY'
  ORDER BY cv.certificate_id, cv.id ASC
),
flags AS (
  SELECT
    ch.vendor_id,
    coalesce(array_agg(flag.value->>'code' ORDER BY flag.ord) FILTER (WHERE flag.value ? 'code'), ARRAY[]::TEXT[]) AS flag_codes,
    count(*) FILTER (WHERE flag.value->>'code' = 'COVERAGE_GAP')::INT AS coverage_gap_count_marker
  FROM chosen ch
  LEFT JOIN LATERAL jsonb_array_elements(ch.validation_flags) WITH ORDINALITY AS flag(value, ord) ON true
  GROUP BY ch.vendor_id
),
classified AS (
  SELECT
    ch.vendor_id,
    ch.vendor_legal_name,
    ch.trade,
    ch.certificate_id,
    ch.certificate_status,
    ec.insurer_name,
    ec.policy_number,
    gl.each_occurrence AS gl_each_occurrence,
    ec.expiration_date,
    CASE WHEN ec.expiration_date IS NULL THEN NULL ELSE (ec.expiration_date - as_of_date)::INT END AS days_to_expiry,
    ch.stored_path,
    ch.validation_flags,
    f.flag_codes,
    f.coverage_gap_count_marker,
    ch.cancellation_notice_wording,
    ch.status_note,
    ch.status_set_by,
    ch.chase_paused,
    os.last_chased_at,
    os.chase_follow_up_due,
    coalesce(os.chase_count, 0) AS chase_count
  FROM chosen ch
  LEFT JOIN earliest_coverage ec ON ec.certificate_id = ch.certificate_id
  LEFT JOIN gl_coverage gl ON gl.certificate_id = ch.certificate_id
  LEFT JOIN flags f ON f.vendor_id = ch.vendor_id
  LEFT JOIN outreach_summary os ON os.vendor_id = ch.vendor_id
)
SELECT
  c.vendor_id,
  c.vendor_legal_name,
  c.trade,
  c.certificate_id,
  c.certificate_status,
  c.insurer_name,
  c.policy_number,
  c.gl_each_occurrence,
  c.expiration_date,
  c.days_to_expiry,
  CASE
    WHEN c.certificate_id IS NULL THEN 'No certificate on file'
    WHEN c.certificate_status = 'NEEDS_REVIEW' THEN 'Needs review'
    WHEN c.certificate_status IN ('CANCELLED', 'NON_RENEWED') THEN 'Needs review'
    WHEN c.expiration_date IS NULL THEN 'Needs review'
    WHEN c.days_to_expiry < 0 THEN 'Expired ' || abs(c.days_to_expiry)::TEXT || CASE WHEN abs(c.days_to_expiry) = 1 THEN ' day ago' ELSE ' days ago' END
    WHEN c.days_to_expiry <= 30 THEN 'Expires in ' || c.days_to_expiry::TEXT || CASE WHEN c.days_to_expiry = 1 THEN ' day' ELSE ' days' END
    ELSE 'Current until ' || to_char(c.expiration_date, 'FMMon FMDD, YYYY')
  END AS display_status,
  CASE
    WHEN c.certificate_id IS NULL THEN 'none'
    WHEN c.certificate_status IN ('NEEDS_REVIEW', 'CANCELLED', 'NON_RENEWED') THEN 'critical'
    WHEN c.expiration_date IS NULL THEN 'critical'
    WHEN c.days_to_expiry < 0 THEN 'critical'
    WHEN c.days_to_expiry <= 30 THEN 'warning'
    WHEN cardinality(coalesce(c.flag_codes, ARRAY[]::TEXT[])) > 0 THEN 'warning'
    ELSE 'good'
  END AS display_tone,
  CASE
    WHEN c.certificate_id IS NOT NULL AND c.stored_path LIKE '/home/node/.n8n-files/certificates/%'
      THEN '/webhook/stage-5-source-document-webhook/coi-source/' || c.certificate_id::TEXT
    ELSE NULL
  END AS source_url_path,
  c.validation_flags,
  coalesce(c.flag_codes, ARRAY[]::TEXT[]) AS flag_codes,
  coalesce(c.coverage_gap_count_marker, 0) AS coverage_gap_count_marker,
  c.cancellation_notice_wording,
  c.status_note,
  c.status_set_by,
  c.last_chased_at,
  c.chase_follow_up_due,
  c.chase_count,
  c.chase_paused,
  CASE
    WHEN c.chase_paused THEN 'Chasing paused'
    WHEN c.chase_count = 0 OR c.last_chased_at IS NULL THEN 'Not yet chased'
    ELSE
      CASE (as_of_date - c.last_chased_at::DATE)
        WHEN 0 THEN 'Chased today'
        WHEN 1 THEN 'Chased 1 day ago'
        ELSE 'Chased ' || (as_of_date - c.last_chased_at::DATE)::TEXT || ' days ago'
      END
      || CASE WHEN c.chase_count > 1 THEN ' (' || c.chase_count::TEXT || ' requests)' ELSE '' END
      || CASE
           WHEN c.chase_follow_up_due IS NULL THEN ''
           WHEN c.chase_follow_up_due < as_of_date THEN ', follow-up overdue'
           ELSE ', follow-up ' || to_char(c.chase_follow_up_due, 'FMMon FMDD')
         END
  END AS display_chase,
  CASE
    WHEN c.certificate_id IS NULL THEN 1
    WHEN c.certificate_status IN ('NEEDS_REVIEW', 'CANCELLED', 'NON_RENEWED') THEN 2
    WHEN c.expiration_date IS NULL THEN 2
    WHEN c.days_to_expiry < 0 THEN 3
    WHEN c.days_to_expiry <= 30 THEN 4
    WHEN coalesce(c.coverage_gap_count_marker, 0) > 0 THEN 5
    WHEN cardinality(coalesce(c.flag_codes, ARRAY[]::TEXT[])) > 0 THEN 6
    ELSE 7
  END AS sort_rank
FROM classified c
ORDER BY
  CASE
    WHEN c.certificate_id IS NULL THEN 1
    WHEN c.certificate_status IN ('NEEDS_REVIEW', 'CANCELLED', 'NON_RENEWED') THEN 2
    WHEN c.expiration_date IS NULL THEN 2
    WHEN c.days_to_expiry < 0 THEN 3
    WHEN c.days_to_expiry <= 30 THEN 4
    WHEN coalesce(c.coverage_gap_count_marker, 0) > 0 THEN 5
    WHEN cardinality(coalesce(c.flag_codes, ARRAY[]::TEXT[])) > 0 THEN 6
    ELSE 7
  END,
  c.days_to_expiry NULLS FIRST,
  c.vendor_legal_name;
$$;

COMMIT;
