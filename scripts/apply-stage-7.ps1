$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$stage6Apply = Join-Path $PSScriptRoot "apply-stage-6.ps1"
$stage7Path = Join-Path $repoRoot "db\postgres\005-stage-7-dashboard.sql"

if (-not (Test-Path $stage6Apply)) {
  throw "Stage 6 apply script not found at $stage6Apply"
}

if (-not (Test-Path $stage7Path)) {
  throw "Stage 7 SQL not found at $stage7Path"
}

Push-Location $repoRoot
try {
  & $stage6Apply
  Get-Content -Raw $stage7Path | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -f -
  Write-Host "Stage 7 dashboard schema applied."
}
finally {
  Pop-Location
}
