param(
  [switch] $DryRun,
  [switch] $Force,
  [switch] $Codex,
  [switch] $Claude,
  [switch] $Shared
)

$ErrorActionPreference = 'Stop'

$source = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) {
  throw "Skill source not found: $source"
}

$targets = @()
if ($Codex) {
  $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } elseif ($env:USERPROFILE) { Join-Path $env:USERPROFILE '.codex' } else { '' }
  if (-not [string]::IsNullOrWhiteSpace($codexHome)) {
    $targets += (Join-Path $codexHome 'skills\handoff-implementation-to-opencode')
  }
}
if ($Claude) {
  if ($env:USERPROFILE) {
    $targets += (Join-Path $env:USERPROFILE '.claude\skills\handoff-implementation-to-opencode')
  }
}
if ($Shared -or (-not $Codex -and -not $Claude)) {
  if ($env:USERPROFILE) {
    $targets += (Join-Path $env:USERPROFILE '.agents\skills\handoff-implementation-to-opencode')
  }
}

foreach ($target in $targets) {
  Write-Host "[install] Target: $target" -ForegroundColor Cyan
  if ($DryRun) { continue }

  if ((Test-Path -LiteralPath $target) -and -not $Force) {
    Write-Host "[install] Exists; use -Force to replace: $target" -ForegroundColor Yellow
    continue
  }

  $parent = Split-Path -Parent $target
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent | Out-Null
  }

  $temp = Join-Path $parent ("handoff-implementation-to-opencode.installing-" + (Get-Date).ToString('yyyyMMddHHmmss'))
  Copy-Item -LiteralPath $source -Destination $temp -Recurse

  if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
  }
  Move-Item -LiteralPath $temp -Destination $target
  Write-Host "[install] Installed: $target" -ForegroundColor Green
}
