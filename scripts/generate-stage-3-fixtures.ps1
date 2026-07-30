$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$bundledPython = "C:\Users\jains\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$popplerBin = "C:\Users\jains\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\poppler\Library\bin"

if (Test-Path $bundledPython) {
  $python = $bundledPython
}
else {
  $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
  if (-not $pythonCommand) {
    throw "Python not found. Install Python with reportlab, pypdf, pdfplumber, and Pillow, or run from Codex with bundled dependencies."
  }
  $python = $pythonCommand.Source
}

if (Test-Path $popplerBin) {
  $env:PATH = "$popplerBin;$env:PATH"
  $env:PDFTOPPM = Join-Path $popplerBin "pdftoppm.exe"
}

Push-Location $repoRoot
try {
  & $python .\scripts\generate_stage_3_fixtures.py
}
finally {
  Pop-Location
}
