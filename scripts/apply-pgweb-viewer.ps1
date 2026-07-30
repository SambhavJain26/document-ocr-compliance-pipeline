$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $repoRoot ".env"

if (-not (Test-Path $envPath)) {
  throw ".env not found. Run scripts/init-env.ps1 first."
}

function New-HexSecret([int]$ByteCount) {
  $bytes = New-Object byte[] $ByteCount
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $rng.GetBytes($bytes)
  }
  finally {
    $rng.Dispose()
  }
  return -join ($bytes | ForEach-Object { $_.ToString("x2") })
}

function Read-EnvValues {
  param([string]$Path)

  $values = @{}
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
      $parts = $line.Split("=", 2)
      $values[$parts[0]] = $parts[1]
    }
  }
  return $values
}

function Upsert-EnvValue {
  param(
    [string[]]$Lines,
    [string]$Key,
    [string]$Value
  )

  $updated = $false
  $next = foreach ($line in $Lines) {
    if ($line -match "^$([regex]::Escape($Key))=") {
      $updated = $true
      "$Key=$Value"
    }
    else {
      $line
    }
  }

  if (-not $updated) {
    $next += "$Key=$Value"
  }

  return $next
}

$envValues = Read-EnvValues $envPath
$pgwebUser = $envValues["PGWEB_USER"]
if (-not $pgwebUser) {
  $pgwebUser = "coi_readonly"
}
$pgwebPassword = $envValues["PGWEB_PASSWORD"]
if (-not $pgwebPassword) {
  $pgwebPassword = New-HexSecret 24
}

$envLines = Get-Content $envPath
$envLines = Upsert-EnvValue -Lines $envLines -Key "PGWEB_USER" -Value $pgwebUser
$envLines = Upsert-EnvValue -Lines $envLines -Key "PGWEB_PASSWORD" -Value $pgwebPassword
if (-not $envValues["PGWEB_PORT"]) {
  $envLines = Upsert-EnvValue -Lines $envLines -Key "PGWEB_PORT" -Value "8081"
}
Set-Content -Path $envPath -Value $envLines -Encoding ascii

$envValues = Read-EnvValues $envPath
$postgresUser = $envValues["POSTGRES_USER"]
$postgresDb = $envValues["POSTGRES_DB"]

$coiTables = @(
  "vendors",
  "certificates",
  "coverages",
  "outreach_log",
  "client_config",
  "holder_entities",
  "trade_requirements",
  "intake_notices"
)

$escapedPgwebUser = $pgwebUser.Replace("'", "''")
$escapedPgwebPassword = $pgwebPassword.Replace("'", "''")
$viewerSchema = "coi_pgweb"
$viewSql = ($coiTables | ForEach-Object {
  "CREATE OR REPLACE VIEW $viewerSchema.$_ AS SELECT * FROM public.$_;"
}) -join "`n"

$sql = @"
DO `$do`$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$escapedPgwebUser') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '$escapedPgwebUser', '$escapedPgwebPassword');
  ELSE
    EXECUTE format('ALTER ROLE %I LOGIN PASSWORD %L', '$escapedPgwebUser', '$escapedPgwebPassword');
  END IF;
END
`$do`$;

GRANT CONNECT ON DATABASE $postgresDb TO $pgwebUser;

CREATE SCHEMA IF NOT EXISTS $viewerSchema;
$viewSql

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO $postgresUser;
REVOKE USAGE ON SCHEMA public FROM $pgwebUser;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM $pgwebUser;

REVOKE ALL ON SCHEMA $viewerSchema FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA $viewerSchema FROM PUBLIC;
GRANT USAGE ON SCHEMA $viewerSchema TO $pgwebUser;
GRANT SELECT ON ALL TABLES IN SCHEMA $viewerSchema TO $pgwebUser;

ALTER ROLE $pgwebUser SET default_transaction_read_only = on;
ALTER ROLE $pgwebUser SET search_path = $viewerSchema;
"@

Push-Location $repoRoot
try {
  $sql | docker compose exec -T postgres psql -U $postgresUser -d $postgresDb -v ON_ERROR_STOP=1 | Out-Host

  Write-Host "Restarting pgweb with restricted COI table user..."
  docker compose up -d pgweb | Out-Host
  docker compose restart pgweb | Out-Host

  $visibleTablesSql = "SELECT table_schema || '.' || table_name FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema') ORDER BY table_schema, table_name;"
  $visibleTables = docker compose exec -T -e PGPASSWORD=$pgwebPassword postgres psql -h localhost -U $pgwebUser -d $postgresDb -t -A -c $visibleTablesSql
  if ($LASTEXITCODE -ne 0) {
    throw "Could not verify pgweb readonly user table visibility."
  }
  $visibleTableList = @($visibleTables | Where-Object { $_ -ne "" })
  $expectedVisibleObjects = @($coiTables | ForEach-Object { "$viewerSchema.$_" })
  $unexpectedTables = @($visibleTableList | Where-Object { $expectedVisibleObjects -notcontains $_ })
  foreach ($table in $coiTables) {
    $expectedObject = "$viewerSchema.$table"
    if ($visibleTableList -notcontains $expectedObject) {
      throw "Restricted pgweb user cannot see expected view '$expectedObject'."
    }
  }
  if ($unexpectedTables.Count -gt 0) {
    throw "Restricted pgweb user can still see unexpected objects: $($unexpectedTables -join ', ')"
  }

  Write-Host "pgweb readonly user '$pgwebUser' can see only COI demo views: $($visibleTableList -join ', ')."
}
finally {
  Pop-Location
}
