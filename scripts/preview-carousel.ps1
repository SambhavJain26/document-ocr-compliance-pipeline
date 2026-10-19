#Requires -Version 5.1
<#
.SYNOPSIS
    Render a carousel to PNG for visual checking, without producing a PDF.

.DESCRIPTION
    Building a carousel is an iterative loop: change the HTML or the stylesheet,
    look at it, fix what is wrong. This renders the deck as a contact sheet of
    all slides, or a single slide at full size.

    Look at both. A contact sheet shows composition and rhythm but hides
    clipping, low contrast and misplaced annotations. A full-size slide shows
    the marks but tells you nothing about how the deck reads as a set. Most
    mistakes in the first build of this template were caught by one view after
    passing unnoticed in the other.

    Output goes to a temp directory, not the repo. Use
    generate-linkedin-carousel.ps1 when you want the actual PDF.

.EXAMPLE
    .\scripts\preview-carousel.ps1
    Contact sheet of every slide in the only carousel present.

.EXAMPLE
    .\scripts\preview-carousel.ps1 -Slide 6
    Slide 6 at full size, for checking a mark or a tight fit.
#>
[CmdletBinding()]
param(
    [string] $Name,
    [int]    $Slide = 0,
    [double] $Zoom  = 0.26,
    [string] $OutDir,
    [int]    $VirtualTimeBudget = 25000
)

$ErrorActionPreference = 'Stop'

$repoRoot    = Split-Path -Parent $PSScriptRoot
$carouselDir = Join-Path $repoRoot 'docs\carousels'
$cssPath     = Join-Path $carouselDir 'carousel-template.css'

if (-not $OutDir) { $OutDir = Join-Path $env:TEMP 'carousel-preview' }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

function Find-Chrome {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    throw 'No Chrome or Edge executable found.'
}

# Resolve the post file.
if ($Name) {
    $src = Join-Path $carouselDir "$Name.html"
    if (-not (Test-Path $src)) { throw "No such carousel: $src" }
    $src = Get-Item $src
} else {
    $all = @(Get-ChildItem -Path $carouselDir -Filter '*.html' -File)
    if ($all.Count -eq 0) { throw "No carousel HTML in $carouselDir" }
    if ($all.Count -gt 1) {
        throw ("Several carousels present; pass -Name. Found: " + (($all | ForEach-Object { $_.BaseName }) -join ', '))
    }
    $src = $all[0]
}

$enc  = New-Object System.Text.UTF8Encoding($false)
$html = [System.IO.File]::ReadAllText($src.FullName, $enc)

# The stylesheet is linked relatively, which breaks once the page is copied to
# a temp directory. Point it back at the real file.
$cssUrl = 'file:///' + $cssPath.Replace([char]92, [char]47)
$html = $html.Replace('href="carousel-template.css"', 'href="' + $cssUrl + '"')
$cachedFonts = Join-Path $repoRoot 'tmp\carousel-fonts\fonts.css'
if ($html.Contains('href="../../tmp/carousel-fonts/fonts.css"')) {
    if (-not (Test-Path $cachedFonts)) { throw 'Prepare fonts first: python scripts/prepare-carousel-fonts.py (fonttools required).' }
    $fontUrl = 'file:///' + $cachedFonts.Replace([char]92, [char]47)
    $html = $html.Replace('href="../../tmp/carousel-fonts/fonts.css"', 'href="' + $fontUrl + '"')
}

$slideCount = ([regex]::Matches($html, '<section class="slide')).Count

if ($Slide -gt 0) {
    if ($Slide -gt $slideCount) { throw "Slide $Slide requested but the deck has $slideCount." }
    $zoomUsed = if ($PSBoundParameters.ContainsKey('Zoom')) { $Zoom } else { 1.0 }
    $winW = [int](1080 * $zoomUsed) + 24
    $winH = [int](1350 * $zoomUsed) + 24
    $label = "slide-$Slide"
    $override = @"
<style>
html, body { width:auto; background:#5A6068; }
body { display:block; padding:12px; width:$([int](1080 * $zoomUsed) + 12)px; }
.slide { zoom:$zoomUsed; page-break-after:auto; display:none; }
.slide:nth-of-type($Slide) { display:block; }
</style>
</head>
"@
} else {
    $zoomUsed = $Zoom
    $perRow   = 3
    $rows     = [math]::Ceiling($slideCount / $perRow)
    $winW     = 1180
    $winH     = [int]($rows * ((1350 * $zoomUsed) + 18)) + 40
    $label    = 'sheet'
    $override = @"
<style>
html, body { width:auto; background:#5A6068; }
body { display:flex; flex-wrap:wrap; gap:18px; padding:18px; width:1180px; }
.slide { zoom:$zoomUsed; page-break-after:auto; }
</style>
</head>
"@
}

$html = $html.Replace('</head>', $override)

$stamp    = Get-Date -Format 'HHmmss'
$tempHtml = Join-Path $OutDir "$($src.BaseName)-$label-$stamp.html"
$png      = Join-Path $OutDir "$($src.BaseName)-$label-$stamp.png"
[System.IO.File]::WriteAllText($tempHtml, $html, $enc)

# Invoking chrome.exe directly hands the command line to an already-running
# Chrome and returns immediately with no exit code, so nothing gets written.
# Start-Process with a throwaway profile keeps this instance separate.
$profileDir = Join-Path $env:TEMP ('carousel-preview-' + [guid]::NewGuid().ToString('N'))
$browser    = Find-Chrome
$browserArgs = @(
    '--headless=new'
    '--disable-gpu'
    '--no-sandbox'
    '--hide-scrollbars'
    "--user-data-dir=$profileDir"
    "--virtual-time-budget=$VirtualTimeBudget"
    "--window-size=$winW,$winH"
    "--screenshot=$png"
    ('file:///' + $tempHtml.Replace([char]92, [char]47))
)

$proc = Start-Process -FilePath $browser -ArgumentList $browserArgs -NoNewWindow -Wait -PassThru
Remove-Item -Recurse -Force $profileDir -ErrorAction SilentlyContinue

if ($proc.ExitCode -ne 0 -or -not (Test-Path $png)) {
    throw "Render failed (exit $($proc.ExitCode)). Check that the webfonts could be fetched."
}

Write-Host "$($src.BaseName): $slideCount slides"
Write-Host $png
