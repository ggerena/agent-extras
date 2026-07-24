param(
  [switch] $DryRun,
  [switch] $Force
)

$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $PSScriptRoot
$codexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path $env:USERPROFILE '.codex' } else { $env:CODEX_HOME }
$target = Join-Path $codexHome 'skills\handoff-implementation-to-grok'

Write-Host "[install] Source: $source" -ForegroundColor Cyan
Write-Host "[install] Target: $target" -ForegroundColor Cyan
if (Test-Path -LiteralPath $target) {
  if (-not $Force) {
    Write-Host '[install] El destino ya existe; usa -Force para reemplazarlo.' -ForegroundColor Yellow
    exit 0
  }
  if ($DryRun) {
    Write-Host '[install] Dry run: se reemplazaria la skill instalada.' -ForegroundColor Yellow
    exit 0
  }
} elseif ($DryRun) {
  Write-Host '[install] Dry run: se copiaria la skill.' -ForegroundColor Yellow
  exit 0
}

$parent = Split-Path -Parent $target
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$temp = Join-Path $parent ('handoff-implementation-to-grok.installing-' + (Get-Date -Format 'yyyyMMddHHmmss'))
Copy-Item -LiteralPath $source -Destination $temp -Recurse
if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
Move-Item -LiteralPath $temp -Destination $target
Write-Host "[install] Installed: $target" -ForegroundColor Green
