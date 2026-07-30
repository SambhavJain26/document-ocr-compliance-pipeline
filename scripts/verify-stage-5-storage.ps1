$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Stage5Sql {
  param([string]$Sql)
  $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -F "`t" -A
}

Push-Location $repoRoot
try {
  & .\scripts\apply-stage-5.ps1 | Out-Host

  Invoke-Stage5Sql "TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY;" | Out-Null

  $callsSql = @'
SELECT store_stage_5_intake_result(jsonb_build_object(
  'fixture_id', 'storage-f01',
  'disposition', 'store_on_file',
  'status', 'ON_FILE',
  'extraction_method', 'text',
  'vendor_match', jsonb_build_object('match_type', 'exact', 'score', 1, 'vendor_id', (SELECT id FROM vendors WHERE normalised_name = normalize_vendor_name('Apex Plumbing Services LLC')), 'vendor_legal_name', 'Apex Plumbing Services LLC'),
  'holder_match', jsonb_build_object('matched', true, 'best_match', 'Harbourline Property Management LLC', 'score', 1),
  'validation_flags', '[]'::jsonb,
  'certificate', jsonb_build_object(
    'source', 'form',
    'source_ref', 'storage-f01',
    'original_filename', 'f01-clean-current.pdf',
    'stored_path', '/home/node/.n8n-files/certificates/2026/07/30/storage-f01-f01-clean-current.pdf',
    'certificate_date', '2026-07-30',
    'certificate_holder', 'Harbourline Property Management LLC',
    'holder_match', true,
    'extraction_confidence', 'HIGH',
    'extraction_method', 'text',
    'raw_extraction', jsonb_build_object('vendor_legal_name', 'Apex Plumbing Services LLC'),
    'validation_flags', '[]'::jsonb,
    'status', 'ON_FILE',
    'cancellation_notice_wording', NULL
  ),
  'coverages', jsonb_build_array(jsonb_build_object(
    'coverage_type', 'GENERAL_LIABILITY',
    'insurer_name', 'Northgate Mutual',
    'policy_number', 'NMG-1001-GL',
    'effective_date', '2026-07-01',
    'expiration_date', '2027-03-30',
    'each_occurrence', 1000000,
    'general_aggregate', 2000000,
    'addl_insd_asserted', true,
    'subr_wvd_asserted', false
  )),
  'raw_extraction', jsonb_build_object('vendor_legal_name', 'Apex Plumbing Services LLC')
));

SELECT store_stage_5_intake_result(jsonb_build_object(
  'fixture_id', 'storage-f01',
  'disposition', 'store_on_file',
  'status', 'ON_FILE',
  'certificate', jsonb_build_object('source', 'form', 'source_ref', 'storage-f01', 'original_filename', 'f01-clean-current.pdf'),
  'coverages', '[]'::jsonb
));

SELECT store_stage_5_intake_result(jsonb_build_object(
  'fixture_id', 'storage-review',
  'disposition', 'store_needs_review',
  'status', 'NEEDS_REVIEW',
  'extraction_method', 'text',
  'vendor_match', jsonb_build_object('match_type', 'none', 'score', 0),
  'validation_flags', jsonb_build_array(jsonb_build_object('code', 'MODEL_OUTPUT_INVALID', 'severity', 'hard', 'message', 'invalid', 'details', '{}'::jsonb)),
  'certificate', jsonb_build_object(
    'source', 'form',
    'source_ref', 'storage-review',
    'original_filename', 'review.pdf',
    'stored_path', '/home/node/.n8n-files/certificates/2026/07/30/storage-review-review.pdf',
    'certificate_date', '2026-07-30',
    'certificate_holder', 'Harbourline Property Management LLC',
    'holder_match', true,
    'extraction_confidence', 'LOW',
    'extraction_method', 'text',
    'raw_extraction', jsonb_build_object('vendor_legal_name', 'Unknown Vendor LLC'),
    'validation_flags', jsonb_build_array(jsonb_build_object('code', 'MODEL_OUTPUT_INVALID', 'severity', 'hard', 'message', 'invalid', 'details', '{}'::jsonb)),
    'status', 'NEEDS_REVIEW',
    'cancellation_notice_wording', NULL
  ),
  'coverages', '[]'::jsonb,
  'raw_extraction', jsonb_build_object('vendor_legal_name', 'Unknown Vendor LLC')
));

SELECT store_stage_5_intake_result(jsonb_build_object(
  'fixture_id', 'storage-not-coi',
  'disposition', 'ignore_not_certificate',
  'status', NULL,
  'validation_flags', jsonb_build_array(jsonb_build_object('code', 'NOT_A_COI', 'severity', 'hard', 'message', 'not a certificate', 'details', '{}'::jsonb)),
  'certificate', jsonb_build_object('source', 'form', 'source_ref', 'storage-not-coi', 'original_filename', 'not.pdf', 'stored_path', '/home/node/.n8n-files/certificates/2026/07/30/storage-not-coi-not.pdf'),
  'coverages', '[]'::jsonb,
  'raw_extraction', NULL
));

SELECT store_stage_5_intake_result(jsonb_build_object(
  'fixture_id', 'storage-older',
  'disposition', 'store_on_file',
  'status', 'ON_FILE',
  'extraction_method', 'text',
  'vendor_match', jsonb_build_object('match_type', 'exact', 'score', 1, 'vendor_id', (SELECT id FROM vendors WHERE normalised_name = normalize_vendor_name('Apex Plumbing Services LLC')), 'vendor_legal_name', 'Apex Plumbing Services LLC'),
  'validation_flags', '[]'::jsonb,
  'certificate', jsonb_build_object(
    'source', 'form',
    'source_ref', 'storage-older',
    'original_filename', 'older.pdf',
    'stored_path', '/home/node/.n8n-files/certificates/2026/07/30/storage-older-older.pdf',
    'certificate_date', '2026-01-01',
    'certificate_holder', 'Harbourline Property Management LLC',
    'holder_match', true,
    'extraction_confidence', 'HIGH',
    'extraction_method', 'text',
    'raw_extraction', jsonb_build_object('vendor_legal_name', 'Apex Plumbing Services LLC'),
    'validation_flags', '[]'::jsonb,
    'status', 'ON_FILE'
  ),
  'coverages', '[]'::jsonb,
  'raw_extraction', jsonb_build_object('vendor_legal_name', 'Apex Plumbing Services LLC')
));

SELECT store_stage_5_intake_result(jsonb_build_object(
  'fixture_id', 'storage-unknown',
  'disposition', 'store_on_file',
  'status', 'ON_FILE',
  'extraction_method', 'text',
  'vendor_match', jsonb_build_object('match_type', 'none', 'score', 0),
  'validation_flags', '[]'::jsonb,
  'certificate', jsonb_build_object(
    'source', 'form',
    'source_ref', 'storage-unknown',
    'original_filename', 'unknown.pdf',
    'stored_path', '/home/node/.n8n-files/certificates/2026/07/30/storage-unknown-unknown.pdf',
    'certificate_date', '2026-07-30',
    'certificate_holder', 'Harbourline Property Management LLC',
    'holder_match', true,
    'extraction_confidence', 'HIGH',
    'extraction_method', 'text',
    'raw_extraction', jsonb_build_object('vendor_legal_name', 'Unknown Vendor LLC'),
    'validation_flags', '[]'::jsonb,
    'status', 'ON_FILE'
  ),
  'coverages', '[]'::jsonb,
  'raw_extraction', jsonb_build_object('vendor_legal_name', 'Unknown Vendor LLC')
));
'@

  Invoke-Stage5Sql $callsSql | Out-Host

  $checkSql = @'
WITH checks AS (
  SELECT 'clean insert created on file certificate' AS check_name,
    count(*) = 1 AS passed,
    count(*)::text AS detail
  FROM certificates
  WHERE source_ref = 'storage-f01' AND status = 'ON_FILE'

  UNION ALL

  SELECT 'clean insert created coverage row',
    count(*) = 1,
    count(*)::text
  FROM coverages cv
  JOIN certificates c ON c.id = cv.certificate_id
  WHERE c.source_ref = 'storage-f01'
    AND cv.coverage_type = 'GENERAL_LIABILITY'
    AND cv.each_occurrence = 1000000

  UNION ALL

  SELECT 'duplicate source ref skipped',
    count(*) = 1,
    count(*)::text
  FROM certificates
  WHERE source_ref = 'storage-f01'

  UNION ALL

  SELECT 'needs review preserved',
    count(*) = 1,
    count(*)::text
  FROM certificates
  WHERE source_ref = 'storage-review'
    AND status = 'NEEDS_REVIEW'
    AND vendor_id IS NULL
    AND validation_flags @> '[{"code":"MODEL_OUTPUT_INVALID"}]'::jsonb

  UNION ALL

  SELECT 'non certificate created notice only',
    ((SELECT count(*) FROM intake_notices WHERE source_ref = 'storage-not-coi' AND notice_code = 'NOT_A_COI') = 1
      AND (SELECT count(*) FROM certificates WHERE source_ref = 'storage-not-coi') = 0),
    'notices=' || (SELECT count(*) FROM intake_notices WHERE source_ref = 'storage-not-coi')::text ||
      ', certificates=' || (SELECT count(*) FROM certificates WHERE source_ref = 'storage-not-coi')::text

  UNION ALL

  SELECT 'older than current created notice',
    ((SELECT count(*) FROM intake_notices WHERE source_ref = 'storage-older' AND notice_code = 'OLDER_THAN_ON_FILE') = 1
      AND (SELECT count(*) FROM certificates WHERE source_ref = 'storage-older') = 0),
    'notices=' || (SELECT count(*) FROM intake_notices WHERE source_ref = 'storage-older')::text ||
      ', certificates=' || (SELECT count(*) FROM certificates WHERE source_ref = 'storage-older')::text

  UNION ALL

  SELECT 'unknown vendor downgraded to review',
    count(*) = 1,
    count(*)::text
  FROM certificates
  WHERE source_ref = 'storage-unknown'
    AND status = 'NEEDS_REVIEW'
    AND vendor_id IS NULL
    AND validation_flags @> '[{"code":"VENDOR_NOT_FOUND"}]'::jsonb

  UNION ALL

  SELECT 'no vendor was created',
    count(*) = 18,
    count(*)::text
  FROM vendors
)
SELECT check_name, passed, detail
FROM checks
ORDER BY check_name;
'@

  $output = Invoke-Stage5Sql $checkSql
  $output

  if ($output -match "`tf`t") {
    throw "Stage 5 storage verification failed. See failed checks above."
  }

  Write-Host "Stage 5 storage verification complete."
}
finally {
  Pop-Location
}
