$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$dashboardWorkflowPath = Join-Path $repoRoot "n8n-workflows\stage-7-dashboard-demo-view.json"
$sourceWorkflowPath = Join-Path $repoRoot "n8n-workflows\stage-5-source-document-route.json"
$sourceFixturePath = Join-Path $repoRoot "fixtures\pdfs\f01-clean-current.pdf"
$sourceStorageRelative = "2026\07\30\stage7-source-f01.pdf"
$sourceStorageHostPath = Join-Path $repoRoot ("data\certificates\" + $sourceStorageRelative)
$sourceStorageContainerPath = "/home/node/.n8n-files/certificates/2026/07/30/stage7-source-f01.pdf"

function Assert-Stage7Condition {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-Stage7Sql {
  param([string]$Sql)
  $output = $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -F "`t" -A
  if ($LASTEXITCODE -ne 0) {
    throw "Stage 7 SQL command failed."
  }
  return $output
}

function Invoke-Stage7Scalar {
  param([string]$Sql)
  $result = $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -t -A
  if ($LASTEXITCODE -ne 0) {
    throw "Stage 7 SQL scalar command failed."
  }
  return (($result -join "`n").Trim() -split "`n" | Select-Object -Last 1).Trim()
}

function Wait-Stage7N8n {
  for ($attempt = 1; $attempt -le 40; $attempt++) {
    try {
      $response = Invoke-WebRequest -Uri "http://localhost:5678" -UseBasicParsing -TimeoutSec 5
      if ($response.StatusCode -eq 200) {
        return
      }
    }
    catch {
      if ($attempt -eq 40) {
        throw
      }
      Start-Sleep -Seconds 3
    }
  }
}

function Import-Stage7Workflow {
  param(
    [string]$Path,
    [string]$WorkflowId,
    [string]$WorkflowName
  )

  $deleteSql = "DELETE FROM workflow_entity WHERE id = '$WorkflowId' OR name = '$WorkflowName';"
  Invoke-Stage7Sql $deleteSql | Out-Null

  $workflowJson = Get-Content -Raw $Path
  $importCommand = "tmp=/tmp/$WorkflowId.json; cat > `$tmp; n8n import:workflow --input=`$tmp"
  $workflowJson | docker compose exec -T n8n sh -lc $importCommand | Out-Host

  $found = Invoke-Stage7Scalar "SELECT id FROM workflow_entity WHERE id = '$WorkflowId' OR name = '$WorkflowName' LIMIT 1;"
  Assert-Stage7Condition ($found -eq $WorkflowId) "Imported workflow $WorkflowName was not found by expected ID."
}

function Get-Stage7DashboardHtml {
  for ($attempt = 1; $attempt -le 20; $attempt++) {
    try {
      $response = Invoke-WebRequest -Uri "http://localhost:5678/webhook/stage-7-dashboard-webhook/coi" -UseBasicParsing -TimeoutSec 20
      Assert-Stage7Condition ($response.StatusCode -eq 200) "Dashboard webhook did not return HTTP 200."
      return [string]$response.Content
    }
    catch {
      if ($attempt -eq 20) {
        throw
      }
      Start-Sleep -Seconds 2
    }
  }
}

Push-Location $repoRoot
try {
  & .\scripts\generate-stage-7-dashboard-workflow.ps1 | Out-Host
  Get-Content -Raw $dashboardWorkflowPath | ConvertFrom-Json | Out-Null
  Get-Content -Raw $sourceWorkflowPath | ConvertFrom-Json | Out-Null
  docker compose config --quiet
  Write-Host "Stage 7 workflow JSON and Docker Compose config parse."

  try {
    $services = docker compose ps --services --filter "status=running" 2>$null
  }
  catch {
    Write-Warning "Docker is not reachable. Start Docker Desktop and run .\scripts\start-local.ps1 before live Stage 7 dashboard verification."
    return
  }

  if (($services -notcontains "n8n") -or ($services -notcontains "postgres")) {
    Write-Warning "n8n and Postgres are not both running. Run .\scripts\start-local.ps1, then rerun this script for live Stage 7 dashboard verification."
    return
  }

  & .\scripts\apply-stage-7.ps1 | Out-Host
  docker compose up -d n8n | Out-Host
  Wait-Stage7N8n

  $dashboardWorkflowId = "stage-7-dashboard-demo-view"
  $sourceWorkflowId = "stage-5-source-document-route"

  Import-Stage7Workflow -Path $sourceWorkflowPath -WorkflowId $sourceWorkflowId -WorkflowName "Stage 5 - Source Document Route"
  Import-Stage7Workflow -Path $dashboardWorkflowPath -WorkflowId $dashboardWorkflowId -WorkflowName "Stage 7 - Dashboard Demo View"

  docker compose run --rm --no-deps n8n update:workflow --id=$sourceWorkflowId --active=true | Out-Host
  docker compose run --rm --no-deps n8n update:workflow --id=$dashboardWorkflowId --active=true | Out-Host
  docker compose restart n8n | Out-Host
  Wait-Stage7N8n

  Invoke-Stage7Sql @'
TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY;
UPDATE vendors
SET chase_paused = false,
    last_attested_at = NULL;
UPDATE client_config
SET value = '2026-07-30'
WHERE key = 'stage_7_dashboard_as_of_date';
'@ | Out-Null

  Assert-Stage7Condition ((Invoke-Stage7Scalar "SELECT count(*) = 18 FROM stage_7_dashboard_rows('2026-07-30');") -eq "t") "Opening dashboard did not return all 18 vendors."
  Assert-Stage7Condition ((Invoke-Stage7Scalar "SELECT count(*) = 18 FROM stage_7_dashboard_rows('2026-07-30') WHERE display_status = 'No certificate on file' AND display_tone = 'none';") -eq "t") "Opening dashboard did not show 18 no-certificate rows."

  $openingHtml = Get-Stage7DashboardHtml
  Assert-Stage7Condition ($openingHtml -match "No certificate on file") "Opening dashboard HTML did not render no-certificate state."
  Assert-Stage7Condition ($openingHtml -match "18") "Opening dashboard HTML did not render the 18-vendor count."

  New-Item -ItemType Directory -Force (Split-Path -Parent $sourceStorageHostPath) | Out-Null
  Copy-Item -Force $sourceFixturePath $sourceStorageHostPath

  $seedSql = @'
WITH cert_seed(vendor_name, source_ref, certificate_date, expiration_date, policy_number, carrier, status_value, stored_path_value, flags_value, cancellation_notice_value, note_value, set_by_value) AS (
  VALUES
    ('Apex Plumbing Services LLC', 'stage7-current', '2026-07-01'::date, '2027-03-30'::date, 'NMG-7001-GL', 'Northgate Mutual', 'ON_FILE', '__SOURCE_STORAGE_PATH__', '[]'::jsonb, NULL::text, NULL::text, NULL::text),
    ('Blue Ridge HVAC Co.', 'stage7-expiring', '2026-07-30'::date, '2026-08-19'::date, 'CAR-7002-GL', 'Cardinal Casualty', 'ON_FILE', NULL, '[]'::jsonb, NULL::text, NULL::text, NULL::text),
    ('Circuit Square Electric LLC', 'stage7-expired', '2025-06-20'::date, '2026-06-26'::date, 'IRN-7003-GL', 'Ironvale Indemnity', 'ON_FILE', NULL, '[]'::jsonb, NULL::text, NULL::text, NULL::text),
    ('Summit Shield Roofing Inc.', 'stage7-review', '2026-07-30'::date, '2027-07-30'::date, 'NMG-7004-GL', 'Northgate Mutual', 'NEEDS_REVIEW', NULL, '[{"code":"PDF_PASSWORD_PROTECTED","severity":"hard","message":"The PDF is password protected.","details":{}}]'::jsonb, NULL::text, NULL::text, NULL::text),
    ('Greenline Groundskeeping LLC', 'stage7-gap', '2026-07-30'::date, '2027-08-15'::date, 'CAR-7005-GL', 'Cardinal Casualty', 'ON_FILE', NULL, '[{"code":"COVERAGE_GAP","severity":"soft","message":"The replacement general liability policy starts after the prior policy ended.","details":{"gap_days":14}}]'::jsonb, NULL::text, NULL::text, NULL::text),
    ('Oakbend Tree Service LLC', 'stage7-cancelled', '2026-07-30'::date, '2027-07-30'::date, 'IRN-7006-GL', 'Ironvale Indemnity', 'CANCELLED', NULL, '[]'::jsonb, NULL::text, 'Carrier notice received.', 'ops@example.test'),
    ('Rapid Response Restoration LLC', 'stage7-notice-wording', '2026-07-30'::date, '2027-07-30'::date, 'NMG-7007-GL', 'Northgate Mutual', 'ON_FILE', NULL, '[]'::jsonb, 'Thirty days written notice of cancellation will be sent to the certificate holder when required by policy terms.', NULL::text, NULL::text)
),
inserted AS (
  INSERT INTO certificates(vendor_id, source, source_ref, original_filename, stored_path, certificate_date, certificate_holder, holder_match, extraction_confidence, extraction_method, raw_extraction, validation_flags, status, cancellation_notice_wording, status_note, status_set_by)
  SELECT v.id, 'form', s.source_ref, s.source_ref || '.pdf', s.stored_path_value, s.certificate_date, 'Harbourline Property Management LLC', true, 'HIGH', 'text', '{}'::jsonb, s.flags_value, s.status_value, s.cancellation_notice_value, s.note_value, s.set_by_value
  FROM cert_seed s
  JOIN vendors v ON v.normalised_name = normalize_vendor_name(s.vendor_name)
  RETURNING id, source_ref
)
INSERT INTO coverages(certificate_id, coverage_type, insurer_name, policy_number, effective_date, expiration_date, each_occurrence, general_aggregate, addl_insd_asserted, subr_wvd_asserted)
SELECT i.id, 'GENERAL_LIABILITY', s.carrier, s.policy_number, s.certificate_date, s.expiration_date, CASE WHEN s.source_ref = 'stage7-review' THEN 300000 ELSE 1000000 END, 2000000, true, false
FROM inserted i
JOIN cert_seed s ON s.source_ref = i.source_ref;
'@ -replace "__SOURCE_STORAGE_PATH__", $sourceStorageContainerPath

  Invoke-Stage7Sql $seedSql | Out-Null

  $checksSql = @'
WITH rows AS (
  SELECT * FROM stage_7_dashboard_rows('2026-07-30')
),
checks AS (
  SELECT 'all vendors rendered' AS check_name,
    (SELECT count(*) FROM rows) = 18 AS passed,
    (SELECT count(*)::text FROM rows) AS detail

  UNION ALL
  SELECT 'green current row',
    EXISTS (SELECT 1 FROM rows WHERE vendor_legal_name = 'Apex Plumbing Services LLC' AND display_tone = 'good' AND display_status = 'Current until Mar 30, 2027' AND source_url_path IS NOT NULL),
    coalesce((SELECT display_tone || ':' || display_status || ':' || coalesce(source_url_path, 'no-link') FROM rows WHERE vendor_legal_name = 'Apex Plumbing Services LLC'), 'missing')

  UNION ALL
  SELECT 'amber expiring row',
    EXISTS (SELECT 1 FROM rows WHERE vendor_legal_name = 'Blue Ridge HVAC Co.' AND display_tone = 'warning' AND display_status = 'Expires in 20 days'),
    coalesce((SELECT display_tone || ':' || display_status FROM rows WHERE vendor_legal_name = 'Blue Ridge HVAC Co.'), 'missing')

  UNION ALL
  SELECT 'red expired row',
    EXISTS (SELECT 1 FROM rows WHERE vendor_legal_name = 'Circuit Square Electric LLC' AND display_tone = 'critical' AND display_status = 'Expired 34 days ago'),
    coalesce((SELECT display_tone || ':' || display_status FROM rows WHERE vendor_legal_name = 'Circuit Square Electric LLC'), 'missing')

  UNION ALL
  SELECT 'review row',
    EXISTS (SELECT 1 FROM rows WHERE vendor_legal_name = 'Summit Shield Roofing Inc.' AND certificate_status = 'NEEDS_REVIEW' AND display_tone = 'critical' AND flag_codes @> ARRAY['PDF_PASSWORD_PROTECTED']),
    coalesce((SELECT certificate_status || ':' || display_tone || ':' || array_to_string(flag_codes, ',') FROM rows WHERE vendor_legal_name = 'Summit Shield Roofing Inc.'), 'missing')

  UNION ALL
  SELECT 'coverage gap count marker',
    EXISTS (SELECT 1 FROM rows WHERE vendor_legal_name = 'Greenline Groundskeeping LLC' AND display_tone = 'warning' AND coverage_gap_count_marker = 1 AND flag_codes @> ARRAY['COVERAGE_GAP']),
    coalesce((SELECT display_tone || ':' || coverage_gap_count_marker::text || ':' || array_to_string(flag_codes, ',') FROM rows WHERE vendor_legal_name = 'Greenline Groundskeeping LLC'), 'missing')

  UNION ALL
  SELECT 'manual cancelled row',
    EXISTS (SELECT 1 FROM rows WHERE vendor_legal_name = 'Oakbend Tree Service LLC' AND certificate_status = 'CANCELLED' AND display_tone = 'critical' AND status_note = 'Carrier notice received.'),
    coalesce((SELECT certificate_status || ':' || display_tone || ':' || coalesce(status_note, 'no-note') FROM rows WHERE vendor_legal_name = 'Oakbend Tree Service LLC'), 'missing')

  UNION ALL
  SELECT 'neutral cancellation notice row',
    EXISTS (SELECT 1 FROM rows WHERE vendor_legal_name = 'Rapid Response Restoration LLC' AND cancellation_notice_wording IS NOT NULL),
    coalesce((SELECT left(cancellation_notice_wording, 20) FROM rows WHERE vendor_legal_name = 'Rapid Response Restoration LLC'), 'missing')

  UNION ALL
  SELECT 'no certificate rows remain',
    (SELECT count(*) FROM rows WHERE display_status = 'No certificate on file' AND display_tone = 'none') = 11,
    (SELECT count(*)::text FROM rows WHERE display_status = 'No certificate on file' AND display_tone = 'none')

  UNION ALL
  SELECT 'coverage gap aggregate count',
    (SELECT sum(coverage_gap_count_marker) FROM rows) = 1,
    coalesce((SELECT sum(coverage_gap_count_marker)::text FROM rows), 'missing')
)
SELECT check_name, passed, detail
FROM checks
ORDER BY check_name;
'@

  $output = Invoke-Stage7Sql $checksSql
  $output
  if ($output -match "`tf`t") {
    throw "Stage 7 SQL verification failed. See failed checks above."
  }

  $html = Get-Stage7DashboardHtml
  $lowerHtml = $html.ToLowerInvariant()
  foreach ($blocked in @("compliant", "verified", "covered", "approved")) {
    Assert-Stage7Condition (-not $lowerHtml.Contains($blocked)) "Dashboard HTML contained forbidden word '$blocked'."
  }

  foreach ($required in @("Vendor Insurance Register", "Apex Plumbing Services LLC", "Expires in 20 days", "Expired 34 days ago", "Needs review", "14-day paperwork gap", "Certificate states cancellation notice wording.", "Carrier notice received.", "Open PDF", "<th scope=""col"">Chase</th>", "Not yet chased")) {
    Assert-Stage7Condition ($html.Contains($required)) "Dashboard HTML did not contain expected text '$required'."
  }

  $certificateId = Invoke-Stage7Scalar "SELECT certificate_id FROM stage_7_dashboard_rows('2026-07-30') WHERE vendor_legal_name = 'Apex Plumbing Services LLC';"
  $sourceUrl = "http://localhost:5678/webhook/stage-5-source-document-webhook/coi-source/$certificateId"
  $sourceResponse = Invoke-WebRequest -Uri $sourceUrl -UseBasicParsing -TimeoutSec 20
  $sourcePrefix = if ($sourceResponse.Content -is [byte[]]) {
    [Text.Encoding]::ASCII.GetString($sourceResponse.Content[0..3])
  }
  else {
    [string]$sourceResponse.Content.Substring(0, [Math]::Min(4, $sourceResponse.Content.Length))
  }
  Assert-Stage7Condition ($sourceResponse.StatusCode -eq 200 -and $sourcePrefix -eq "%PDF") "Stage 7 source PDF link did not return PDF bytes."

  Invoke-Stage7Sql "TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY; UPDATE vendors SET chase_paused = false, last_attested_at = NULL; UPDATE client_config SET value = '' WHERE key = 'stage_7_dashboard_as_of_date';" | Out-Null

  Write-Host "Stage 7 dashboard verification complete."
}
finally {
  Pop-Location
}
