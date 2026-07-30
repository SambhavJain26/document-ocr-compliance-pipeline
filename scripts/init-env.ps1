param(
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$examplePath = Join-Path $repoRoot ".env.example"
$envPath = Join-Path $repoRoot ".env"

if (-not (Test-Path $examplePath)) {
  throw ".env.example not found at $examplePath"
}

if ((Test-Path $envPath) -and -not $Force) {
  Write-Host ".env already exists. Use -Force to regenerate local secrets."
  exit 0
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

$content = Get-Content -Raw $examplePath
$content = $content.Replace("replace-with-generated-local-password", (New-HexSecret 24))
$content = $content.Replace("replace-with-generated-pgweb-password", (New-HexSecret 24))
$content = $content.Replace("replace-with-generated-local-encryption-key", (New-HexSecret 32))

Set-Content -Path $envPath -Value $content -Encoding ascii -NoNewline
Write-Host "Created .env with generated local secrets."
