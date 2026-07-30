$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

Push-Location $repoRoot
try {
  node .\scripts\generate-stage-5-workflows.js
}
finally {
  Pop-Location
}
