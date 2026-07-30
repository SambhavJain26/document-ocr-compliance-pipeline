$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $repoRoot "db\postgres\001-schema.sql"
$seedPath = Join-Path $repoRoot "db\postgres\002-seed.sql"

if (-not (Test-Path $schemaPath)) {
  throw "Schema SQL not found at $schemaPath"
}

if (-not (Test-Path $seedPath)) {
  throw "Seed SQL not found at $seedPath"
}

Push-Location $repoRoot
try {
  Get-Content -Raw $schemaPath | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -f -
  Get-Content -Raw $seedPath | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -f -
  Write-Host "Stage 2 schema and seed applied."
}
finally {
  Pop-Location
}
