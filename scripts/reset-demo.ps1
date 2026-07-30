$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = Split-Path -Parent $PSScriptRoot
$storageRoot = Join-Path $repoRoot "data\certificates"

function Invoke-DemoSql {
  param([string]$Sql)
  $output = $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -F "`t" -A
  if ($LASTEXITCODE -ne 0) {
    throw "Demo reset SQL command failed."
  }
  return $output
}

function Invoke-DemoScalar {
  param([string]$Sql)
  $result = $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -t -A
  if ($LASTEXITCODE -ne 0) {
    throw "Demo reset SQL scalar command failed."
  }
  return (($result -join "`n").Trim() -split "`n" | Select-Object -Last 1).Trim()
}

function Ensure-DemoServices {
  try {
    $services = docker compose ps --services --filter "status=running" 2>$null
  }
  catch {
    throw "Docker is not reachable. Start Docker Desktop and run .\scripts\start-local.ps1 before resetting the demo."
  }

  if ($services -notcontains "postgres") {
    throw "Postgres is not running. Run .\scripts\start-local.ps1 before resetting the demo."
  }
}

function Ensure-Stage7Applied {
  $hasStage7 = "f"
  try {
    $hasStage7 = Invoke-DemoScalar "SELECT to_regprocedure('stage_7_dashboard_rows(date)') IS NOT NULL;"
  }
  catch {
    $hasStage7 = "f"
  }

  if ($hasStage7 -ne "t") {
    Write-Host "Stage 7 dashboard schema is missing; applying through Stage 7 first."
    & (Join-Path $PSScriptRoot "apply-stage-7.ps1") | Out-Host
  }
}

function Ensure-StorageDatePath {
  $datePath = Join-Path $storageRoot ((Get-Date).ToUniversalTime().ToString("yyyy\\MM\\dd"))
  New-Item -ItemType Directory -Force $datePath | Out-Null
  return $datePath
}

Push-Location $repoRoot
try {
  Ensure-DemoServices
  Ensure-Stage7Applied

  Invoke-DemoSql @'
TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY;
UPDATE vendors
SET chase_paused = false,
    last_attested_at = NULL;
UPDATE client_config
SET value = ''
WHERE key IN ('stage_6_watch_as_of_date', 'stage_7_dashboard_as_of_date');
'@ | Out-Null

  $storageDatePath = Ensure-StorageDatePath
  $summary = Invoke-DemoSql @'
SELECT metric, value
FROM (
  VALUES
    ('vendors', (SELECT count(*)::TEXT FROM vendors)),
    ('certificates', (SELECT count(*)::TEXT FROM certificates)),
    ('coverages', (SELECT count(*)::TEXT FROM coverages)),
    ('intake_notices', (SELECT count(*)::TEXT FROM intake_notices)),
    ('outreach_log', (SELECT count(*)::TEXT FROM outreach_log)),
    ('dashboard_rows', (SELECT count(*)::TEXT FROM stage_7_dashboard_rows(CURRENT_DATE))),
    ('no_certificate_dashboard_rows', (SELECT count(*)::TEXT FROM stage_7_dashboard_rows(CURRENT_DATE) WHERE display_status = 'No certificate on file'))
) AS summary(metric, value)
ORDER BY metric;
'@
  $summary | Out-Host
  Write-Host "Demo reset complete. Certificate storage path ready: $storageDatePath"
}
finally {
  Pop-Location
}
