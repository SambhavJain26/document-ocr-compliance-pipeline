$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
  "docs\stage-9-production-readiness-plan.md",
  "docs\stage-9-scope-limitations.md",
  "docs\stage-9-data-processing-retention.md",
  "docs\stage-9-client-onboarding-checklist.md",
  "docs\stage-9-implementation-backlog.md"
)

function Assert-Stage9Condition {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function Read-Stage9Doc {
  param([string]$RelativePath)

  $path = Join-Path $repoRoot $RelativePath
  Assert-Stage9Condition (Test-Path $path) "Missing Stage 9 artifact: $RelativePath"
  return Get-Content -Raw $path
}

Push-Location $repoRoot
try {
  foreach ($file in $requiredFiles) {
    $null = Read-Stage9Doc $file
  }

  $plan = Read-Stage9Doc "docs\stage-9-production-readiness-plan.md"
  $scope = Read-Stage9Doc "docs\stage-9-scope-limitations.md"
  $data = Read-Stage9Doc "docs\stage-9-data-processing-retention.md"
  $onboarding = Read-Stage9Doc "docs\stage-9-client-onboarding-checklist.md"
  $backlog = Read-Stage9Doc "docs\stage-9-implementation-backlog.md"

  $planTerms = @(
    "client-owned",
    "n8n licensing",
    "Error Trigger",
    "Retry",
    "Dead Letter",
    "Idempotency",
    "Heartbeat",
    "canary",
    "weekly client digest",
    "uptime monitoring",
    "Backup",
    "restore",
    "HTTPS",
    "Go/No-Go"
  )
  foreach ($term in $planTerms) {
    Assert-Stage9Condition ($plan -match [regex]::Escape($term)) "Production readiness plan missing required term: $term"
  }

  Assert-Stage9Condition ($scope -match "tracks vendor certificate paperwork") "Scope document must state the paperwork-tracking boundary."
  Assert-Stage9Condition ($scope -match "does not verify coverage") "Scope document must explicitly state that the system does not verify coverage."
  Assert-Stage9Condition ($scope -match "compliant, verified, covered, or approved") "Scope document must include the forbidden-claim language boundary."

  $dataTerms = @(
    "vendor names",
    "source certificate PDFs",
    "OpenAI API",
    "24 months",
    "export n8n workflow JSON",
    "Postgres database dump",
    "delete remaining hosted copies"
  )
  foreach ($term in $dataTerms) {
    Assert-Stage9Condition ($data -match [regex]::Escape($term)) "Data processing terms missing required term: $term"
  }

  $onboardingTerms = @(
    "Vendor CSV",
    "holder entities",
    "trade requirements",
    "Gmail/Google Workspace OAuth",
    "Approval links tested from a non-local network",
    "Restore test completed",
    "does not verify coverage",
    "export process"
  )
  foreach ($term in $onboardingTerms) {
    Assert-Stage9Condition ($onboarding -match [regex]::Escape($term)) "Onboarding checklist missing required term: $term"
  }

  foreach ($priority in @("P0 Before First Client", "P1 First Month", "P2 After Operational Learning")) {
    Assert-Stage9Condition ($backlog -match [regex]::Escape($priority)) "Implementation backlog missing section: $priority"
  }

  Write-Host "Stage 9 production readiness artifacts verified."
}
finally {
  Pop-Location
}
