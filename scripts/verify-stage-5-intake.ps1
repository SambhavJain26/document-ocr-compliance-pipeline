$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$intakeWorkflowPath = Join-Path $repoRoot "n8n-workflows\stage-5-intake-workflow.json"
$sourceWorkflowPath = Join-Path $repoRoot "n8n-workflows\stage-5-source-document-route.json"
$storageRoot = Join-Path $repoRoot "data\certificates"

function Assert-Stage5Condition {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-Stage5Sql {
  param([string]$Sql)
  $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -F "`t" -A
}

function Invoke-Stage5Scalar {
  param([string]$Sql)
  $result = $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -t -A
  return (($result -join "`n").Trim() -split "`n" | Select-Object -Last 1).Trim()
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

function Wait-Stage5N8n {
  for ($attempt = 1; $attempt -le 40; $attempt++) {
    try {
      $response = Invoke-WebRequest -Uri "http://localhost:5678" -UseBasicParsing -TimeoutSec 5
      if ($response.StatusCode -eq 200) {
        return
      }
    }
    catch {
      if ($attempt -eq 40) {
        throw
      }
      Start-Sleep -Seconds 3
    }
  }
}

function Ensure-Stage5StorageDatePath {
  $datePath = Join-Path $storageRoot ((Get-Date).ToUniversalTime().ToString("yyyy\\MM\\dd"))
  New-Item -ItemType Directory -Force $datePath | Out-Null
}

function Reset-Stage5Data {
  Invoke-Stage5Sql "TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY;" | Out-Null
}

function Set-Stage5SmokeFixtures {
  param([string]$FixtureSet)
  $safe = $FixtureSet.Replace("'", "''")
  Invoke-Stage5Sql "UPDATE client_config SET value = '$safe' WHERE key = 'stage_5_smoke_fixture_set';" | Out-Null
}

function Import-Stage5Workflow {
  param(
    [string]$Path,
    [string]$WorkflowId,
    [string]$WorkflowName
  )

  $deleteSql = "DELETE FROM workflow_entity WHERE id = '$WorkflowId' OR name = '$WorkflowName';"
  Invoke-Stage5Sql $deleteSql | Out-Null

  $workflowJson = Get-Content -Raw $Path
  $importCommand = "tmp=/tmp/$WorkflowId.json; cat > `$tmp; n8n import:workflow --input=`$tmp"
  $workflowJson | docker compose exec -T n8n sh -lc $importCommand | Out-Host

  $found = Invoke-Stage5Scalar "SELECT id FROM workflow_entity WHERE id = '$WorkflowId' OR name = '$WorkflowName' LIMIT 1;"
  Assert-Stage5Condition ($found -eq $WorkflowId) "Imported workflow $WorkflowName was not found by expected ID."
}

function Invoke-Stage5IntakeSmoke {
  param(
    [string]$WorkflowId,
    [string]$FixtureSet
  )

  Ensure-Stage5StorageDatePath
  Set-Stage5SmokeFixtures $FixtureSet

  $executeOutput = docker compose run --rm --no-deps n8n execute --id $WorkflowId --rawOutput
  $executeText = $executeOutput -join "`n"
  $safeFixtureName = $FixtureSet -replace "[^a-zA-Z0-9._-]+", "-"
  $outputPath = Join-Path $repoRoot "tmp\stage5-intake-$safeFixtureName-output.txt"
  New-Item -ItemType Directory -Force (Split-Path -Parent $outputPath) | Out-Null
  Set-Content -Path $outputPath -Value $executeText -Encoding UTF8

  $execution = ConvertFrom-N8nRawOutput -Text $executeText
  Assert-Stage5Condition ($execution.finished -eq $true) "Stage 5 intake execution for $FixtureSet did not finish successfully. Raw output saved at $outputPath."
}

function Assert-Stage5SqlTrue {
  param(
    [string]$Sql,
    [string]$Message
  )

  $result = Invoke-Stage5Scalar $Sql
  Assert-Stage5Condition ($result -eq "t") "$Message SQL returned '$result'."
}

Push-Location $repoRoot
try {
  & .\scripts\generate-stage-5-workflows.ps1 | Out-Host
  Get-Content -Raw $intakeWorkflowPath | ConvertFrom-Json | Out-Null
  Get-Content -Raw $sourceWorkflowPath | ConvertFrom-Json | Out-Null
  docker compose config --quiet
  Write-Host "Stage 5 workflow JSON and Docker Compose config parse."

  try {
    $services = docker compose ps --services --filter "status=running" 2>$null
  }
  catch {
    Write-Warning "Docker is not reachable. Start Docker Desktop and run .\scripts\start-local.ps1 before live Stage 5 intake verification."
    return
  }

  if (($services -notcontains "n8n") -or ($services -notcontains "postgres")) {
    Write-Warning "n8n and Postgres are not both running. Run .\scripts\start-local.ps1, then rerun this script for live Stage 5 intake verification."
    return
  }

  & .\scripts\apply-stage-5.ps1 | Out-Host
  docker compose up -d n8n | Out-Host
  Wait-Stage5N8n

  $intakeWorkflowId = "stage-5-intake-workflow"
  $sourceWorkflowId = "stage-5-source-document-route"
  $cleanupSql = "DELETE FROM workflow_entity WHERE id IN ('$intakeWorkflowId', '$sourceWorkflowId') OR name IN ('COI Intake', 'Source Document Route');"

  try {
    Invoke-Stage5Sql $cleanupSql | Out-Null
    Import-Stage5Workflow -Path $intakeWorkflowPath -WorkflowId $intakeWorkflowId -WorkflowName "COI Intake"

    Reset-Stage5Data
    Invoke-Stage5IntakeSmoke -WorkflowId $intakeWorkflowId -FixtureSet "f01-clean-current"
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f01-clean-current' AND status = 'ON_FILE' AND vendor_id IS NOT NULL;" "f01 did not store one ON_FILE certificate with exact vendor link."
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM coverages cv JOIN certificates c ON c.id = cv.certificate_id WHERE c.source_ref = 'f01-clean-current' AND cv.coverage_type = 'GENERAL_LIABILITY' AND cv.each_occurrence = 1000000 AND cv.general_aggregate = 2000000;" "f01 GL coverage limits were not stored as expected."
    Assert-Stage5SqlTrue "SELECT count(*) = 0 FROM intake_notices;" "f01 unexpectedly created intake notices."

    Import-Stage5Workflow -Path $sourceWorkflowPath -WorkflowId $sourceWorkflowId -WorkflowName "Source Document Route"
    docker compose run --rm --no-deps n8n update:workflow --id=$sourceWorkflowId --active=true | Out-Host
    docker compose restart n8n | Out-Host
    Wait-Stage5N8n
    $certificateId = Invoke-Stage5Scalar "SELECT id FROM certificates WHERE source_ref = 'f01-clean-current' LIMIT 1;"
    $sourceUrl = "http://localhost:5678/webhook/stage-5-source-document-webhook/coi-source/$certificateId"
    $sourceResponse = Invoke-WebRequest -Uri $sourceUrl -UseBasicParsing -TimeoutSec 20
    $sourcePrefix = if ($sourceResponse.Content -is [byte[]]) {
      [Text.Encoding]::ASCII.GetString($sourceResponse.Content[0..3])
    } else {
      [string]$sourceResponse.Content.Substring(0, [Math]::Min(4, $sourceResponse.Content.Length))
    }
    Assert-Stage5Condition ($sourceResponse.StatusCode -eq 200 -and $sourcePrefix -eq "%PDF") "Stored PDF route did not return PDF bytes."

    Reset-Stage5Data
    Invoke-Stage5IntakeSmoke -WorkflowId $intakeWorkflowId -FixtureSet "f10-two-certificates-email"
    Assert-Stage5SqlTrue "SELECT count(*) = 2 FROM certificates WHERE source_ref LIKE 'f10-two-certificates-email:%';" "f10 did not store two independent certificate rows."

    Reset-Stage5Data
    Invoke-Stage5IntakeSmoke -WorkflowId $intakeWorkflowId -FixtureSet "f02-expiring-20-days"
    Invoke-Stage5IntakeSmoke -WorkflowId $intakeWorkflowId -FixtureSet "f12-renewal-supersede"
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f12-renewal-supersede' AND status = 'ON_FILE';" "f12 renewal was not stored as ON_FILE."
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f02-expiring-20-days' AND status = 'SUPERSEDED';" "f02 was not superseded by f12."

    Reset-Stage5Data
    Invoke-Stage5IntakeSmoke -WorkflowId $intakeWorkflowId -FixtureSet "f12-renewal-supersede"
    Invoke-Stage5IntakeSmoke -WorkflowId $intakeWorkflowId -FixtureSet "f02-expiring-20-days"
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f12-renewal-supersede' AND status = 'ON_FILE';" "f12 did not remain ON_FILE after older upload."
    Assert-Stage5SqlTrue "SELECT count(*) = 0 FROM certificates WHERE source_ref = 'f02-expiring-20-days';" "older f02 upload created a certificate row."
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM intake_notices WHERE source_ref = 'f02-expiring-20-days' AND notice_code = 'OLDER_THAN_ON_FILE';" "older f02 upload did not create OLDER_THAN_ON_FILE notice."

    Reset-Stage5Data
    Invoke-Stage5IntakeSmoke -WorkflowId $intakeWorkflowId -FixtureSet "f03-expired-34-days"
    Invoke-Stage5IntakeSmoke -WorkflowId $intakeWorkflowId -FixtureSet "f13-renewal-coverage-gap"
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f13-renewal-coverage-gap' AND status = 'ON_FILE' AND validation_flags @> '[{""code"":""COVERAGE_GAP""}]'::jsonb;" "f13 renewal did not store with COVERAGE_GAP flag."
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f03-expired-34-days' AND status = 'SUPERSEDED';" "f03 was not superseded by f13."

    Reset-Stage5Data
    Invoke-Stage5IntakeSmoke -WorkflowId $intakeWorkflowId -FixtureSet "f11-not-a-certificate,f18-password-protected,f19-portal-link-email"
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM intake_notices WHERE source_ref = 'f11-not-a-certificate' AND notice_code = 'NOT_A_COI';" "f11 did not create NOT_A_COI notice."
    Assert-Stage5SqlTrue "SELECT count(*) = 0 FROM certificates WHERE source_ref = 'f11-not-a-certificate';" "f11 created a certificate row."
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f18-password-protected' AND status = 'NEEDS_REVIEW' AND validation_flags @> '[{""code"":""PDF_PASSWORD_PROTECTED""}]'::jsonb;" "f18 did not store graceful password-protected review row."
    Assert-Stage5SqlTrue "SELECT count(*) = 1 FROM intake_notices WHERE source_ref = 'f19-portal-link-email:no-pdf' AND notice_code = 'PORTAL_LINK_NO_ATTACHMENT';" "f19 did not create portal-link notice."

    Write-Host "Stage 5 intake workflow smoke passed."
  }
  finally {
    Invoke-Stage5Sql "TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY;" | Out-Null
    Invoke-Stage5Sql $cleanupSql | Out-Null
    docker compose restart n8n | Out-Null
  }
}
finally {
  Pop-Location
}
