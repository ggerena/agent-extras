param(
  [Parameter(Mandatory = $true)]
  [string] $PhaseDirectory,
  [ValidateRange(1, 55)]
  [int] $TimeoutSeconds = 55,
  [ValidateRange(1, 10)]
  [int] $PollSeconds = 2
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'grok_handoff.py'
$arguments = @(
  $script,
  'wait',
  '--phase-dir', $PhaseDirectory,
  '--timeout-seconds', [string]$TimeoutSeconds,
  '--poll-seconds', [string]$PollSeconds
)
$python = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
if ($python -and $python.Source) {
  & $python.Source @arguments
  exit $LASTEXITCODE
}
$launcher = Get-Command py -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $launcher -or -not $launcher.Source) {
  throw 'Python 3 is required.'
}
& $launcher.Source -3 @arguments
exit $LASTEXITCODE
