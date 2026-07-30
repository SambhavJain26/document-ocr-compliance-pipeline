$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Stage6Sql {
  param([string]$Sql)
  $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -F "`t" -A
}

function Invoke-Stage6Scalar {
  param([string]$Sql)
  $result = $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -t -A
  return (($result -join "`n").Trim() -split "`n" | Select-Object -Last 1).Trim()
}

function Assert-Stage6SqlTrue {
  param(
    [string]$Sql,
    [string]$Message
  )

  $result = Invoke-Stage6Scalar $Sql
  if ($result -ne "t") {
    throw "$Message SQL returned '$result'."
  }
}

Push-Location $repoRoot
try {
  & .\scripts\apply-stage-6.ps1 | Out-Host

  $setupSql = @'
TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY;
UPDATE vendors
SET chase_paused = false,
    last_attested_at = NULL;

WITH cert_seed(vendor_name, source_ref, certificate_date, expiration_date, policy_number, carrier) AS (
  VALUES
    ('Apex Plumbing Services LLC', 'stage6-current-reattest', '2026-07-01'::date, '2027-03-30'::date, 'NMG-1001-GL', 'Northgate Mutual'),
    ('Blue Ridge HVAC Co.', 'stage6-30d', '2026-07-30'::date, '2026-08-19'::date, 'CAR-2002-GL', 'Cardinal Casualty'),
    ('Circuit Square Electric LLC', 'stage6-expired', '2025-06-20'::date, '2026-06-26'::date, 'IRN-3003-GL', 'Ironvale Indemnity'),
    ('Greenline Groundskeeping LLC', 'stage6-14d', '2026-07-30'::date, '2026-08-10'::date, 'CAR-6006-GL', 'Cardinal Casualty'),
    ('Clearway Pest Control LLC', 'stage6-60d', '2026-07-30'::date, '2026-09-20'::date, 'IRN-7007-GL', 'Ironvale Indemnity'),
    ('Bright Hall Cleaning Co.', 'stage6-earliest-expiry', '2026-07-30'::date, '2026-12-01'::date, 'NMG-8008-GL', 'Northgate Mutual'),
    ('Prime Coat Painting LLC', 'stage6-paused', '2026-07-30'::date, '2026-08-19'::date, 'CAR-9009-GL', 'Cardinal Casualty'),
    ('Anchor Tile and Flooring LLC', 'stage6-pending', '2026-07-30'::date, '2026-08-19'::date, 'IRN-1009-GL', 'Ironvale Indemnity'),
    ('Harbor Point General Contractors LLC', 'stage6-followup', '2026-07-30'::date, '2026-08-19'::date, 'NMG-1010-GL', 'Northgate Mutual'),
    ('Lockstep Locksmith Services', 'stage6-overdue-one', '2026-07-30'::date, '2026-08-19'::date, 'CAR-1011-GL', 'Cardinal Casualty'),
    ('Evergreen Appliance Repair LLC', 'stage6-escalate', '2026-07-30'::date, '2026-08-19'::date, 'IRN-1012-GL', 'Ironvale Indemnity'),
    ('Mason Creek Handyman', 'stage6-newer-old', '2026-07-01'::date, '2026-08-19'::date, 'NMG-1013-OLD', 'Northgate Mutual')
),
inserted AS (
  INSERT INTO certificates(vendor_id, source, source_ref, original_filename, certificate_date, certificate_holder, holder_match, extraction_confidence, extraction_method, raw_extraction, validation_flags, status)
  SELECT v.id, 'form', s.source_ref, s.source_ref || '.pdf', s.certificate_date, 'Harbourline Property Management LLC', true, 'HIGH', 'text', '{}'::jsonb, '[]'::jsonb, 'ON_FILE'
  FROM cert_seed s
  JOIN vendors v ON v.normalised_name = normalize_vendor_name(s.vendor_name)
  RETURNING id, vendor_id, source_ref
)
INSERT INTO coverages(certificate_id, coverage_type, insurer_name, policy_number, effective_date, expiration_date, each_occurrence, general_aggregate, addl_insd_asserted, subr_wvd_asserted)
SELECT i.id, 'GENERAL_LIABILITY', s.carrier, s.policy_number, s.certificate_date, s.expiration_date, 1000000, 2000000, true, false
FROM inserted i
JOIN cert_seed s ON s.source_ref = i.source_ref;

INSERT INTO coverages(certificate_id, coverage_type, insurer_name, policy_number, effective_date, expiration_date, each_occurrence, general_aggregate, addl_insd_asserted, subr_wvd_asserted)
SELECT c.id, 'AUTO', 'Cardinal Casualty', 'CAR-8008-AU', '2026-03-15', '2026-09-15', 1000000, NULL, false, false
FROM certificates c
WHERE c.source_ref = 'stage6-earliest-expiry';

UPDATE vendors
SET last_attested_at = '2026-03-01'
WHERE normalised_name = normalize_vendor_name('Apex Plumbing Services LLC');

UPDATE vendors
SET chase_paused = true
WHERE normalised_name = normalize_vendor_name('Prime Coat Painting LLC');

INSERT INTO certificates(vendor_id, source, source_ref, original_filename, certificate_date, certificate_holder, holder_match, extraction_confidence, extraction_method, raw_extraction, validation_flags, status, status_set_by, status_note)
SELECT id, 'form', 'stage6-manual-cancelled', 'manual.pdf', '2026-07-30', 'Harbourline Property Management LLC', true, 'HIGH', 'text', '{}'::jsonb, '[]'::jsonb, 'CANCELLED', 'ops@example.test', 'Carrier notice received.'
FROM vendors
WHERE normalised_name = normalize_vendor_name('Vista Glass and Door LLC');

INSERT INTO certificates(vendor_id, source, source_ref, original_filename, certificate_date, certificate_holder, holder_match, extraction_confidence, extraction_method, raw_extraction, validation_flags, status)
SELECT id, 'form', 'stage6-newer-new', 'new.pdf', '2026-08-05', 'Harbourline Property Management LLC', true, 'HIGH', 'text', '{}'::jsonb, '[]'::jsonb, 'ON_FILE'
FROM vendors
WHERE normalised_name = normalize_vendor_name('Mason Creek Handyman');

INSERT INTO coverages(certificate_id, coverage_type, insurer_name, policy_number, effective_date, expiration_date, each_occurrence, general_aggregate, addl_insd_asserted, subr_wvd_asserted)
SELECT id, 'GENERAL_LIABILITY', 'Northgate Mutual', 'NMG-1013-NEW', '2026-08-20', '2027-08-20', 1000000, 2000000, true, false
FROM certificates
WHERE source_ref = 'stage6-newer-new';
'@

  Invoke-Stage6Sql $setupSql | Out-Null

  $suppressionSql = @'
WITH pending AS (
  SELECT *
  FROM stage_6_actionable_vendors('2026-07-30')
  WHERE vendor_legal_name = 'Anchor Tile and Flooring LLC'
),
active_followup AS (
  SELECT *
  FROM stage_6_actionable_vendors('2026-07-30')
  WHERE vendor_legal_name = 'Harbor Point General Contractors LLC'
),
overdue_one AS (
  SELECT *
  FROM stage_6_actionable_vendors('2026-07-30')
  WHERE vendor_legal_name = 'Lockstep Locksmith Services'
),
escalate_two AS (
  SELECT *
  FROM stage_6_actionable_vendors('2026-07-30')
  WHERE vendor_legal_name = 'Evergreen Appliance Repair LLC'
),
newer_old AS (
  SELECT stage_6_vendor_issue_key(
    v.id,
    c.id,
    '30d',
    cv.expiration_date
  ) AS issue_key,
  v.id AS vendor_id,
  c.id AS certificate_id
  FROM vendors v
  JOIN certificates c ON c.vendor_id = v.id AND c.source_ref = 'stage6-newer-old'
  JOIN coverages cv ON cv.certificate_id = c.id AND cv.coverage_type = 'GENERAL_LIABILITY'
  WHERE v.normalised_name = normalize_vendor_name('Mason Creek Handyman')
)
INSERT INTO outreach_log(vendor_id, certificate_id, bucket, issue_key, drafted_subject, drafted_body, recipient, sent_at, follow_up_due)
SELECT vendor_id, certificate_id, bucket, issue_key, 'Pending', 'Pending body', intended_recipient, NULL, NULL FROM pending
UNION ALL
SELECT vendor_id, certificate_id, bucket, issue_key, 'Active', 'Active body', intended_recipient, '2026-07-25'::timestamptz, '2026-08-06'::date FROM active_followup
UNION ALL
SELECT vendor_id, certificate_id, bucket, issue_key, 'Overdue one', 'Overdue body', intended_recipient, '2026-07-01'::timestamptz, '2026-07-10'::date FROM overdue_one
UNION ALL
SELECT vendor_id, certificate_id, bucket, issue_key, 'Esc one', 'Esc body', intended_recipient, '2026-07-01'::timestamptz, '2026-07-10'::date FROM escalate_two
UNION ALL
SELECT vendor_id, certificate_id, bucket, issue_key, 'Esc two', 'Esc body', intended_recipient, '2026-07-12'::timestamptz, '2026-07-20'::date FROM escalate_two
UNION ALL
SELECT vendor_id, certificate_id, '30d', issue_key, 'Old one', 'Old body', 'certs@example.test', '2026-07-01'::timestamptz, '2026-07-10'::date FROM newer_old
UNION ALL
SELECT vendor_id, certificate_id, '30d', issue_key, 'Old two', 'Old body', 'certs@example.test', '2026-07-12'::timestamptz, '2026-07-20'::date FROM newer_old;
'@

  Invoke-Stage6Sql $suppressionSql | Out-Null

  $sideEffectsSql = @'
SELECT stage_6_set_manual_certificate_status(
    (SELECT id FROM certificates WHERE source_ref = 'stage6-60d'),
    'NON_RENEWED',
    'Vendor confirmed non-renewal.',
    'ops@example.test'
  );

SELECT stage_6_store_reply_notice(jsonb_build_object(
    'source', 'email',
    'source_ref', 'stage6-text-reply',
    'from', 'producer@example.test',
    'subject', 'Re: certificate',
    'text', 'We will get this to you next week.'
  ));

SELECT stage_6_store_reply_notice(jsonb_build_object(
    'source', 'email',
    'source_ref', 'stage6-portal-reply',
    'from', 'producer@example.test',
    'subject', 'Certificate portal',
    'text', 'Download it at https://portal.example.test/cert.pdf'
  ));

SELECT * FROM stage_6_escalate_overdue('2026-07-30');
'@

  Invoke-Stage6Sql $sideEffectsSql | Out-Null

  $checksSql = @'
WITH actions AS (
  SELECT * FROM stage_6_actionable_vendors('2026-07-30')
),
post_manual_actions AS (
  SELECT * FROM stage_6_actionable_vendors('2026-07-30')
),
checks AS (
  SELECT 'never received bucket exists' AS check_name,
    EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Oakbend Tree Service LLC' AND bucket = 'NEVER_RECEIVED') AS passed,
    coalesce((SELECT bucket FROM actions WHERE vendor_legal_name = 'Oakbend Tree Service LLC' LIMIT 1), 'missing') AS detail

  UNION ALL
  SELECT 'expired bucket exists',
    EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Circuit Square Electric LLC' AND bucket = 'EXPIRED' AND days_to_expiry = -34),
    coalesce((SELECT bucket || ':' || days_to_expiry::text FROM actions WHERE vendor_legal_name = 'Circuit Square Electric LLC' LIMIT 1), 'missing')

  UNION ALL
  SELECT '14 day bucket exists',
    EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Greenline Groundskeeping LLC' AND bucket = '14d'),
    coalesce((SELECT bucket FROM actions WHERE vendor_legal_name = 'Greenline Groundskeeping LLC' LIMIT 1), 'missing')

  UNION ALL
  SELECT '30 day bucket exists',
    EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Blue Ridge HVAC Co.' AND bucket = '30d'),
    coalesce((SELECT bucket FROM actions WHERE vendor_legal_name = 'Blue Ridge HVAC Co.' LIMIT 1), 'missing')

  UNION ALL
  SELECT '60 day bucket exists',
    EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Bright Hall Cleaning Co.' AND bucket = '60d' AND expiration_date = '2026-09-15'),
    coalesce((SELECT bucket || ':' || expiration_date::text FROM actions WHERE vendor_legal_name = 'Bright Hall Cleaning Co.' LIMIT 1), 'missing')

  UNION ALL
  SELECT 're-attest bucket exists',
    EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Apex Plumbing Services LLC' AND bucket = 'RE_ATTEST'),
    coalesce((SELECT bucket FROM actions WHERE vendor_legal_name = 'Apex Plumbing Services LLC' LIMIT 1), 'missing')

  UNION ALL
  SELECT 'paused vendor suppressed',
    NOT EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Prime Coat Painting LLC'),
    (SELECT count(*)::text FROM actions WHERE vendor_legal_name = 'Prime Coat Painting LLC')

  UNION ALL
  SELECT 'pending approval suppressed',
    NOT EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Anchor Tile and Flooring LLC'),
    (SELECT count(*)::text FROM actions WHERE vendor_legal_name = 'Anchor Tile and Flooring LLC')

  UNION ALL
  SELECT 'active follow-up suppressed',
    NOT EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Harbor Point General Contractors LLC'),
    (SELECT count(*)::text FROM actions WHERE vendor_legal_name = 'Harbor Point General Contractors LLC')

  UNION ALL
  SELECT 'one overdue request remains actionable',
    EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Lockstep Locksmith Services' AND ignored_request_count = 1),
    coalesce((SELECT ignored_request_count::text FROM actions WHERE vendor_legal_name = 'Lockstep Locksmith Services' LIMIT 1), 'missing')

  UNION ALL
  SELECT 'two overdue requests escalated and paused',
    EXISTS (
      SELECT 1
      FROM intake_notices
      WHERE notice_code = 'CHASE_ESCALATED'
        AND details->>'vendor_legal_name' = 'Evergreen Appliance Repair LLC'
    )
      AND (SELECT chase_paused FROM vendors WHERE normalised_name = normalize_vendor_name('Evergreen Appliance Repair LLC')) = true,
    'paused=' || (SELECT chase_paused::text FROM vendors WHERE normalised_name = normalize_vendor_name('Evergreen Appliance Repair LLC'))

  UNION ALL
  SELECT 'newer certificate suppresses stale escalation pause',
    (SELECT chase_paused FROM vendors WHERE normalised_name = normalize_vendor_name('Mason Creek Handyman')) = false,
    'paused=' || (SELECT chase_paused::text FROM vendors WHERE normalised_name = normalize_vendor_name('Mason Creek Handyman'))

  UNION ALL
  SELECT 'manual cancelled status actionable',
    EXISTS (SELECT 1 FROM actions WHERE vendor_legal_name = 'Vista Glass and Door LLC' AND certificate_status = 'CANCELLED' AND bucket = 'EXPIRED'),
    coalesce((SELECT certificate_status || ':' || bucket FROM actions WHERE vendor_legal_name = 'Vista Glass and Door LLC' LIMIT 1), 'missing')

  UNION ALL
  SELECT 'manual non-renewed status actionable',
    EXISTS (SELECT 1 FROM post_manual_actions WHERE vendor_legal_name = 'Clearway Pest Control LLC' AND certificate_status = 'NON_RENEWED' AND bucket = 'EXPIRED'),
    coalesce((SELECT certificate_status || ':' || bucket FROM post_manual_actions WHERE vendor_legal_name = 'Clearway Pest Control LLC' LIMIT 1), 'missing')

  UNION ALL
  SELECT 'text reply notice stored',
    EXISTS (SELECT 1 FROM intake_notices WHERE source_ref = 'stage6-text-reply' AND notice_code = 'TEXT_REPLY_NO_ATTACHMENT'),
    (SELECT count(*)::text FROM intake_notices WHERE source_ref = 'stage6-text-reply')

  UNION ALL
  SELECT 'portal reply notice stored',
    EXISTS (SELECT 1 FROM intake_notices WHERE source_ref = 'stage6-portal-reply' AND notice_code = 'PORTAL_LINK_NO_ATTACHMENT'),
    (SELECT count(*)::text FROM intake_notices WHERE source_ref = 'stage6-portal-reply')
)
SELECT check_name, passed, detail
FROM checks
ORDER BY check_name;
'@

  $output = Invoke-Stage6Sql $checksSql
  $output

  if ($output -match "`tf`t") {
    throw "Stage 6 watch verification failed. See failed checks above."
  }

  Invoke-Stage6Sql "TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY; UPDATE vendors SET chase_paused = false, last_attested_at = NULL;" | Out-Null

  Write-Host "Stage 6 watch/chase deterministic verification complete."
}
finally {
  Pop-Location
}
