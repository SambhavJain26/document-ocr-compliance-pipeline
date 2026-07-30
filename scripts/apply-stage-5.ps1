$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$stage2Apply = Join-Path $PSScriptRoot "apply-stage-2.ps1"
$stage5Path = Join-Path $repoRoot "db\postgres\003-stage-5-intake.sql"
$certificateRoot = Join-Path $repoRoot "data\certificates"
$todayCertificatePath = Join-Path $certificateRoot ((Get-Date).ToUniversalTime().ToString("yyyy\\MM\\dd"))

if (-not (Test-Path $stage2Apply)) {
  throw "Stage 2 apply script not found at $stage2Apply"
}

if (-not (Test-Path $stage5Path)) {
  throw "Stage 5 SQL not found at $stage5Path"
}

Push-Location $repoRoot
try {
  New-Item -ItemType Directory -Force $todayCertificatePath | Out-Null
  & $stage2Apply
  Get-Content -Raw $stage5Path | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -f -
  Write-Host "Stage 5 intake schema applied."
}
finally {
  Pop-Location
}
