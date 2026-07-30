BEGIN;

ALTER TABLE outreach_log
  ADD COLUMN IF NOT EXISTS issue_key TEXT,
  ADD COLUMN IF NOT EXISTS drafted_subject TEXT,
  ADD COLUMN IF NOT EXISTS cc_recipient TEXT,
  ADD COLUMN IF NOT EXISTS actual_recipient TEXT,
  ADD COLUMN IF NOT EXISTS approval_channel TEXT,
  ADD COLUMN IF NOT EXISTS send_mode TEXT,
  ADD COLUMN IF NOT EXISTS declined_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approval_response JSONB,
  ADD COLUMN IF NOT EXISTS send_response JSONB,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS escalated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS outreach_log_issue_key_idx ON outreach_log(issue_key);
CREATE INDEX IF NOT EXISTS outreach_log_pending_idx
ON outreach_log(issue_key)
WHERE approved IS NULL AND sent_at IS NULL AND declined_at IS NULL;

CREATE INDEX IF NOT EXISTS outreach_log_escalation_idx
ON outreach_log(issue_key, follow_up_due)
WHERE sent_at IS NOT NULL AND escalated = false;

INSERT INTO client_config(key, value) VALUES
  ('stage_6_follow_up_days', '7'),
  ('stage_6_outbound_test_mode', 'true'),
  ('stage_6_test_recipient_email', ''),
  ('stage_6_approver_email', ''),
  ('stage_6_copy_vendor', 'true'),
  ('stage_6_watch_as_of_date', '')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION stage_6_config_value(config_key TEXT, default_value TEXT DEFAULT NULL)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce((SELECT value FROM client_config WHERE key = config_key), default_value);
$$;

CREATE OR REPLACE FUNCTION stage_6_bool(value TEXT, default_value BOOLEAN DEFAULT false)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN value IS NULL THEN default_value
    WHEN lower(btrim(value)) IN ('true', 't', 'yes', 'y', '1', 'on') THEN true
    WHEN lower(btrim(value)) IN ('false', 'f', 'no', 'n', '0', 'off') THEN false
    ELSE default_value
  END;
$$;

CREATE OR REPLACE FUNCTION stage_6_parse_int(value TEXT, default_value INT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN value ~ '^\d+$' THEN value::INT ELSE default_value END;
$$;

CREATE OR REPLACE FUNCTION stage_6_parse_date(value TEXT, default_value DATE)
RETURNS DATE
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN value ~ '^\d{4}-\d{2}-\d{2}$' THEN value::DATE ELSE default_value END;
$$;

CREATE OR REPLACE FUNCTION stage_6_vendor_issue_key(
  vendor_id_value INT,
  certificate_id_value INT,
  bucket_value TEXT,
  expiration_date_value DATE
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT concat_ws(
    ':',
    'vendor',
    vendor_id_value::TEXT,
    coalesce(bucket_value, 'none'),
    coalesce(certificate_id_value::TEXT, 'no-cert'),
    coalesce(expiration_date_value::TEXT, 'no-expiry')
  );
$$;

CREATE OR REPLACE FUNCTION stage_6_actionable_vendors(as_of_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
  vendor_id INT,
  vendor_legal_name TEXT,
  trade TEXT,
  contact_email TEXT,
  producer_name TEXT,
  producer_email TEXT,
  certificate_id INT,
  certificate_status TEXT,
  policy_number TEXT,
  insurer_name TEXT,
  coverage_type TEXT,
  expiration_date DATE,
  days_to_expiry INT,
  bucket TEXT,
  issue_key TEXT,
  intended_recipient TEXT,
  cc_recipient TEXT,
  actual_recipient TEXT,
  approver_email TEXT,
  approval_channel TEXT,
  send_mode TEXT,
  model_id TEXT,
  follow_up_days INT,
  ignored_request_count INT,
  last_sent_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
WITH config AS (
  SELECT
    stage_6_parse_int(stage_6_config_value('reattest_days', '90'), 90) AS reattest_days,
    stage_6_parse_int(stage_6_config_value('stage_6_follow_up_days', '7'), 7) AS follow_up_days,
    stage_6_bool(stage_6_config_value('stage_6_copy_vendor', 'true'), true) AS copy_vendor,
    stage_6_bool(stage_6_config_value('stage_6_outbound_test_mode', 'true'), true) AS test_mode,
    nullif(stage_6_config_value('stage_6_test_recipient_email', ''), '') AS test_recipient_email,
    nullif(stage_6_config_value('stage_6_approver_email', ''), '') AS approver_email,
    coalesce(nullif(stage_6_config_value('approval_channel', 'email'), ''), 'email') AS approval_channel,
    stage_6_config_value('model_id', 'gpt-5.4-nano') AS model_id
),
current_cert AS (
  SELECT DISTINCT ON (c.vendor_id)
    c.*
  FROM certificates c
  WHERE c.status = 'ON_FILE'
  ORDER BY c.vendor_id, c.certificate_date DESC NULLS LAST, c.received_at DESC, c.id DESC
),
manual_cert AS (
  SELECT DISTINCT ON (c.vendor_id)
    c.*
  FROM certificates c
  WHERE c.status IN ('CANCELLED', 'NON_RENEWED')
  ORDER BY c.vendor_id, c.received_at DESC, c.id DESC
),
earliest_coverage AS (
  SELECT DISTINCT ON (cv.certificate_id)
    cv.*
  FROM coverages cv
  WHERE cv.expiration_date IS NOT NULL
  ORDER BY cv.certificate_id, cv.expiration_date ASC, cv.id ASC
),
classified AS (
  SELECT
    v.id AS vendor_id,
    v.legal_name AS vendor_legal_name,
    v.trade,
    v.contact_email,
    v.producer_name,
    v.producer_email,
    coalesce(mc.id, cc.id) AS certificate_id,
    coalesce(mc.status, cc.status) AS certificate_status,
    ec.policy_number,
    ec.insurer_name,
    ec.coverage_type,
    ec.expiration_date,
    CASE WHEN ec.expiration_date IS NULL THEN NULL ELSE (ec.expiration_date - as_of_date)::INT END AS days_to_expiry,
    CASE
      WHEN v.chase_paused THEN 'none'
      WHEN mc.status IN ('CANCELLED', 'NON_RENEWED') THEN 'EXPIRED'
      WHEN cc.id IS NULL THEN 'NEVER_RECEIVED'
      WHEN ec.expiration_date IS NULL THEN 'none'
      WHEN ec.expiration_date < as_of_date THEN 'EXPIRED'
      WHEN (ec.expiration_date - as_of_date) <= 14 THEN '14d'
      WHEN (ec.expiration_date - as_of_date) <= 30 THEN '30d'
      WHEN (ec.expiration_date - as_of_date) <= 60 THEN '60d'
      WHEN (v.last_attested_at IS NULL OR as_of_date - v.last_attested_at > (SELECT reattest_days FROM config)) THEN 'RE_ATTEST'
      ELSE 'none'
    END AS bucket
  FROM vendors v
  LEFT JOIN current_cert cc ON cc.vendor_id = v.id
  LEFT JOIN manual_cert mc ON mc.vendor_id = v.id
  LEFT JOIN earliest_coverage ec ON ec.certificate_id = cc.id
),
keyed AS (
  SELECT
    c.*,
    stage_6_vendor_issue_key(c.vendor_id, c.certificate_id, c.bucket, c.expiration_date) AS issue_key
  FROM classified c
),
suppression AS (
  SELECT
    k.*,
    EXISTS (
      SELECT 1
      FROM outreach_log o
      WHERE o.issue_key = k.issue_key
        AND o.approved IS NULL
        AND o.sent_at IS NULL
        AND o.declined_at IS NULL
    ) AS has_pending_approval,
    EXISTS (
      SELECT 1
      FROM outreach_log o
      WHERE o.issue_key = k.issue_key
        AND o.sent_at IS NOT NULL
        AND o.follow_up_due IS NOT NULL
        AND o.follow_up_due >= as_of_date
    ) AS has_active_follow_up,
    (
      SELECT count(*)::INT
      FROM outreach_log o
      WHERE o.issue_key = k.issue_key
        AND o.sent_at IS NOT NULL
        AND o.follow_up_due IS NOT NULL
        AND o.follow_up_due < as_of_date
        AND o.escalated = false
    ) AS ignored_request_count,
    (
      SELECT max(o.sent_at)
      FROM outreach_log o
      WHERE o.issue_key = k.issue_key
        AND o.sent_at IS NOT NULL
    ) AS last_sent_at
  FROM keyed k
)
SELECT
  s.vendor_id,
  s.vendor_legal_name,
  s.trade,
  s.contact_email,
  s.producer_name,
  s.producer_email,
  s.certificate_id,
  s.certificate_status,
  s.policy_number,
  s.insurer_name,
  s.coverage_type,
  s.expiration_date,
  s.days_to_expiry,
  s.bucket,
  s.issue_key,
  coalesce(nullif(s.producer_email, ''), nullif(s.contact_email, '')) AS intended_recipient,
  CASE WHEN (SELECT copy_vendor FROM config) THEN nullif(s.contact_email, '') ELSE NULL END AS cc_recipient,
  CASE
    WHEN (SELECT test_mode FROM config) THEN (SELECT test_recipient_email FROM config)
    ELSE coalesce(nullif(s.producer_email, ''), nullif(s.contact_email, ''))
  END AS actual_recipient,
  (SELECT approver_email FROM config) AS approver_email,
  (SELECT approval_channel FROM config) AS approval_channel,
  CASE WHEN (SELECT test_mode FROM config) THEN 'test_override' ELSE 'live' END AS send_mode,
  (SELECT model_id FROM config) AS model_id,
  (SELECT follow_up_days FROM config) AS follow_up_days,
  s.ignored_request_count,
  s.last_sent_at
FROM suppression s
WHERE s.bucket <> 'none'
  AND coalesce(nullif(s.producer_email, ''), nullif(s.contact_email, '')) IS NOT NULL
  AND s.has_pending_approval = false
  AND s.has_active_follow_up = false
  AND s.ignored_request_count < 2
ORDER BY
  CASE s.bucket
    WHEN 'NEVER_RECEIVED' THEN 1
    WHEN 'EXPIRED' THEN 2
    WHEN '14d' THEN 3
    WHEN '30d' THEN 4
    WHEN '60d' THEN 5
    WHEN 'RE_ATTEST' THEN 6
    ELSE 7
  END,
  s.days_to_expiry NULLS FIRST,
  s.vendor_legal_name;
$$;

CREATE OR REPLACE FUNCTION stage_6_record_pending_outreach(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  inserted_id INT;
BEGIN
  INSERT INTO outreach_log(
    vendor_id,
    certificate_id,
    bucket,
    issue_key,
    drafted_subject,
    drafted_body,
    recipient,
    cc_recipient,
    actual_recipient,
    approval_channel,
    send_mode,
    approval_response
  )
  VALUES (
    (payload->>'vendor_id')::INT,
    NULLIF(payload->>'certificate_id', '')::INT,
    payload->>'bucket',
    payload->>'issue_key',
    payload->>'drafted_subject',
    payload->>'drafted_body',
    payload->>'intended_recipient',
    NULLIF(payload->>'cc_recipient', ''),
    NULLIF(payload->>'actual_recipient', ''),
    coalesce(NULLIF(payload->>'approval_channel', ''), 'email'),
    coalesce(NULLIF(payload->>'send_mode', ''), 'live'),
    jsonb_build_object('pending_at', now())
  )
  RETURNING id INTO inserted_id;

  RETURN jsonb_build_object('outreach_id', inserted_id, 'status', 'pending_approval');
END;
$$;

CREATE OR REPLACE FUNCTION stage_6_mark_outreach_sent(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  updated_id INT;
  follow_up_days INT := stage_6_parse_int(payload->>'follow_up_days', stage_6_parse_int(stage_6_config_value('stage_6_follow_up_days', '7'), 7));
BEGIN
  UPDATE outreach_log
  SET approved = true,
      approved_at = now(),
      sent_at = now(),
      follow_up_due = (CURRENT_DATE + follow_up_days),
      actual_recipient = coalesce(NULLIF(payload->>'actual_recipient', ''), actual_recipient),
      approval_response = coalesce(payload->'approval_response', '{}'::jsonb),
      send_response = coalesce(payload->'send_response', '{}'::jsonb)
  WHERE id = (payload->>'outreach_id')::INT
  RETURNING id INTO updated_id;

  RETURN jsonb_build_object('outreach_id', updated_id, 'status', 'sent', 'follow_up_days', follow_up_days);
END;
$$;

CREATE OR REPLACE FUNCTION stage_6_mark_outreach_declined(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  updated_id INT;
BEGIN
  UPDATE outreach_log
  SET approved = false,
      declined_at = now(),
      approval_response = coalesce(payload->'approval_response', '{}'::jsonb)
  WHERE id = (payload->>'outreach_id')::INT
  RETURNING id INTO updated_id;

  RETURN jsonb_build_object('outreach_id', updated_id, 'status', 'declined');
END;
$$;

CREATE OR REPLACE FUNCTION stage_6_escalate_overdue(as_of_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
  vendor_id INT,
  vendor_legal_name TEXT,
  issue_key TEXT,
  ignored_request_count INT,
  notice_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
  row_value RECORD;
  inserted_notice_id INT;
BEGIN
  FOR row_value IN
    WITH ignored AS (
      SELECT
        o.issue_key,
        o.vendor_id,
        count(*)::INT AS ignored_count,
        max(o.follow_up_due) AS latest_follow_up_due,
        max(o.certificate_id) AS certificate_id
      FROM outreach_log o
      WHERE o.sent_at IS NOT NULL
        AND o.follow_up_due IS NOT NULL
        AND o.follow_up_due < as_of_date
        AND o.escalated = false
      GROUP BY o.issue_key, o.vendor_id
      HAVING count(*) >= 2
    )
    SELECT
      i.*,
      v.legal_name,
      EXISTS (
        SELECT 1
        FROM certificates newer
        JOIN certificates oldc ON oldc.id = i.certificate_id
        WHERE newer.vendor_id = i.vendor_id
          AND newer.status = 'ON_FILE'
          AND newer.received_at > oldc.received_at
      ) AS newer_certificate_arrived
    FROM ignored i
    JOIN vendors v ON v.id = i.vendor_id
  LOOP
    IF row_value.newer_certificate_arrived THEN
      UPDATE outreach_log
      SET escalated = true,
          escalated_at = now()
      WHERE outreach_log.issue_key = row_value.issue_key
        AND outreach_log.escalated = false;
    ELSE
      INSERT INTO intake_notices(source, source_ref, notice_code, severity, message, details)
      VALUES (
        'email',
        row_value.issue_key || ':stage-6-escalation',
        'CHASE_ESCALATED',
        'hard',
        'Two certificate request emails were ignored; automated chasing is paused for this vendor.',
        jsonb_build_object(
          'vendor_id', row_value.vendor_id,
          'vendor_legal_name', row_value.legal_name,
          'issue_key', row_value.issue_key,
          'ignored_request_count', row_value.ignored_count,
          'latest_follow_up_due', row_value.latest_follow_up_due
        )
      )
      ON CONFLICT DO NOTHING
      RETURNING id INTO inserted_notice_id;

      UPDATE outreach_log
      SET escalated = true,
          escalated_at = now()
      WHERE outreach_log.issue_key = row_value.issue_key
        AND outreach_log.escalated = false;

      UPDATE vendors
      SET chase_paused = true
      WHERE id = row_value.vendor_id;

      vendor_id := row_value.vendor_id;
      vendor_legal_name := row_value.legal_name;
      issue_key := row_value.issue_key;
      ignored_request_count := row_value.ignored_count;
      notice_id := inserted_notice_id;
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION stage_6_store_reply_notice(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  inserted_notice_id INT;
  text_value TEXT := coalesce(payload->>'text', payload->>'body', payload->>'snippet', '');
  has_portal_link BOOLEAN := text_value ~* 'https?://';
  notice_code_value TEXT;
BEGIN
  notice_code_value := CASE WHEN has_portal_link THEN 'PORTAL_LINK_NO_ATTACHMENT' ELSE 'TEXT_REPLY_NO_ATTACHMENT' END;

  INSERT INTO intake_notices(source, source_ref, original_filename, notice_code, severity, message, details, raw_payload)
  VALUES (
    coalesce(NULLIF(payload->>'source', ''), 'email'),
    coalesce(NULLIF(payload->>'source_ref', ''), 'stage-6-reply:' || extract(epoch FROM now())::TEXT),
    NULL,
    notice_code_value,
    'note',
    CASE
      WHEN has_portal_link THEN 'The reply contained a portal link but no PDF attachment.'
      ELSE 'The reply did not include a PDF attachment.'
    END,
    jsonb_build_object(
      'from', payload->>'from',
      'subject', payload->>'subject',
      'snippet', left(text_value, 500)
    ),
    payload
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO inserted_notice_id;

  RETURN jsonb_build_object('notice_id', inserted_notice_id, 'notice_code', notice_code_value);
END;
$$;

CREATE OR REPLACE FUNCTION stage_6_store_config_notice(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  inserted_notice_id INT;
BEGIN
  INSERT INTO intake_notices(source, source_ref, original_filename, notice_code, severity, message, details, raw_payload)
  VALUES (
    coalesce(NULLIF(payload->>'source', ''), 'email'),
    coalesce(NULLIF(payload->>'source_ref', ''), 'stage-6-config:' || extract(epoch FROM now())::TEXT),
    NULLIF(payload->>'original_filename', ''),
    coalesce(NULLIF(payload->>'notice_code', ''), 'STAGE_6_CONFIG_NOTICE'),
    coalesce(NULLIF(payload->>'severity', ''), 'hard'),
    coalesce(NULLIF(payload->>'message', ''), 'Stage 6 could not send because required approval or recipient configuration is missing.'),
    coalesce(payload->'details', '{}'::jsonb),
    payload
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO inserted_notice_id;

  RETURN jsonb_build_object('notice_id', inserted_notice_id, 'notice_code', coalesce(NULLIF(payload->>'notice_code', ''), 'STAGE_6_CONFIG_NOTICE'));
END;
$$;

CREATE OR REPLACE FUNCTION stage_6_set_manual_certificate_status(
  certificate_id_value INT,
  status_value TEXT,
  note_value TEXT,
  set_by_value TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  updated_id INT;
  vendor_id_value INT;
BEGIN
  IF status_value NOT IN ('CANCELLED', 'NON_RENEWED') THEN
    RAISE EXCEPTION 'Stage 6 manual status must be CANCELLED or NON_RENEWED, got %', status_value;
  END IF;

  UPDATE certificates
  SET status = status_value,
      status_note = note_value,
      status_set_by = coalesce(NULLIF(set_by_value, ''), 'manual')
  WHERE id = certificate_id_value
  RETURNING id, vendor_id INTO updated_id, vendor_id_value;

  RETURN jsonb_build_object(
    'certificate_id', updated_id,
    'vendor_id', vendor_id_value,
    'status', status_value,
    'status_set_by', coalesce(NULLIF(set_by_value, ''), 'manual')
  );
END;
$$;

COMMIT;
