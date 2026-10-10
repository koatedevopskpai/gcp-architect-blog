param(
    [switch]$SkipBuild
)

# Generate 1200x630 OG images for posts into public/og/
# Requires Windows PowerShell (System.Drawing). Usage: powershell -File scripts/gen-og.ps1
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing | Out-Null

function New-OgImage {
    param(
        [string]$OutFile,
        [string]$Eyebrow,
        [string]$Title,
        [string]$Footer,
        [string]$BgHex,
        [string]$AccentHex,
        [string]$TextHex
    )
    $W = 1200
    $H = 630
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $g.Clear([System.Drawing.ColorTranslator]::FromHtml($BgHex))

    # left accent bar + faint bottom rule
    $accent = [System.Drawing.ColorTranslator]::FromHtml($AccentHex)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($accent)), 0, 0, 14, $H)
    $ruleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, 255, 255, 255))
    $g.FillRectangle($ruleBrush, 56, 528, ($W - 112), 2)

    # eyebrow
    $eyebrowBrush = New-Object System.Drawing.SolidBrush($accent)
    $eyebrowFont = New-Object System.Drawing.Font("Segoe UI", 26, [System.Drawing.FontStyle]::Bold)
    $g.DrawString($Eyebrow, $eyebrowFont, $eyebrowBrush, 56, 70)

    # title (wraps inside the rectangle)
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($TextHex))
    $titleFont = New-Object System.Drawing.Font("Segoe UI", 46, [System.Drawing.FontStyle]::Bold)
    $titleRect = New-Object System.Drawing.RectangleF(56, 150, ($W - 112), 360)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Near
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Near
    $g.DrawString($Title, $titleFont, $textBrush, $titleRect, $fmt)

    # footer
    $footerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 255, 255, 255))
    $footerFont = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $g.DrawString($Footer, $footerFont, $footerBrush, 56, 552)

    $dir = Split-Path $OutFile -Parent
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Wrote $OutFile"
}

$root = Split-Path $PSScriptRoot -Parent
$ogDir = Join-Path $root "public\og"
$footer = "KOATEKPAI.DEV  /  GITHUB.COM/KOATEDEVOPSKPAI/ENTERPRISE-RAG-PIPELINE"

New-OgImage `
    -OutFile (Join-Path $ogDir "001-foundry-rag-gotchas.png") `
    -Eyebrow "MICROSOFT FOUNDRY - RAG PIPELINE" `
    -Title "Deploying RAG on Microsoft Foundry: 11 gotchas and their fixes" `
    -Footer $footer `
    -BgHex "#0B1220" `
    -AccentHex "#F59E0B" `
    -TextHex "#F8FAFC"

New-OgImage `
    -OutFile (Join-Path $ogDir "002-retrieval-mode-benchmark.png") `
    -Eyebrow "AZURE AI SEARCH - RETRIEVAL BENCHMARK" `
    -Title "We built three retrieval modes. They tied. Here's the harness." `
    -Footer $footer `
    -BgHex "#062825" `
    -AccentHex "#34D399" `
    -TextHex "#ECFDF5"

New-OgImage `
    -OutFile (Join-Path $ogDir "003-reranking-semantic-crowded.png") `
    -Eyebrow "AZURE AI SEARCH - RERANKING" `
    -Title "Reranking earns its latency when the pool is large and the needle is inside" `
    -Footer $footer `
    -BgHex "#1E293B" `
    -AccentHex "#38BDF8" `
    -TextHex "#F0F9FF"