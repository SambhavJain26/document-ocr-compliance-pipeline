BEGIN;

CREATE TABLE IF NOT EXISTS intake_notices (
  id                 SERIAL PRIMARY KEY,
  source             TEXT,
  source_ref         TEXT,
  original_filename  TEXT,
  stored_path        TEXT,
  notice_code        TEXT NOT NULL,
  severity           TEXT NOT NULL DEFAULT 'info',
  message            TEXT NOT NULL,
  details            JSONB NOT NULL DEFAULT '{}'::jsonb,
  raw_payload        JSONB,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT intake_notices_source_check CHECK (source IS NULL OR source IN ('email', 'form')),
  CONSTRAINT intake_notices_severity_check CHECK (severity IN ('info', 'note', 'soft', 'hard')),
  CONSTRAINT intake_notices_details_object CHECK (jsonb_typeof(details) = 'object')
);

CREATE INDEX IF NOT EXISTS intake_notices_source_ref_idx ON intake_notices(source_ref);
CREATE INDEX IF NOT EXISTS intake_notices_notice_code_idx ON intake_notices(notice_code);

CREATE UNIQUE INDEX IF NOT EXISTS certificates_source_ref_unique_idx
ON certificates(source_ref)
WHERE source_ref IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS intake_notices_source_ref_unique_idx
ON intake_notices(source_ref)
WHERE source_ref IS NOT NULL;

INSERT INTO client_config(key, value) VALUES
  ('manager_notice_email', ''),
  ('send_manager_notices', 'false'),
  ('stage_5_smoke_fixture_set', 'f01-clean-current')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value;

CREATE OR REPLACE FUNCTION stage_5_parse_date(value TEXT)
RETURNS DATE
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN value ~ '^\d{4}-\d{2}-\d{2}$' THEN value::date
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION stage_5_storage_flag(
  code TEXT,
  severity TEXT,
  message TEXT,
  details JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT jsonb_build_object(
    'code', code,
    'severity', severity,
    'message', message,
    'details', coalesce(details, '{}'::jsonb)
  );
$$;

CREATE OR REPLACE FUNCTION store_stage_5_intake_result(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  disposition TEXT := coalesce(payload->>'disposition', '');
  requested_status TEXT := payload->>'status';
  source_value TEXT := coalesce(payload #>> '{certificate,source}', payload->>'source', 'form');
  source_ref_value TEXT := coalesce(payload #>> '{certificate,source_ref}', payload->>'source_ref', payload->>'fixture_id');
  filename_value TEXT := coalesce(payload #>> '{certificate,original_filename}', payload->>'original_filename');
  stored_path_value TEXT := coalesce(payload #>> '{certificate,stored_path}', payload->>'stored_path');
  vendor_match_type TEXT := payload #>> '{vendor_match,match_type}';
  matched_vendor_id INT;
  effective_vendor_id INT;
  certificate_payload JSONB := coalesce(payload->'certificate', '{}'::jsonb);
  flags JSONB := coalesce(payload->'validation_flags', '[]'::jsonb);
  raw_extraction_payload JSONB := payload->'raw_extraction';
  certificate_date_value DATE := stage_5_parse_date(certificate_payload->>'certificate_date');
  current_certificate RECORD;
  certificate_id_value INT;
  coverage JSONB;
  notice_code TEXT;
  notice_message TEXT;
  notice_severity TEXT := 'info';
  inserted_notice_id INT;
  existing_certificate RECORD;
  existing_notice RECORD;
BEGIN
  IF source_ref_value IS NOT NULL THEN
    SELECT id, vendor_id, status
    INTO existing_certificate
    FROM certificates
    WHERE source_ref = source_ref_value
    LIMIT 1;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'storage_action', 'duplicate_certificate',
        'certificate_id', existing_certificate.id,
        'vendor_id', existing_certificate.vendor_id,
        'status', existing_certificate.status,
        'source_ref', source_ref_value
      );
    END IF;

    SELECT n.id, n.notice_code
    INTO existing_notice
    FROM intake_notices n
    WHERE n.source_ref = source_ref_value
    LIMIT 1;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'storage_action', 'duplicate_notice',
        'notice_id', existing_notice.id,
        'notice_code', existing_notice.notice_code,
        'source_ref', source_ref_value
      );
    END IF;
  END IF;

  IF vendor_match_type = 'exact' AND payload #>> '{vendor_match,vendor_id}' IS NOT NULL THEN
    SELECT id
    INTO matched_vendor_id
    FROM vendors
    WHERE id = (payload #>> '{vendor_match,vendor_id}')::INT;
  END IF;

  effective_vendor_id := matched_vendor_id;

  IF disposition = 'ignore_not_certificate' THEN
    notice_code := 'NOT_A_COI';
    notice_severity := 'hard';
    notice_message := 'The intake item was not a certificate of liability insurance.';
  ELSIF disposition = 'ignore_older_than_on_file' THEN
    notice_code := 'OLDER_THAN_ON_FILE';
    notice_severity := 'hard';
    notice_message := 'The intake item is older than the active certificate already on file.';
  ELSIF disposition IN ('store_on_file', 'store_needs_review') THEN
    IF disposition = 'store_on_file' AND effective_vendor_id IS NULL THEN
      requested_status := 'NEEDS_REVIEW';
      flags := flags || jsonb_build_array(stage_5_storage_flag(
        'VENDOR_NOT_FOUND',
        'hard',
        'No exact seeded vendor match was available, so the certificate was routed to review.',
        jsonb_build_object('vendor_match_type', coalesce(vendor_match_type, 'none'))
      ));
    END IF;

    IF requested_status = 'ON_FILE' AND effective_vendor_id IS NOT NULL AND certificate_date_value IS NOT NULL THEN
      SELECT id, certificate_date
      INTO current_certificate
      FROM certificates
      WHERE vendor_id = effective_vendor_id AND status = 'ON_FILE'
      ORDER BY certificate_date DESC NULLS LAST, received_at DESC, id DESC
      LIMIT 1;

      IF FOUND AND current_certificate.certificate_date IS NOT NULL AND certificate_date_value < current_certificate.certificate_date THEN
        notice_code := 'OLDER_THAN_ON_FILE';
        notice_severity := 'hard';
        notice_message := 'The intake item is older than the active certificate already on file.';

        INSERT INTO intake_notices(source, source_ref, original_filename, stored_path, notice_code, severity, message, details, raw_payload)
        VALUES (
          source_value,
          source_ref_value,
          filename_value,
          stored_path_value,
          notice_code,
          notice_severity,
          notice_message,
          jsonb_build_object(
            'current_certificate_id', current_certificate.id,
            'current_certificate_date', current_certificate.certificate_date,
            'new_certificate_date', certificate_date_value
          ),
          payload
        )
        RETURNING id INTO inserted_notice_id;

        RETURN jsonb_build_object(
          'storage_action', 'notice_inserted',
          'notice_id', inserted_notice_id,
          'notice_code', notice_code,
          'source_ref', source_ref_value
        );
      END IF;
    END IF;

    INSERT INTO certificates(
      vendor_id,
      source,
      source_ref,
      original_filename,
      stored_path,
      certificate_date,
      certificate_holder,
      holder_match,
      extraction_confidence,
      extraction_method,
      raw_extraction,
      validation_flags,
      status,
      cancellation_notice_wording
    )
    VALUES (
      effective_vendor_id,
      source_value,
      source_ref_value,
      filename_value,
      stored_path_value,
      certificate_date_value,
      certificate_payload->>'certificate_holder',
      CASE
        WHEN certificate_payload ? 'holder_match' THEN (certificate_payload->>'holder_match')::BOOLEAN
        ELSE NULL
      END,
      certificate_payload->>'extraction_confidence',
      coalesce(payload->>'extraction_method', certificate_payload->>'extraction_method'),
      raw_extraction_payload,
      flags,
      requested_status,
      certificate_payload->>'cancellation_notice_wording'
    )
    RETURNING id INTO certificate_id_value;

    FOR coverage IN SELECT * FROM jsonb_array_elements(coalesce(payload->'coverages', '[]'::jsonb))
    LOOP
      INSERT INTO coverages(
        certificate_id,
        coverage_type,
        insurer_name,
        naic,
        policy_number,
        effective_date,
        expiration_date,
        each_occurrence,
        general_aggregate,
        addl_insd_asserted,
        subr_wvd_asserted
      )
      VALUES (
        certificate_id_value,
        coverage->>'coverage_type',
        coverage->>'insurer_name',
        coverage->>'naic',
        coverage->>'policy_number',
        stage_5_parse_date(coverage->>'effective_date'),
        stage_5_parse_date(coverage->>'expiration_date'),
        NULLIF(coverage->>'each_occurrence', '')::NUMERIC,
        NULLIF(coverage->>'general_aggregate', '')::NUMERIC,
        CASE WHEN coverage ? 'addl_insd_asserted' THEN (coverage->>'addl_insd_asserted')::BOOLEAN ELSE NULL END,
        CASE WHEN coverage ? 'subr_wvd_asserted' THEN (coverage->>'subr_wvd_asserted')::BOOLEAN ELSE NULL END
      );
    END LOOP;

    IF requested_status = 'ON_FILE' AND effective_vendor_id IS NOT NULL THEN
      UPDATE certificates
      SET status = 'SUPERSEDED',
          status_set_by = 'stage_5_storage',
          status_note = 'Superseded by certificate ' || certificate_id_value::TEXT
      WHERE vendor_id = effective_vendor_id
        AND status = 'ON_FILE'
        AND id <> certificate_id_value;

      -- Filing a current certificate is itself an attestation: the vendor has
      -- just confirmed their coverage details by sending the document. Without
      -- this, last_attested_at stays NULL forever, and the RE_ATTEST branch in
      -- stage_6_actionable_vendors treats NULL as "never confirmed", so every
      -- vendor with perfectly good paperwork stays permanently chase-eligible.
      --
      -- The certificate's own date is used rather than the current date, so an
      -- old-but-still-current certificate does not reset the clock to today.
      -- GREATEST ignores NULLs, so this only ever moves the date forward.
      UPDATE vendors
      SET last_attested_at = GREATEST(last_attested_at, coalesce(certificate_date_value, CURRENT_DATE)),
          updated_at = now()
      WHERE id = effective_vendor_id;
    END IF;

    RETURN jsonb_build_object(
      'storage_action', 'certificate_inserted',
      'certificate_id', certificate_id_value,
      'vendor_id', effective_vendor_id,
      'status', requested_status,
      'source_ref', source_ref_value
    );
  ELSE
    notice_code := coalesce(nullif(disposition, ''), 'INTAKE_NOTICE');
    notice_message := 'The intake item did not produce a storage-ready certificate.';
  END IF;

  INSERT INTO intake_notices(source, source_ref, original_filename, stored_path, notice_code, severity, message, details, raw_payload)
  VALUES (
    source_value,
    source_ref_value,
    filename_value,
    stored_path_value,
    notice_code,
    notice_severity,
    notice_message,
    jsonb_build_object('disposition', disposition, 'validation_flags', flags),
    payload
  )
  RETURNING id INTO inserted_notice_id;

  RETURN jsonb_build_object(
    'storage_action', 'notice_inserted',
    'notice_id', inserted_notice_id,
    'notice_code', notice_code,
    'source_ref', source_ref_value
  );
END;
$$;

-- Backfill for deployments that filed certificates before the attestation
-- update above existed. Those vendors carry a NULL last_attested_at, which the
-- RE_ATTEST branch reads as "never confirmed", so they would keep generating
-- re-attestation reminders despite having current paperwork on file.
-- Idempotent: only advances a vendor whose recorded date is missing or older.
UPDATE vendors v
SET last_attested_at = filed.certificate_date,
    updated_at = now()
FROM (
  SELECT vendor_id, max(certificate_date) AS certificate_date
  FROM certificates
  WHERE status = 'ON_FILE'
    AND vendor_id IS NOT NULL
    AND certificate_date IS NOT NULL
  GROUP BY vendor_id
) AS filed
WHERE filed.vendor_id = v.id
  AND (v.last_attested_at IS NULL OR v.last_attested_at < filed.certificate_date);

COMMIT;
