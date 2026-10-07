<#
.SYNOPSIS
    Build the Astro site and deploy it to Firebase Hosting.

.DESCRIPTION
    Runs `npm ci` + `npm run build`, then `firebase deploy --only hosting`.
    Authenticates non-interactively using gcloud Application Default
    Credentials (run `gcloud auth application-default login` once if missing).

.PARAMETER Project
    Firebase/GCP project id. Defaults to gcp-architect-blog.

.PARAMETER SkipBuild
    Deploy the existing dist/ without rebuilding.
#>
[CmdletBinding()]
param(
    [string]$Project = "gcp-architect-blog",
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = [System.IO.Path]::GetFullPath((Join-Path $here '..'))

Push-Location $root
try {
    if (-not $SkipBuild) {
        Write-Host "==> npm ci"
        npm ci --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "npm ci failed" }

        Write-Host "==> npm run build"
        npm run build
        if ($LASTEXITCODE -ne 0) { throw "build failed" }
    }

    # firebase-tools can use gcloud ADC when this env var is set.
    if (-not $env:GOOGLE_APPLICATION_CREDENTIALS) {
        $adc = Join-Path $env:APPDATA 'gcloud\application_default_credentials.json'
        if (Test-Path $adc) {
            $env:GOOGLE_APPLICATION_CREDENTIALS = $adc
            Write-Host "==> using gcloud ADC: $adc"
        } else {
            Write-Warning "No gcloud ADC found. Run: gcloud auth application-default login"
        }
    }

    Write-Host "==> firebase deploy --only hosting --project $Project"
    npx --yes firebase-tools@latest deploy --only hosting --project $Project
    if ($LASTEXITCODE -ne 0) { throw "firebase deploy failed" }
}
finally {
    Pop-Location
}
