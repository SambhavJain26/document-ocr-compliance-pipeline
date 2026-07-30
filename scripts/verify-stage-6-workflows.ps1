$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$dailyWorkflowPath = Join-Path $repoRoot "n8n-workflows\stage-6-daily-watch-chase.json"
$replyWorkflowPath = Join-Path $repoRoot "n8n-workflows\stage-6-non-pdf-reply-notice.json"

function Assert-Stage6Condition {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-Stage6Sql {
  param([string]$Sql)
  $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -F "`t" -A
}

function Invoke-Stage6Scalar {
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

function Wait-Stage6N8n {
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

function Import-Stage6Workflow {
  param(
    [string]$Path,
    [string]$WorkflowId,
    [string]$WorkflowName
  )

  $deleteSql = "DELETE FROM workflow_entity WHERE id = '$WorkflowId' OR name = '$WorkflowName';"
  Invoke-Stage6Sql $deleteSql | Out-Null

  $workflowJson = Get-Content -Raw $Path
  $importCommand = "tmp=/tmp/$WorkflowId.json; cat > `$tmp; n8n import:workflow --input=`$tmp"
  $workflowJson | docker compose exec -T n8n sh -lc $importCommand | Out-Host

  $found = Invoke-Stage6Scalar "SELECT id FROM workflow_entity WHERE id = '$WorkflowId' OR name = '$WorkflowName' LIMIT 1;"
  Assert-Stage6Condition ($found -eq $WorkflowId) "Imported workflow $WorkflowName was not found by expected ID."
}

Push-Location $repoRoot
try {
  & .\scripts\generate-stage-6-workflows.ps1 | Out-Host
  Get-Content -Raw $dailyWorkflowPath | ConvertFrom-Json | Out-Null
  Get-Content -Raw $replyWorkflowPath | ConvertFrom-Json | Out-Null
  docker compose config --quiet
  Write-Host "Stage 6 workflow JSON and Docker Compose config parse."

  try {
    $services = docker compose ps --services --filter "status=running" 2>$null
  }
  catch {
    Write-Warning "Docker is not reachable. Start Docker Desktop and run .\scripts\start-local.ps1 before live Stage 6 workflow verification."
    return
  }

  if (($services -notcontains "n8n") -or ($services -notcontains "postgres")) {
    Write-Warning "n8n and Postgres are not both running. Run .\scripts\start-local.ps1, then rerun this script for live Stage 6 workflow verification."
    return
  }

  & .\scripts\apply-stage-6.ps1 | Out-Host
  docker compose up -d n8n | Out-Host
  Wait-Stage6N8n

  $dailyWorkflowId = "stage-6-daily-watch-chase"
  $replyWorkflowId = "stage-6-non-pdf-reply-notice"

  Import-Stage6Workflow -Path $dailyWorkflowPath -WorkflowId $dailyWorkflowId -WorkflowName "Stage 6 - Daily Watch Chase"
  Import-Stage6Workflow -Path $replyWorkflowPath -WorkflowId $replyWorkflowId -WorkflowName "Stage 6 - Non PDF Reply Notice"

  docker compose run --rm --no-deps n8n update:workflow --id=$dailyWorkflowId --active=true | Out-Host
  docker compose run --rm --no-deps n8n update:workflow --id=$replyWorkflowId --active=true | Out-Host

  $liveSmokeEnabled = Invoke-Stage6Scalar "SELECT EXISTS (SELECT 1 FROM credentials_entity WHERE name = 'OpenAI account');"
  if ($liveSmokeEnabled -ne "t") {
    Write-Warning "OpenAI credential is not present; imported workflows but skipped live Stage 6 draft smoke."
    return
  }

  Invoke-Stage6Sql @'
TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY;
UPDATE vendors
SET chase_paused = true,
    last_attested_at = NULL;
UPDATE vendors
SET chase_paused = false
WHERE normalised_name = normalize_vendor_name('Vista Glass and Door LLC');
UPDATE client_config
SET value = ''
WHERE key IN ('stage_6_approver_email', 'stage_6_test_recipient_email');
UPDATE client_config
SET value = '2026-07-30'
WHERE key = 'stage_6_watch_as_of_date';
'@ | Out-Null

  $executeOutput = docker compose run --rm --no-deps n8n execute --id $dailyWorkflowId --rawOutput
  $executeText = $executeOutput -join "`n"
  $outputPath = Join-Path $repoRoot "tmp\stage6-daily-watch-output.txt"
  New-Item -ItemType Directory -Force (Split-Path -Parent $outputPath) | Out-Null
  Set-Content -Path $outputPath -Value $executeText -Encoding UTF8

  $execution = ConvertFrom-N8nRawOutput -Text $executeText
  Assert-Stage6Condition ($execution.finished -eq $true) "Stage 6 daily watch execution did not finish successfully. Raw output saved at $outputPath."

  Assert-Stage6Condition ((Invoke-Stage6Scalar "SELECT count(*) = 1 FROM outreach_log WHERE bucket = 'NEVER_RECEIVED' AND drafted_body IS NOT NULL AND drafted_body !~* '\m(compliant|verified|covered|approved)\M';") -eq "t") "Stage 6 draft smoke did not create one safe pending outreach row."
  Assert-Stage6Condition ((Invoke-Stage6Scalar "SELECT count(*) = 1 FROM intake_notices WHERE notice_code = 'STAGE_6_CONFIG_NOTICE';") -eq "t") "Stage 6 config notice was not stored when approval/send addresses were intentionally blank."

  $configuredForApproval = Invoke-Stage6Scalar "SELECT stage_6_config_value('stage_6_approver_email', '') <> '' AND stage_6_config_value('stage_6_test_recipient_email', '') <> '';"
  if ($configuredForApproval -ne "t") {
    Write-Warning "Approval/send live path skipped: stage_6_approver_email and stage_6_test_recipient_email are blank. Configure both, then rerun for a real approval email."
  }

  Invoke-Stage6Sql "TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY; UPDATE vendors SET chase_paused = false, last_attested_at = NULL; UPDATE client_config SET value = '' WHERE key = 'stage_6_watch_as_of_date';" | Out-Null

  Write-Host "Stage 6 workflow import and draft smoke verification complete."
}
finally {
  Pop-Location
}
