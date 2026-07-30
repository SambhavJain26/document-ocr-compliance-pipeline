$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

Push-Location $repoRoot
try {
  node .\scripts\test-stage-4-validation.js
  Write-Host "Stage 4 offline validation verification complete."
}
finally {
  Pop-Location
}
