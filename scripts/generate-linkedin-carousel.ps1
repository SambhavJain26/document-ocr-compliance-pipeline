#Requires -Version 5.1
<#
.SYNOPSIS
    Render a LinkedIn document carousel from HTML to an upload-ready PDF.

.DESCRIPTION
    Carousel slides live as HTML in docs/carousels/, sharing the fixed
    template in docs/carousels/carousel-template.css. This script prints them
    through headless Chrome at the page size declared in the stylesheet
    (1080 x 1350) and writes the PDF to docs/carousels/out/.

    Fonts are fetched from api.fontshare.com at render time, so the machine
    needs network access. -VirtualTimeBudget exists because Chrome will
    otherwise print before the webfonts land and fall back to a system face.

    template-specimen.html is a layout reference, not a post. Render it with
    -Name when checking the template; it is skipped in a full run.

.EXAMPLE
    .\scripts\generate-linkedin-carousel.ps1
    Renders every carousel in docs/carousels/.

.EXAMPLE
    .\scripts\generate-linkedin-carousel.ps1 -Name post-01-property-manager-day
    Renders one carousel by file stem.
#>
[CmdletBinding()]
param(
    [string] $Name,
    [int]    $VirtualTimeBudget = 15000
)

$ErrorActionPreference = 'Stop'

$repoRoot    = Split-Path -Parent $PSScriptRoot
$carouselDir = Join-Path $repoRoot 'docs\carousels'
$outDir      = Join-Path $carouselDir 'out'

function Find-Chrome {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    throw 'No Chrome or Edge executable found. Install Chrome, or set the path in this script.'
}

if (-not (Test-Path $carouselDir)) {
    throw "Carousel directory not found: $carouselDir"
}
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$browser = Find-Chrome
Write-Host "Renderer: $browser"

$pattern = if ($Name) { "$Name.html" } else { '*.html' }
$sources = @(Get-ChildItem -Path $carouselDir -Filter $pattern -File)

if (-not $Name) {
    $sources = @($sources | Where-Object { $_.BaseName -ne 'template-specimen' })
}

if ($sources.Count -eq 0) {
    throw "No carousel HTML matched '$pattern' in $carouselDir"
}

# Chrome needs a writable profile dir; reusing the real one fails if the
# browser is already open.
$profileDir = Join-Path $env:TEMP ("carousel-render-" + [guid]::NewGuid().ToString('N'))

$failed = 0
foreach ($src in $sources) {
    $pdf = Join-Path $outDir ($src.BaseName + '.pdf')
    $url = 'file:///' + ($src.FullName -replace '\\', '/')

    Write-Host "Rendering $($src.Name) -> $(Split-Path -Leaf $pdf)"

    # Invoking chrome.exe directly hands the command line to an already-running
    # Chrome and returns immediately with no exit code, so the PDF never gets
    # written. Start-Process with a throwaway profile keeps this instance
    # separate and lets us actually wait for it.
    $browserArgs = @(
        '--headless=new'
        '--disable-gpu'
        '--no-sandbox'
        '--no-pdf-header-footer'
        '--run-all-compositor-stages-before-draw'
        "--user-data-dir=$profileDir"
        "--virtual-time-budget=$VirtualTimeBudget"
        "--print-to-pdf=$pdf"
        $url
    )

    $proc = Start-Process -FilePath $browser -ArgumentList $browserArgs `
                          -NoNewWindow -Wait -PassThru
    $code = $proc.ExitCode

    if ($code -ne 0 -or -not (Test-Path $pdf)) {
        Write-Warning "FAILED: $($src.Name) (exit $code)"
        $failed++
        continue
    }

    $sizeKb = [math]::Round((Get-Item $pdf).Length / 1KB, 1)
    Write-Host "  ok, $sizeKb KB"
}

if (Test-Path $profileDir) {
    Remove-Item -Recurse -Force $profileDir -ErrorAction SilentlyContinue
}

if ($failed -gt 0) {
    throw "$failed carousel(s) failed to render."
}

Write-Host ''
Write-Host "Done. PDFs in $outDir"
Write-Host 'Upload the PDF to LinkedIn as a document post. The document title'
Write-Host 'you type on upload is displayed in the feed, so use the cover line.'
