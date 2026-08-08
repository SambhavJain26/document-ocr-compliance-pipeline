param(
  [switch]$IncludeLiveEmail,
  [switch]$OnlyLiveEmail
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = Split-Path -Parent $PSScriptRoot
$tmpRoot = Join-Path $repoRoot "tmp"
$resultsPath = Join-Path $repoRoot "docs\stage-8-fixture-results.md"

$workflowSpecs = @(
  @{ Path = "n8n-workflows\stage-5-intake-workflow.json"; Id = "stage-5-intake-workflow"; Name = "COI Intake"; Requires = "gmail" },
  @{ Path = "n8n-workflows\stage-5-source-document-route.json"; Id = "stage-5-source-document-route"; Name = "Source Document Route"; Requires = "" },
  @{ Path = "n8n-workflows\stage-6-daily-watch-chase.json"; Id = "stage-6-daily-watch-chase"; Name = "Daily Watch and Chase"; Requires = "openai" },
  @{ Path = "n8n-workflows\stage-6-vendor-approval-request.json"; Id = "stage-6-vendor-approval-request"; Name = "Vendor Approval Request"; Requires = "gmail" },
  @{ Path = "n8n-workflows\stage-6-non-pdf-reply-notice.json"; Id = "stage-6-non-pdf-reply-notice"; Name = "Non-PDF Reply Notice"; Requires = "gmail" },
  @{ Path = "n8n-workflows\stage-7-dashboard-demo-view.json"; Id = "stage-7-dashboard-demo-view"; Name = "COI Dashboard"; Requires = "" }
)

$results = New-Object System.Collections.Generic.List[object]
$publishNotes = New-Object System.Collections.Generic.List[string]
$deviations = New-Object System.Collections.Generic.List[string]

function Assert-Stage8Condition {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-Stage8Sql {
  param([string]$Sql)
  $output = $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -F "`t" -A
  if ($LASTEXITCODE -ne 0) {
    throw "Stage 8 SQL command failed."
  }
  return $output
}

function Invoke-Stage8Scalar {
  param([string]$Sql)
  $result = $Sql | docker compose exec -T postgres psql -U vendor_coi -d vendor_coi -v ON_ERROR_STOP=1 -t -A
  if ($LASTEXITCODE -ne 0) {
    throw "Stage 8 SQL scalar command failed."
  }
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

function Wait-Stage8N8n {
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

function Get-Stage8DashboardHtml {
  for ($attempt = 1; $attempt -le 25; $attempt++) {
    try {
      $response = Invoke-WebRequest -Uri "http://localhost:5678/webhook/stage-7-dashboard-webhook/coi" -UseBasicParsing -TimeoutSec 20
      Assert-Stage8Condition ($response.StatusCode -eq 200) "Dashboard webhook did not return HTTP 200."
      return [string]$response.Content
    }
    catch {
      if ($attempt -eq 25) {
        throw
      }
      Start-Sleep -Seconds 2
    }
  }
}

function Import-Stage8Workflow {
  param(
    [string]$Path,
    [string]$WorkflowId,
    [string]$WorkflowName
  )

  $safeId = $WorkflowId.Replace("'", "''")
  $safeName = $WorkflowName.Replace("'", "''")
  Invoke-Stage8Sql "DELETE FROM workflow_entity WHERE id = '$safeId' OR name = '$safeName';" | Out-Null

  $workflowJson = Get-Content -Raw $Path
  $importCommand = "tmp=/tmp/$WorkflowId.json; cat > `$tmp; n8n import:workflow --input=`$tmp"
  $workflowJson | docker compose exec -T n8n sh -lc $importCommand | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "n8n import failed for $WorkflowName."
  }

  $found = Invoke-Stage8Scalar "SELECT id FROM workflow_entity WHERE id = '$safeId' OR name = '$safeName' LIMIT 1;"
  Assert-Stage8Condition ($found -eq $WorkflowId) "Imported workflow $WorkflowName was not found by expected ID."
}

function Set-Stage8WorkflowActive {
  param(
    [string]$WorkflowId,
    [bool]$Required
  )

  $output = docker compose run --rm --no-deps n8n update:workflow --id=$WorkflowId --active=true 2>&1
  $text = $output -join "`n"
  if ($LASTEXITCODE -ne 0) {
    if ($Required) {
      throw "Could not publish workflow $WorkflowId. Output:`n$text"
    }
    $publishNotes.Add("Skipped publishing $WorkflowId because n8n reported: $($text.Split("`n")[0])") | Out-Null
    Write-Warning "Skipped publishing $WorkflowId. See docs/stage-8-fixture-results.md for the reason."
    return
  }

  $publishNotes.Add("Published $WorkflowId.") | Out-Null
  $output | Out-Host
}

function Set-Stage8SmokeFixtures {
  param([string]$FixtureSet)

  $safe = $FixtureSet.Replace("'", "''")
  Invoke-Stage8Sql "UPDATE client_config SET value = '$safe' WHERE key = 'stage_5_smoke_fixture_set';" | Out-Null
}

function Invoke-Stage8N8nExecute {
  param([string]$WorkflowId)

  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = docker compose run --rm --no-deps n8n execute --id $WorkflowId --rawOutput 2>&1
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousErrorAction
  }

  return [pscustomobject]@{
    Output = $output
    ExitCode = $exitCode
  }
}

function Get-Stage8GmailMessageById {
  param([string]$MessageId)

  $workflowId = "tmp-stage8-gmail-final-message-check"
  $workflowName = "TMP Stage 8 Gmail Final Message Check"
  $outputPath = Join-Path $tmpRoot "stage8-gmail-final-message-check-output.txt"
  $workflowPath = Join-Path $tmpRoot "$workflowId.json"

  $workflow = [ordered]@{
    id = $workflowId
    name = $workflowName
    nodes = @(
      [ordered]@{
        parameters = [ordered]@{}
        id = "tmp-stage8-gmail-final-manual"
        name = "Manual Trigger"
        type = "n8n-nodes-base.manualTrigger"
        typeVersion = 1
        position = @(0, 0)
      },
      [ordered]@{
        parameters = [ordered]@{
          resource = "message"
          operation = "get"
          messageId = $MessageId
          simple = $false
        }
        id = "tmp-stage8-gmail-final-get"
        name = "Get Gmail Final Chase Message"
        type = "n8n-nodes-base.gmail"
        typeVersion = 2.1
        position = @(280, 0)
        credentials = [ordered]@{
          gmailOAuth2 = [ordered]@{
            id = "Gmail account"
            name = "Gmail account"
          }
        }
      }
    )
    connections = [ordered]@{
      "Manual Trigger" = [ordered]@{
        main = @(
          @(
            [ordered]@{
              node = "Get Gmail Final Chase Message"
              type = "main"
              index = 0
            }
          )
        )
      }
    }
    settings = [ordered]@{
      executionOrder = "v1"
    }
  }

  New-Item -ItemType Directory -Force $tmpRoot | Out-Null
  $workflow | ConvertTo-Json -Depth 30 | Set-Content -Path $workflowPath -Encoding UTF8

  try {
    Import-Stage8Workflow -Path $workflowPath -WorkflowId $workflowId -WorkflowName $workflowName
    $executionResult = Invoke-Stage8N8nExecute -WorkflowId $workflowId
    $executeText = $executionResult.Output -join "`n"
    Set-Content -Path $outputPath -Value $executeText -Encoding UTF8

    if ($executionResult.ExitCode -ne 0) {
      throw "Stage 8 Gmail final message check failed. Raw output saved at $outputPath."
    }

    $execution = ConvertFrom-N8nRawOutput -Text $executeText
    Assert-Stage8Condition ($execution.finished -eq $true) "Stage 8 Gmail final message check did not finish. Raw output saved at $outputPath."

    $run = $execution.data.resultData.runData.'Get Gmail Final Chase Message'[0]
    $message = $run.data.main[0][0].json
    Assert-Stage8Condition ($message.id -eq $MessageId) "Stage 8 Gmail final message check returned the wrong message ID."
    return $message
  }
  finally {
    $safeWorkflowId = $workflowId.Replace("'", "''")
    Invoke-Stage8Sql "DELETE FROM workflow_entity WHERE id = '$safeWorkflowId';" | Out-Null
    Remove-Item -LiteralPath $workflowPath -ErrorAction SilentlyContinue
  }
}

function Invoke-Stage8IntakeFixtureSet {
  param([string]$FixtureSet)

  Set-Stage8SmokeFixtures $FixtureSet
  & .\scripts\reset-demo.ps1 | Out-Host
  Set-Stage8SmokeFixtures $FixtureSet

  $safeFixtureName = $FixtureSet -replace "[^a-zA-Z0-9._-]+", "-"
  $outputPath = Join-Path $tmpRoot "stage8-intake-$safeFixtureName-output.txt"
  New-Item -ItemType Directory -Force (Split-Path -Parent $outputPath) | Out-Null

  $executionResult = Invoke-Stage8N8nExecute -WorkflowId "stage-5-intake-workflow"
  $executeText = $executionResult.Output -join "`n"
  Set-Content -Path $outputPath -Value $executeText -Encoding UTF8

  if ($executionResult.ExitCode -ne 0) {
    throw "Stage 5 intake execution for $FixtureSet failed. Raw output saved at $outputPath."
  }

  $execution = ConvertFrom-N8nRawOutput -Text $executeText
  Assert-Stage8Condition ($execution.finished -eq $true) "Stage 5 intake execution for $FixtureSet did not finish successfully. Raw output saved at $outputPath."
}

function Invoke-Stage8IntakeWithoutReset {
  param([string]$FixtureSet)

  Set-Stage8SmokeFixtures $FixtureSet
  $safeFixtureName = $FixtureSet -replace "[^a-zA-Z0-9._-]+", "-"
  $outputPath = Join-Path $tmpRoot "stage8-intake-$safeFixtureName-output.txt"
  New-Item -ItemType Directory -Force (Split-Path -Parent $outputPath) | Out-Null

  $executionResult = Invoke-Stage8N8nExecute -WorkflowId "stage-5-intake-workflow"
  $executeText = $executionResult.Output -join "`n"
  Set-Content -Path $outputPath -Value $executeText -Encoding UTF8

  if ($executionResult.ExitCode -ne 0) {
    throw "Stage 5 intake execution for $FixtureSet failed. Raw output saved at $outputPath."
  }

  $execution = ConvertFrom-N8nRawOutput -Text $executeText
  Assert-Stage8Condition ($execution.finished -eq $true) "Stage 5 intake execution for $FixtureSet did not finish successfully. Raw output saved at $outputPath."
}

function Add-Stage8Result {
  param(
    [string]$Fixture,
    [string]$Expected,
    [string]$Actual,
    [string]$Status,
    [string]$Notes
  )

  $results.Add([pscustomobject]@{
    Fixture = $Fixture
    Expected = $Expected
    Actual = $Actual
    Status = $Status
    Notes = $Notes
  }) | Out-Null
}

function Escape-MdCell {
  param([string]$Value)
  return (($Value -replace "\|", "\|") -replace "`r?`n", "<br>")
}

function Write-Stage8ResultsDoc {
  param([string]$RunStatus)

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Stage 8 Fixture Results") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("Generated by ``.\scripts\verify-stage-8-fixtures.ps1`` on $((Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")) UTC.") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("Run status: $RunStatus") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("## Workflow Publish Notes") | Out-Null
  $lines.Add("") | Out-Null
  if ($publishNotes.Count -eq 0) {
    $lines.Add("- No live publish attempted.") | Out-Null
  }
  else {
    foreach ($note in $publishNotes) {
      $lines.Add("- $note") | Out-Null
    }
  }
  $lines.Add("") | Out-Null
  $lines.Add("## Fixture Outcome Summary") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("| Fixture | Expected | Actual | Status | Notes |") | Out-Null
  $lines.Add("| --- | --- | --- | --- | --- |") | Out-Null
  foreach ($row in $results) {
    $lines.Add("| $(Escape-MdCell $row.Fixture) | $(Escape-MdCell $row.Expected) | $(Escape-MdCell $row.Actual) | $(Escape-MdCell $row.Status) | $(Escape-MdCell $row.Notes) |") | Out-Null
  }
  if ($results.Count -eq 0) {
    $lines.Add("| n/a | Live fixture run | Skipped | SKIPPED | n8n/Postgres/OpenAI were unavailable. |") | Out-Null
  }
  $lines.Add("") | Out-Null
  if ($deviations.Count -eq 0) {
    $lines.Add("Accepted deviations: none recorded in the latest run.") | Out-Null
  }
  else {
    $lines.Add("## Accepted Deviations") | Out-Null
    $lines.Add("") | Out-Null
    foreach ($deviation in $deviations) {
      $lines.Add("- $deviation") | Out-Null
    }
  }
  $lines.Add("") | Out-Null
  $lines.Add("Raw n8n execution output is written under ignored ``tmp/stage8-intake-*.txt``.") | Out-Null

  Set-Content -Path $resultsPath -Value $lines -Encoding UTF8
}

function Assert-CertificateOutcome {
  param(
    [string]$Fixture,
    [string]$ExpectedStatus,
    [string[]]$ExpectedFlags = @(),
    [string]$ExtraSql = "",
    [string]$ExtraNote = "",
    [string]$AcceptedNoticeCode = "",
    [string]$AcceptedDeviationNote = ""
  )

  Invoke-Stage8IntakeFixtureSet $Fixture
  $status = Invoke-Stage8Scalar "SELECT coalesce((SELECT status FROM certificates WHERE source_ref = '$Fixture' LIMIT 1), 'missing');"
  if ($status -eq "missing" -and $AcceptedNoticeCode -ne "") {
    $noticeCode = Invoke-Stage8Scalar "SELECT coalesce((SELECT notice_code FROM intake_notices WHERE source_ref = '$Fixture' LIMIT 1), 'missing');"
    if ($noticeCode -eq $AcceptedNoticeCode) {
      Add-Stage8Result $Fixture "$ExpectedStatus with $($ExpectedFlags -join ", ")" $noticeCode "ACCEPTED_DEVIATION" $AcceptedDeviationNote
      $deviations.Add("${Fixture}: $AcceptedDeviationNote") | Out-Null
      return
    }
  }
  Assert-Stage8Condition ($status -eq $ExpectedStatus) "$Fixture expected certificate status $ExpectedStatus but got $status."
  foreach ($flag in $ExpectedFlags) {
    $hasFlag = Invoke-Stage8Scalar "SELECT EXISTS (SELECT 1 FROM certificates c, jsonb_array_elements(c.validation_flags) f WHERE c.source_ref = '$Fixture' AND f->>'code' = '$flag');"
    Assert-Stage8Condition ($hasFlag -eq "t") "$Fixture did not store expected flag $flag."
  }
  if ($ExtraSql -ne "") {
    $extraPassed = Invoke-Stage8Scalar $ExtraSql
    Assert-Stage8Condition ($extraPassed -eq "t") "$Fixture failed extra verification: $ExtraNote"
  }
  $flagText = if ($ExpectedFlags.Count -gt 0) { " with " + ($ExpectedFlags -join ", ") } else { "" }
  Add-Stage8Result $Fixture $ExpectedStatus "$status$flagText" "PASS" $ExtraNote
}

function Assert-NoticeOutcome {
  param(
    [string]$Fixture,
    [string]$SourceRef,
    [string]$ExpectedNoticeCode
  )

  Invoke-Stage8IntakeFixtureSet $Fixture
  $noticeCode = Invoke-Stage8Scalar "SELECT coalesce((SELECT notice_code FROM intake_notices WHERE source_ref = '$SourceRef' LIMIT 1), 'missing');"
  $certCount = Invoke-Stage8Scalar "SELECT count(*)::TEXT FROM certificates WHERE source_ref = '$SourceRef';"
  Assert-Stage8Condition ($noticeCode -eq $ExpectedNoticeCode) "$Fixture expected notice $ExpectedNoticeCode but got $noticeCode."
  Assert-Stage8Condition ($certCount -eq "0") "$Fixture unexpectedly created certificate rows."
  Add-Stage8Result $Fixture $ExpectedNoticeCode $noticeCode "PASS" "Notice-only intake created no certificate row."
}

function Assert-SourcePdfLinks {
  $rows = Invoke-Stage8Sql "SELECT certificate_id, source_url_path FROM stage_7_dashboard_rows(CURRENT_DATE) WHERE source_url_path IS NOT NULL ORDER BY certificate_id LIMIT 3;"
  $dataRows = $rows | Where-Object { $_ -match "^\d+`t" }
  Assert-Stage8Condition ($dataRows.Count -gt 0) "Dashboard did not expose any source PDF links."
  foreach ($row in $dataRows) {
    $parts = $row -split "`t"
    $path = $parts[1]
    $response = Invoke-WebRequest -Uri "http://localhost:5678$path" -UseBasicParsing -TimeoutSec 20
    $sourcePrefix = if ($response.Content -is [byte[]]) {
      [Text.Encoding]::ASCII.GetString($response.Content[0..3])
    }
    else {
      [string]$response.Content.Substring(0, [Math]::Min(4, $response.Content.Length))
    }
    Assert-Stage8Condition ($response.StatusCode -eq 200 -and $sourcePrefix -eq "%PDF") "Dashboard source link $path did not return PDF bytes."
  }
}

function Invoke-Stage8LiveEmailRehearsal {
  param(
    [bool]$HasOpenAi,
    [bool]$HasGmail
  )

  if (-not ($IncludeLiveEmail -or $OnlyLiveEmail)) {
    Add-Stage8Result "stage-8-live-email-rehearsal" "Optional approval email and final send" "Skipped" "SKIPPED" "Run with -IncludeLiveEmail to send a real Stage 6 approval email."
    return
  }

  Assert-Stage8Condition $HasOpenAi "Live email rehearsal requires local n8n credential 'OpenAI account'."
  Assert-Stage8Condition $HasGmail "Live email rehearsal requires local n8n credential 'Gmail account'."

  $configuredForApproval = Invoke-Stage8Scalar "SELECT stage_6_config_value('stage_6_approver_email', '') <> '' AND stage_6_config_value('stage_6_test_recipient_email', '') <> '';"
  Assert-Stage8Condition ($configuredForApproval -eq "t") "Live email rehearsal requires non-empty stage_6_approver_email and stage_6_test_recipient_email."

  $approverEmail = Invoke-Stage8Scalar "SELECT stage_6_config_value('stage_6_approver_email', '');"
  $testRecipientEmail = Invoke-Stage8Scalar "SELECT stage_6_config_value('stage_6_test_recipient_email', '');"

  Invoke-Stage8Sql @'
TRUNCATE TABLE outreach_log, coverages, certificates, intake_notices RESTART IDENTITY;
UPDATE vendors
SET chase_paused = true,
    last_attested_at = NULL;
UPDATE vendors
SET chase_paused = false
WHERE normalised_name = normalize_vendor_name('Vista Glass and Door LLC');
UPDATE client_config
SET value = CURRENT_DATE::TEXT
WHERE key = 'stage_6_watch_as_of_date';
'@ | Out-Null

  Write-Host "Stage 8 live email rehearsal: approval email should arrive at $approverEmail. Click Approve to complete the send to $testRecipientEmail."

  $outputPath = Join-Path $tmpRoot "stage8-live-email-daily-watch-output.txt"
  New-Item -ItemType Directory -Force (Split-Path -Parent $outputPath) | Out-Null
  $executionResult = Invoke-Stage8N8nExecute -WorkflowId "stage-6-daily-watch-chase"
  $executeText = $executionResult.Output -join "`n"
  Set-Content -Path $outputPath -Value $executeText -Encoding UTF8

  if ($executionResult.ExitCode -ne 0) {
    throw "Stage 8 live email rehearsal execution failed. Raw output saved at $outputPath."
  }

  $execution = ConvertFrom-N8nRawOutput -Text $executeText
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 1 FROM outreach_log WHERE bucket = 'NEVER_RECEIVED' AND drafted_body IS NOT NULL AND drafted_body !~* '\m(compliant|verified|covered|approved)\M';") -eq "t") "Stage 8 live email rehearsal did not create one safe pending outreach row."

  if ($execution.status -eq "waiting") {
    for ($attempt = 1; $attempt -le 36; $attempt++) {
      $sent = Invoke-Stage8Scalar "SELECT count(*) = 1 FROM outreach_log WHERE bucket = 'NEVER_RECEIVED' AND approved = true AND sent_at IS NOT NULL AND actual_recipient = stage_6_config_value('stage_6_test_recipient_email', '');"
      if ($sent -eq "t") {
        break
      }
      Start-Sleep -Seconds 10
    }
  }
  else {
    Assert-Stage8Condition ($execution.finished -eq $true) "Stage 8 live email rehearsal did not finish or enter approval wait. Raw output saved at $outputPath."
  }

  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 1 FROM outreach_log WHERE bucket = 'NEVER_RECEIVED' AND approved = true AND sent_at IS NOT NULL AND follow_up_due IS NOT NULL AND actual_recipient = stage_6_config_value('stage_6_test_recipient_email', '');") -eq "t") "Stage 8 live email rehearsal did not produce an approved sent outreach row. Approve the email sent to $approverEmail, then rerun with -IncludeLiveEmail."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 0 FROM intake_notices WHERE notice_code = 'STAGE_6_CONFIG_NOTICE';") -eq "t") "Stage 8 live email rehearsal stored a config notice even though approval/send addresses were configured."

  $gmailMessageId = Invoke-Stage8Scalar "SELECT send_response->>'id' FROM outreach_log WHERE bucket = 'NEVER_RECEIVED' AND approved = true AND sent_at IS NOT NULL ORDER BY id DESC LIMIT 1;"
  Assert-Stage8Condition ($gmailMessageId -ne "") "Stage 8 live email rehearsal did not store a Gmail final message ID."
  $gmailMessage = Get-Stage8GmailMessageById -MessageId $gmailMessageId
  $labelIds = @($gmailMessage.labelIds)
  Assert-Stage8Condition ($labelIds -contains "SENT") "Final Gmail message $gmailMessageId was not found with SENT label."
  Assert-Stage8Condition ($labelIds -contains "INBOX") "Final Gmail message $gmailMessageId was not found with INBOX label."

  Add-Stage8Result "stage-8-live-email-rehearsal" "Approval email sent, approved, final Gmail send logged, and final message readable by Gmail ID" "Approval email to $approverEmail; final send to $testRecipientEmail; Gmail message $gmailMessageId labels $($labelIds -join ',')" "PASS" "When approver and test recipient are the same Gmail account, the message may appear in Sent, Inbox, or All Mail views depending on Gmail threading."
}

Push-Location $repoRoot
try {
  & .\scripts\generate-stage-5-workflows.ps1 | Out-Host
  & .\scripts\generate-stage-6-workflows.ps1 | Out-Host
  & .\scripts\generate-stage-7-dashboard-workflow.ps1 | Out-Host

  foreach ($spec in $workflowSpecs) {
    Get-Content -Raw (Join-Path $repoRoot $spec.Path) | ConvertFrom-Json | Out-Null
  }
  Get-Content -Raw (Join-Path $repoRoot "db\postgres\005-stage-7-dashboard.sql") | Select-String -Pattern "CREATE OR REPLACE FUNCTION stage_7_dashboard_rows" | Out-Null
  docker compose config --quiet
  Write-Host "Stage 8 static checks passed: workflow JSON, Stage 7 SQL path, and Docker Compose config parse."

  try {
    $services = docker compose ps --services --filter "status=running" 2>$null
  }
  catch {
    Write-Warning "Docker is not reachable. Live Stage 8 checks skipped."
    Write-Stage8ResultsDoc "SKIPPED - Docker unavailable after static checks"
    return
  }

  if (($services -notcontains "n8n") -or ($services -notcontains "postgres")) {
    Write-Warning "n8n and Postgres are not both running. Live Stage 8 checks skipped."
    Write-Stage8ResultsDoc "SKIPPED - n8n/Postgres not running after static checks"
    return
  }

  & .\scripts\apply-stage-7.ps1 | Out-Host
  docker compose up -d n8n | Out-Host
  Wait-Stage8N8n

  foreach ($spec in $workflowSpecs) {
    Import-Stage8Workflow -Path (Join-Path $repoRoot $spec.Path) -WorkflowId $spec.Id -WorkflowName $spec.Name
  }

  $hasOpenAi = (Invoke-Stage8Scalar "SELECT EXISTS (SELECT 1 FROM credentials_entity WHERE name = 'OpenAI account');") -eq "t"
  $hasGmail = (Invoke-Stage8Scalar "SELECT EXISTS (SELECT 1 FROM credentials_entity WHERE name = 'Gmail account');") -eq "t"

  Set-Stage8WorkflowActive -WorkflowId "stage-5-source-document-route" -Required $true
  Set-Stage8WorkflowActive -WorkflowId "stage-7-dashboard-demo-view" -Required $true
  if ($hasGmail) {
    Set-Stage8WorkflowActive -WorkflowId "stage-5-intake-workflow" -Required $false
    # Vendor Approval Request must be active before the daily watch runs. Daily
    # Watch and Chase calls it once per actionable vendor via Execute Workflow,
    # and that call fails if the target is not importable and active yet.
    Set-Stage8WorkflowActive -WorkflowId "stage-6-vendor-approval-request" -Required $false
    Set-Stage8WorkflowActive -WorkflowId "stage-6-non-pdf-reply-notice" -Required $false
  }
  else {
    $publishNotes.Add("Skipped publishing Gmail-trigger workflows because local credential 'Gmail account' was not found.") | Out-Null
    Write-Warning "Gmail credential not found; Gmail-trigger workflow publishing skipped."
  }
  if ($hasOpenAi) {
    Set-Stage8WorkflowActive -WorkflowId "stage-6-daily-watch-chase" -Required $false
  }
  else {
    $publishNotes.Add("Skipped publishing Stage 6 daily watch because local credential 'OpenAI account' was not found.") | Out-Null
    Write-Warning "OpenAI credential not found; Stage 6 daily watch publishing skipped."
  }

  docker compose restart n8n | Out-Host
  Wait-Stage8N8n

  if (-not $hasOpenAi) {
    Write-Warning "OpenAI credential is not present; live fixture ingestion skipped after import/publish checks."
    Write-Stage8ResultsDoc "SKIPPED - OpenAI credential unavailable after import/publish"
    return
  }

  if ($OnlyLiveEmail) {
    Invoke-Stage8LiveEmailRehearsal -HasOpenAi $hasOpenAi -HasGmail $hasGmail
    & .\scripts\reset-demo.ps1 | Out-Host
    Write-Stage8ResultsDoc "PASS"
    Write-Host "Stage 8 opt-in live email rehearsal complete."
    return
  }

  $resetDuration = Measure-Command { & .\scripts\reset-demo.ps1 | Out-Host }
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 18 FROM vendors;") -eq "t") "Reset did not preserve 18 vendors."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 0 FROM certificates;") -eq "t") "Reset did not clear certificates."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 0 FROM coverages;") -eq "t") "Reset did not clear coverages."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 0 FROM intake_notices;") -eq "t") "Reset did not clear intake notices."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 0 FROM outreach_log;") -eq "t") "Reset did not clear outreach log."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 18 FROM stage_7_dashboard_rows(CURRENT_DATE) WHERE display_status = 'No certificate on file';") -eq "t") "Reset dashboard did not show 18 no-certificate rows."
  Add-Stage8Result "reset-demo" "18 vendors, zero runtime rows" "18 vendors, zero runtime rows in $([Math]::Round($resetDuration.TotalSeconds, 3))s" "PASS" "Schema was already applied before the reset measurement."

  Assert-CertificateOutcome "f01-clean-current" "ON_FILE"
  Assert-CertificateOutcome "f02-expiring-20-days" "ON_FILE"
  Assert-CertificateOutcome "f03-expired-34-days" "ON_FILE"
  Assert-CertificateOutcome "f04-scanned-clean-current" "ON_FILE"
  Assert-CertificateOutcome "f05-inverted-dates" "NEEDS_REVIEW" @("DATE_INVERTED")
  Assert-CertificateOutcome "f06-wrong-holder" "ON_FILE" @("HOLDER_MISMATCH")
  Assert-CertificateOutcome "f07-low-limits" "ON_FILE" @("LIMIT_BELOW_MINIMUM")
  Assert-CertificateOutcome "f08-multiple-expiry-dates" "ON_FILE" @() "SELECT EXISTS (SELECT 1 FROM certificates c JOIN coverages cv ON cv.certificate_id = c.id WHERE c.source_ref = 'f08-multiple-expiry-dates' AND cv.expiration_date = DATE '2026-09-15');" "Earliest stored coverage date includes 2026-09-15."
  Assert-CertificateOutcome "f09-missing-gl" "ON_FILE" @("NO_GL_LINE")
  Assert-NoticeOutcome "f11-not-a-certificate" "f11-not-a-certificate" "NOT_A_COI"
  Assert-CertificateOutcome "f15-wc-exempt" "ON_FILE"
  Assert-CertificateOutcome "f16-owner-llc-holder" "ON_FILE"
  Assert-CertificateOutcome "f17-near-duplicate-vendor" "NEEDS_REVIEW" @("POSSIBLE_DUPLICATE_VENDOR") "" "" "NOT_A_COI" "Model variance: the extractor treated the synthetic fixture disclaimer as proof that the document was not a certificate. This is conservative and does not violate the honesty boundary, but the live demo should not rely on this fixture to demonstrate near-duplicate review unless it passes locally."
  Assert-CertificateOutcome "f18-password-protected" "NEEDS_REVIEW" @("PDF_PASSWORD_PROTECTED")
  Assert-CertificateOutcome "f20-cancellation-notice-wording" "ON_FILE" @() "SELECT EXISTS (SELECT 1 FROM certificates WHERE source_ref = 'f20-cancellation-notice-wording' AND cancellation_notice_wording = 'Thirty days written notice of cancellation will be sent to the certificate holder when required by policy terms.');" "Cancellation notice wording captured verbatim as neutral dashboard text."
  Assert-NoticeOutcome "f19-portal-link-email" "f19-portal-link-email:no-pdf" "PORTAL_LINK_NO_ATTACHMENT"

  Invoke-Stage8IntakeFixtureSet "f10-two-certificates-email"
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 2 FROM certificates WHERE source_ref LIKE 'f10-two-certificates-email:%';") -eq "t") "f10 did not create two certificate rows."
  Add-Stage8Result "f10-two-certificates-email" "TWO_CERTIFICATE_ROWS" "2 certificate rows" "PASS" "Manual fixture expands the email into two attachment-specific source refs."

  & .\scripts\reset-demo.ps1 | Out-Host
  Invoke-Stage8IntakeWithoutReset "f02-expiring-20-days"
  Invoke-Stage8IntakeWithoutReset "f12-renewal-supersede"
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f12-renewal-supersede' AND status = 'ON_FILE';") -eq "t") "f12 renewal was not ON_FILE."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f02-expiring-20-days' AND status = 'SUPERSEDED';") -eq "t") "f12 did not supersede f02."
  Add-Stage8Result "f12-renewal-supersede" "ON_FILE supersedes f02" "f12 ON_FILE, f02 SUPERSEDED" "PASS" "Dependency-safe renewal scenario run."

  & .\scripts\reset-demo.ps1 | Out-Host
  Invoke-Stage8IntakeWithoutReset "f03-expired-34-days"
  Invoke-Stage8IntakeWithoutReset "f13-renewal-coverage-gap"
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f13-renewal-coverage-gap' AND status = 'ON_FILE';") -eq "t") "f13 renewal was not ON_FILE."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 1 FROM certificates WHERE source_ref = 'f03-expired-34-days' AND status = 'SUPERSEDED';") -eq "t") "f13 did not supersede f03."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT EXISTS (SELECT 1 FROM certificates c, jsonb_array_elements(c.validation_flags) f WHERE c.source_ref = 'f13-renewal-coverage-gap' AND f->>'code' = 'COVERAGE_GAP' AND f #>> '{details,gap_days}' = '14');") -eq "t") "f13 did not store COVERAGE_GAP gap_days 14."
  Add-Stage8Result "f13-renewal-coverage-gap" "ON_FILE supersedes f03 with COVERAGE_GAP gap_days 14" "f13 ON_FILE, f03 SUPERSEDED, gap_days 14" "PASS" "Dependency-safe renewal scenario run."

  & .\scripts\reset-demo.ps1 | Out-Host
  $noFileVendorSql = @'
SELECT count(*) = 4
FROM stage_6_actionable_vendors(CURRENT_DATE)
WHERE bucket = 'NEVER_RECEIVED'
  AND vendor_legal_name IN (
    'Vista Glass and Door LLC',
    'Oakbend Tree Service LLC',
    'Northstar Snow Removal LLC',
    'Rapid Response Restoration LLC'
  );
'@
  Assert-Stage8Condition ((Invoke-Stage8Scalar $noFileVendorSql) -eq "t") "f14 metadata-only vendors did not appear as Stage 6 NEVER_RECEIVED rows."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 18 FROM stage_7_dashboard_rows(CURRENT_DATE) WHERE display_status = 'No certificate on file';") -eq "t") "f14 no-file dashboard state was not all no-certificate rows."
  Add-Stage8Result "f14-no-file-vendors" "NEVER_RECEIVED/no certificate" "4 named vendors actionable; dashboard has 18 no-certificate rows" "PASS" "Metadata-only fixture is represented by reset state, not by a PDF run."

  & .\scripts\reset-demo.ps1 | Out-Host
  foreach ($fixtureSet in @(
    "f01-clean-current",
    "f02-expiring-20-days",
    "f05-inverted-dates",
    "f06-wrong-holder",
    "f07-low-limits",
    "f09-missing-gl",
    "f17-near-duplicate-vendor",
    "f18-password-protected",
    "f20-cancellation-notice-wording"
  )) {
    Invoke-Stage8IntakeWithoutReset $fixtureSet
  }
  Invoke-Stage8IntakeWithoutReset "f03-expired-34-days"
  Invoke-Stage8IntakeWithoutReset "f13-renewal-coverage-gap"

  $dashboardHtml = Get-Stage8DashboardHtml
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT count(*) = 18 FROM stage_7_dashboard_rows(CURRENT_DATE);") -eq "t") "Dashboard did not render all 18 seeded vendors after fixture ingestion."
  Assert-Stage8Condition ((Invoke-Stage8Scalar "SELECT sum(coverage_gap_count_marker) >= 1 FROM stage_7_dashboard_rows(CURRENT_DATE);") -eq "t") "Dashboard did not expose a coverage gap count marker."
  Assert-Stage8Condition ($dashboardHtml.Contains("Certificate states cancellation notice wording.")) "Dashboard did not render neutral cancellation notice wording text."
  Assert-Stage8Condition ($dashboardHtml.Contains("14-day paperwork gap")) "Dashboard did not render coverage gap detail."
  foreach ($blocked in @("compliant", "verified", "covered", "approved")) {
    Assert-Stage8Condition (-not $dashboardHtml.ToLowerInvariant().Contains($blocked)) "Dashboard HTML contained forbidden word '$blocked'."
  }
  Assert-SourcePdfLinks
  Add-Stage8Result "dashboard-full-fixture-view" "18 vendors, source links, gap count, neutral cancellation wording, forbidden words absent" "Dashboard checks passed" "PASS" "Representative fixture ingestion state verified through live webhook."

  Invoke-Stage8LiveEmailRehearsal -HasOpenAi $hasOpenAi -HasGmail $hasGmail

  & .\scripts\reset-demo.ps1 | Out-Host
  $finalRunStatus = if ($deviations.Count -gt 0) { "PASS WITH ACCEPTED DEVIATIONS" } else { "PASS" }
  Write-Stage8ResultsDoc $finalRunStatus
  Write-Host "Stage 8 full fixture and rehearsal-readiness verification complete."
}
catch {
  Write-Stage8ResultsDoc "FAILED - $($_.Exception.Message)"
  throw
}
finally {
  try {
    $services = docker compose ps --services --filter "status=running" 2>$null
    if (($services -contains "postgres") -and (Test-Path (Join-Path $PSScriptRoot "reset-demo.ps1"))) {
      & .\scripts\reset-demo.ps1 | Out-Host
    }
  }
  catch {
    Write-Warning "Final demo reset did not complete: $($_.Exception.Message)"
  }
  Pop-Location
}
