$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $repoRoot "n8n-workflows\stage-4-extraction-validation-core.json"

Push-Location $repoRoot
try {
  node .\scripts\generate-stage-4-workflow.js
  Get-Content -Raw $workflowPath | ConvertFrom-Json | Out-Null
  Write-Host "Stage 4 workflow JSON parses."

  try {
    $services = docker compose ps --services --filter "status=running" 2>$null
  }
  catch {
    Write-Warning "Docker is not reachable. Start Docker Desktop and run .\scripts\start-local.ps1 before live Stage 4 extraction."
    return
  }

  if (($services -notcontains "n8n") -or ($services -notcontains "postgres")) {
    Write-Warning "n8n and Postgres are not both running. Run .\scripts\start-local.ps1, then rerun this script for live extraction."
    return
  }

  $workflowJson = Get-Content -Raw $workflowPath
  $importCommand = "tmp=/tmp/stage-4-extraction-validation-core.json; cat > `$tmp; n8n import:workflow --input=`$tmp"
  $workflowJson | docker compose exec -T n8n sh -lc $importCommand | Out-Host

  $workflowId = docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -t -A -c "SELECT id FROM workflow_entity WHERE name = 'Stage 4 - COI Extraction and Validation Core' ORDER BY created_at DESC LIMIT 1;"
  $workflowId = $workflowId.Trim()
  if (-not $workflowId) {
    throw "Imported Stage 4 workflow was not found in n8n's workflow table."
  }

  try {
    $executeOutput = docker compose exec -T n8n n8n execute --id $workflowId
    $executeOutput | Out-Host

    foreach ($expected in @("f01-clean-current", "f04-scanned-clean-current", "f11-not-a-certificate", "f18-password-protected")) {
      if ($executeOutput -notmatch [regex]::Escape($expected)) {
        throw "Execution output did not include expected fixture $expected."
      }
    }

    if ($executeOutput -notmatch "store_on_file") {
      throw "Execution output did not include a store_on_file result."
    }

    if ($executeOutput -notmatch "ignore_not_certificate") {
      throw "Execution output did not include ignore_not_certificate."
    }

    Write-Host "Stage 4 live extraction verification complete."
  }
  finally {
    docker compose exec -T n8n n8n delete:workflow --id $workflowId 2>$null | Out-Host
  }
}
finally {
  Pop-Location
}
