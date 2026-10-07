param(
  [Parameter(Mandatory = $true)]
  [string] $PhaseDirectory,
  [Parameter(Mandatory = $true)]
  [string] $Output
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'grok_handoff.py'
$python = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
if ($python -and $python.Source) {
  & $python.Source $script report --phase-dir $PhaseDirectory --output $Output
  exit $LASTEXITCODE
}
$launcher = Get-Command py -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $launcher -or -not $launcher.Source) {
  throw 'Python 3 is required.'
}
& $launcher.Source -3 $script report --phase-dir $PhaseDirectory --output $Output
exit $LASTEXITCODE
