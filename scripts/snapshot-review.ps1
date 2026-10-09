param(
    [string]$ReviewDir = "C:\Users\koate\development\page-review"
)

# Snapshot the static build into reviewable, double-clickable HTML.
# Requires `npm run build` first (or `npm run preview` server for full fidelity).
$ErrorActionPreference = "Stop"

$site = Split-Path $PSScriptRoot -Parent
$src = Join-Path $site "dist"
if (-not (Test-Path -LiteralPath $src)) {
    Write-Host "dist/ not found. Run: npm run build" -ForegroundColor Red
    exit 1
}

if (Test-Path -LiteralPath $ReviewDir) { Remove-Item -Recurse -Force $ReviewDir }
Copy-Item -Recurse -Force $src $ReviewDir

$html = Get-ChildItem -Recurse -Filter *.html $ReviewDir
foreach ($f in $html) {
    $rel = $f.FullName.Substring($ReviewDir.Length).TrimStart('\', '/')
    $dir = Split-Path $rel -Parent
    $depth = if ($dir) { ($dir -split '[\\/]').Count } else { 0 }
    $prefix = if ($depth -gt 0) { ('../' * $depth) } else { '' }

    $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $content = [regex]::Replace(
        $content,
        '="(/(?!\/)[^"]*)"',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m) '="' + $prefix + $m.Groups[1].Value.TrimStart('/') + '"'
        }
    )
    [System.IO.File]::WriteAllText($f.FullName, $content, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host "Snapshot ready: $ReviewDir ($($html.Count) html files)"
Write-Host "Open review.html index or any page directly." -ForegroundColor Green