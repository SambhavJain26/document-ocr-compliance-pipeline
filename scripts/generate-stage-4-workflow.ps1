$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

Push-Location $repoRoot
try {
  node .\scripts\generate-stage-4-workflow.js
}
finally {
  Pop-Location
}
