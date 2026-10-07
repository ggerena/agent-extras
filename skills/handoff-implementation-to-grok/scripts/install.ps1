param(
  [string] $TargetRoot = '',
  [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$source = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($TargetRoot)) {
  $TargetRoot = Join-Path $env:USERPROFILE '.codex\skills'
}
$target = Join-Path ([System.IO.Path]::GetFullPath($TargetRoot)) 'handoff-implementation-to-grok'
$files = @(
  'SKILL.md',
  'agents\openai.yaml',
  'scripts\grok_handoff.py',
  'scripts\handoff-implementation-to-grok.ps1',
  'scripts\get-grok-handoff-status.ps1',
  'scripts\wait-grok-handoff.ps1',
  'scripts\export-grok-handoff-report.ps1',
  'scripts\remove-grok-handoff.ps1',
  'scripts\install.ps1'
)

foreach ($relative in $files) {
  $sourcePath = Join-Path $source $relative
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Source file missing: $sourcePath"
  }
}

if ($DryRun) {
  [ordered]@{
    dry_run = $true
    source = $source
    target = $target
    files = $files
  } | ConvertTo-Json -Depth 4
  exit 0
}

foreach ($relative in $files) {
  $sourcePath = Join-Path $source $relative
  $targetPath = Join-Path $target $relative
  $targetParent = Split-Path -Parent $targetPath
  New-Item -ItemType Directory -Force -Path $targetParent | Out-Null
  Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
}

[ordered]@{
  installed = $true
  source = $source
  target = $target
  files = $files
} | ConvertTo-Json -Depth 4
