$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

$sql = @"
WITH expected_tables(table_name) AS (
  VALUES
    ('vendors'),
    ('certificates'),
    ('coverages'),
    ('outreach_log'),
    ('client_config'),
    ('holder_entities'),
    ('trade_requirements')
),
actual_tables AS (
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
),
checks AS (
  SELECT
    'seven project tables exist' AS check_name,
    count(*) = 7 AS passed,
    count(*)::text AS detail
  FROM expected_tables e
  JOIN actual_tables a USING (table_name)

  UNION ALL

  SELECT
    'client config keys exist',
    count(*) = 10,
    count(*)::text
  FROM client_config
  WHERE key IN (
    'min_each_occurrence',
    'min_general_aggregate',
    'from_mailbox',
    'reminder_days',
    'reattest_days',
    'approval_channel',
    'telegram_chat_id',
    'timezone',
    'model_id',
    'model_id_fallback'
  )

  UNION ALL

  SELECT
    'model defaults are correct',
    bool_and((key = 'model_id' AND value = 'gpt-5.4-nano') OR (key = 'model_id_fallback' AND value = 'gpt-5.6-luna')),
    string_agg(key || '=' || value, ', ' ORDER BY key)
  FROM client_config
  WHERE key IN ('model_id', 'model_id_fallback')

  UNION ALL

  SELECT
    'one primary holder exists',
    count(*) = 1,
    count(*)::text
  FROM holder_entities
  WHERE is_primary = true

  UNION ALL

  SELECT
    'trade fallback resolves',
    min_each_occurrence = 1000000 AND min_general_aggregate = 2000000,
    trade || ':' || min_each_occurrence::text || '/' || min_general_aggregate::text
  FROM trade_requirements
  WHERE trade = 'DEFAULT'

  UNION ALL

  SELECT
    'specific trade requirements exist',
    count(*) = 3,
    count(*)::text
  FROM trade_requirements
  WHERE trade IN ('DEFAULT', 'Roofing', 'Landscaping')

  UNION ALL

  SELECT
    'eighteen vendors exist',
    count(*) = 18,
    count(*)::text
  FROM vendors

  UNION ALL

  SELECT
    'vendor normalization deterministic',
    count(*) = 0,
    count(*)::text
  FROM vendors
  WHERE normalised_name <> normalize_vendor_name(legal_name)

  UNION ALL

  SELECT
    'vendor normalized names unique',
    count(*) = count(DISTINCT normalised_name),
    count(*)::text || '/' || count(DISTINCT normalised_name)::text
  FROM vendors

  UNION ALL

  SELECT
    'at least one wc exempt vendor',
    count(*) >= 1,
    count(*)::text
  FROM vendors
  WHERE wc_exempt = true

  UNION ALL

  SELECT
    'certificate tables are empty',
    ((SELECT count(*) FROM certificates) = 0 AND (SELECT count(*) FROM coverages) = 0 AND (SELECT count(*) FROM outreach_log) = 0),
    'certificates=' || (SELECT count(*) FROM certificates)::text ||
      ', coverages=' || (SELECT count(*) FROM coverages)::text ||
      ', outreach_log=' || (SELECT count(*) FROM outreach_log)::text
)
SELECT check_name, passed, detail
FROM checks
ORDER BY check_name;
"@

Push-Location $repoRoot
try {
  $output = $sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -F "`t" -A
  $output

  if ($output -match "`tf`t") {
    throw "Stage 2 verification failed. See failed checks above."
  }

  Write-Host "Stage 2 verification complete."
}
finally {
  Pop-Location
}
