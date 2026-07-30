$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $repoRoot ".env"

if (-not (Test-Path $envPath)) {
  throw ".env not found. Run scripts/init-env.ps1 first."
}

$envValues = @{}
Get-Content $envPath | ForEach-Object {
  $line = $_.Trim()
  if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
    $parts = $line.Split("=", 2)
    $envValues[$parts[0]] = $parts[1]
  }
}

$postgresUser = $envValues["POSTGRES_USER"]
$postgresDb = $envValues["POSTGRES_DB"]
$pgwebUser = $envValues["PGWEB_USER"]
$pgwebPassword = $envValues["PGWEB_PASSWORD"]
$n8nPort = $envValues["N8N_PORT"]
if (-not $n8nPort) {
  $n8nPort = "5678"
}
$pgwebPort = $envValues["PGWEB_PORT"]
if (-not $pgwebPort) {
  $pgwebPort = "8081"
}

Push-Location $repoRoot
try {
  Write-Host "Validating Docker Compose config..."
  docker compose config --quiet

  Write-Host "Checking service status..."
  docker compose ps

  Write-Host "Checking Postgres readiness..."
  docker compose exec -T postgres pg_isready -U $postgresUser -d $postgresDb

  Write-Host "Running Postgres smoke query..."
  docker compose exec -T postgres psql -U $postgresUser -d $postgresDb -c "select 1 as ok;"

  $n8nUrl = "http://localhost:$n8nPort"
  Write-Host "Checking n8n at $n8nUrl..."
  $response = $null
  for ($attempt = 1; $attempt -le 30; $attempt++) {
    try {
      $response = Invoke-WebRequest -Uri $n8nUrl -UseBasicParsing -TimeoutSec 10
      break
    }
    catch {
      if ($attempt -eq 30) {
        throw
      }
      Write-Host "n8n not ready yet; retrying in 5 seconds..."
      Start-Sleep -Seconds 5
    }
  }
  Write-Host "n8n returned HTTP $($response.StatusCode)."

  $pgwebUrl = "http://localhost:$pgwebPort"
  Write-Host "Checking pgweb at $pgwebUrl..."
  $pgwebResponse = $null
  for ($attempt = 1; $attempt -le 20; $attempt++) {
    try {
      $pgwebResponse = Invoke-WebRequest -Uri $pgwebUrl -UseBasicParsing -TimeoutSec 10
      break
    }
    catch {
      if ($attempt -eq 20) {
        throw
      }
      Write-Host "pgweb not ready yet; retrying in 3 seconds..."
      Start-Sleep -Seconds 3
    }
  }
  Write-Host "pgweb returned HTTP $($pgwebResponse.StatusCode)."

  if ($pgwebUser -and $pgwebPassword) {
    Write-Host "Checking pgweb readonly table scope..."
    $expectedCoiTables = @(
      "certificates",
      "client_config",
      "coverages",
      "holder_entities",
      "intake_notices",
      "outreach_log",
      "trade_requirements",
      "vendors"
    )
    $tableSql = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name;"
    $visibleTables = docker compose exec -T -e PGPASSWORD=$pgwebPassword postgres psql -h localhost -U $pgwebUser -d $postgresDb -t -A -c $tableSql
    if ($LASTEXITCODE -ne 0) {
      throw "Could not verify pgweb readonly table scope. Run .\scripts\apply-pgweb-viewer.ps1."
    }
    $visibleTableList = @($visibleTables | Where-Object { $_ -ne "" })
    $unexpectedTables = @($visibleTableList | Where-Object { $expectedCoiTables -notcontains $_ })
    foreach ($table in $expectedCoiTables) {
      if ($visibleTableList -notcontains $table) {
        throw "pgweb readonly user cannot see expected table '$table'. Run .\scripts\apply-pgweb-viewer.ps1."
      }
    }
    if ($unexpectedTables.Count -gt 0) {
      throw "pgweb readonly user can see unexpected tables: $($unexpectedTables -join ', '). Run .\scripts\apply-pgweb-viewer.ps1."
    }
    Write-Host "pgweb readonly user sees only COI demo tables."
  }

  Write-Host "Local verification complete."
}
finally {
  Pop-Location
}
