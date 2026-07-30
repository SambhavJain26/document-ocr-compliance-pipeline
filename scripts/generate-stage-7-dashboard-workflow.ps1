$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $PSScriptRoot "generate-stage-7-dashboard-workflow.js"

if (-not (Test-Path $generator)) {
  throw "Stage 7 dashboard workflow generator not found at $generator"
}

Push-Location $repoRoot
try {
  node $generator
}
finally {
  Pop-Location
}
