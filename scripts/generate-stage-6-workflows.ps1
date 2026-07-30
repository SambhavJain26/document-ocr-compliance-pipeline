$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $PSScriptRoot "generate-stage-6-workflows.js"

if (-not (Test-Path $generator)) {
  throw "Stage 6 workflow generator not found at $generator"
}

Push-Location $repoRoot
try {
  node $generator
}
finally {
  Pop-Location
}
