$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$stage5Apply = Join-Path $PSScriptRoot "apply-stage-5.ps1"
$stage6Path = Join-Path $repoRoot "db\postgres\004-stage-6-watch-chase.sql"

if (-not (Test-Path $stage5Apply)) {
  throw "Stage 5 apply script not found at $stage5Apply"
}

if (-not (Test-Path $stage6Path)) {
  throw "Stage 6 SQL not found at $stage6Path"
}

Push-Location $repoRoot
try {
  & $stage5Apply
  Get-Content -Raw $stage6Path | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -f -
  Write-Host "Stage 6 watch/chase schema applied."
}
finally {
  Pop-Location
}
