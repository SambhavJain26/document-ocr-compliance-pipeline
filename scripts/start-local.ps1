$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $repoRoot ".env"

if (-not (Test-Path $envPath)) {
  throw ".env not found. Run scripts/init-env.ps1 first."
}

Push-Location $repoRoot
try {
  docker compose up -d
}
finally {
  Pop-Location
}
