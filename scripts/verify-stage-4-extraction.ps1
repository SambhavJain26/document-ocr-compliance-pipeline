$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $repoRoot "n8n-workflows\stage-4-extraction-validation-core.json"

function Assert-Stage4Condition {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function ConvertFrom-N8nRawOutput {
  param([string]$Text)

  $first = $Text.IndexOf("{")
  $last = $Text.LastIndexOf("}")
  if ($first -lt 0 -or $last -lt $first) {
    throw "n8n raw execution output did not contain a JSON object."
  }

  return $Text.Substring($first, $last - $first + 1) | ConvertFrom-Json
}

function Get-Stage4FinalResults {
  param($Execution)

  $runData = $Execution.data.resultData.runData
  $nodeRuns = $runData.'Normalize Model Output And Validate'
  if (-not $nodeRuns) {
    throw "Execution did not include the final Stage 4 validation node."
  }

  $results = @()
  foreach ($nodeRun in @($nodeRuns)) {
    foreach ($mainOutput in @($nodeRun.data.main)) {
      foreach ($connectionItems in @($mainOutput)) {
        foreach ($connectionItem in @($connectionItems)) {
          if ($connectionItem.json) {
            $results += $connectionItem.json
          }
        }
      }
    }
  }

  if ($results.Count -eq 0) {
    throw "Final Stage 4 validation node did not emit any JSON results."
  }

  return $results
}

function Get-Stage4ResultById {
  param(
    [array]$Results,
    [string]$FixtureId
  )

  $match = @($Results | Where-Object { $_.fixture_id -eq $FixtureId })
  if ($match.Count -ne 1) {
    throw "Expected exactly one result for $FixtureId, found $($match.Count)."
  }
  return $match[0]
}

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

  $cleanupSql = "DELETE FROM workflow_entity WHERE id = 'stage-4-extraction-validation-core' OR name = 'Extraction and Validation Core';"
  docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -c $cleanupSql | Out-Null

  $workflowJson = Get-Content -Raw $workflowPath
  $importCommand = "tmp=/tmp/stage-4-extraction-validation-core.json; cat > `$tmp; n8n import:workflow --input=`$tmp"
  $workflowJson | docker compose exec -T n8n sh -lc $importCommand | Out-Host

  $workflowId = docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -t -A -c "SELECT id FROM workflow_entity WHERE id = 'stage-4-extraction-validation-core' OR name = 'Extraction and Validation Core' LIMIT 1;"
  $workflowId = $workflowId.Trim()
  if (-not $workflowId) {
    throw "Imported Stage 4 workflow was not found in n8n's workflow table."
  }

  try {
    $executeOutput = docker compose run --rm --no-deps n8n execute --id $workflowId --rawOutput
    $executeText = $executeOutput -join "`n"
    $execution = ConvertFrom-N8nRawOutput -Text $executeText
    Assert-Stage4Condition ($execution.finished -eq $true) "Stage 4 n8n execution did not finish successfully."

    $results = @(Get-Stage4FinalResults -Execution $execution)
    Assert-Stage4Condition ($results.Count -eq 4) "Expected four Stage 4 final results, found $($results.Count)."

    $f01 = Get-Stage4ResultById -Results $results -FixtureId "f01-clean-current"
    $f04 = Get-Stage4ResultById -Results $results -FixtureId "f04-scanned-clean-current"
    $f11 = Get-Stage4ResultById -Results $results -FixtureId "f11-not-a-certificate"
    $f18 = Get-Stage4ResultById -Results $results -FixtureId "f18-password-protected"

    Assert-Stage4Condition ($f01.extraction_method -eq "text") "f01 did not use the text branch."
    Assert-Stage4Condition ($f01.status -eq "ON_FILE") "f01 did not return ON_FILE."
    Assert-Stage4Condition ($f01.vendor_match.match_type -eq "exact") "f01 did not exact-match an existing vendor."
    Assert-Stage4Condition ($f01.certificate.certificate_date -eq "2026-07-30") "f01 certificate date did not match expected fixture date."
    Assert-Stage4Condition ($f01.certificate.certificate_holder -match "Harbourline") "f01 certificate holder did not contain Harbourline."
    $f01Gl = @($f01.coverages | Where-Object { $_.coverage_type -eq "GENERAL_LIABILITY" })[0]
    Assert-Stage4Condition ($null -ne $f01Gl) "f01 did not include a GENERAL_LIABILITY coverage line."
    Assert-Stage4Condition ([int]$f01Gl.each_occurrence -eq 1000000) "f01 GL each-occurrence limit did not match expected value."
    Assert-Stage4Condition ([int]$f01Gl.general_aggregate -eq 2000000) "f01 GL aggregate limit did not match expected value."

    Assert-Stage4Condition ($f04.extraction_method -eq "vision") "f04 did not use the vision branch."
    Assert-Stage4Condition ($f04.status -eq "ON_FILE") "f04 did not return ON_FILE."
    Assert-Stage4Condition (-not @($f04.validation_flags | Where-Object { $_.severity -eq "hard" })) "f04 returned a hard validation flag."
    $f04Gl = @($f04.coverages | Where-Object { $_.coverage_type -eq "GENERAL_LIABILITY" })[0]
    Assert-Stage4Condition ($null -ne $f04Gl) "f04 did not include a GENERAL_LIABILITY coverage line."
    Assert-Stage4Condition ($f04Gl.expiration_date -match "^2027-03-[0-9]{2}$") "f04 GL expiration date was not extracted as a March 2027 date."

    Assert-Stage4Condition ($f11.disposition -eq "ignore_not_certificate") "f11 did not return ignore_not_certificate."
    Assert-Stage4Condition (@($f11.validation_flags | Where-Object { $_.code -eq "NOT_A_COI" }).Count -eq 1) "f11 did not return NOT_A_COI."

    Assert-Stage4Condition ($f18.status -eq "NEEDS_REVIEW") "f18 did not return NEEDS_REVIEW."
    Assert-Stage4Condition (@($f18.validation_flags | Where-Object { $_.code -eq "PDF_PASSWORD_PROTECTED" }).Count -eq 1) "f18 did not return PDF_PASSWORD_PROTECTED."

    $results |
      Select-Object fixture_id, extraction_method, disposition, status |
      Format-Table -AutoSize | Out-String | Write-Host

    Write-Host "Stage 4 live extraction smoke passed."
  }
  finally {
    docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -c $cleanupSql | Out-Null
  }
}
finally {
  Pop-Location
}
