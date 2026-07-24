param(
  [Parameter(Mandatory = $true)]
  [Alias('RunDirectory')]
  [string] $PhaseDirectory,
  [string] $HandoffRoot = '',
  [string] $ReportOutput = '',
  [switch] $ForceRunning
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'grok_handoff.py'
$arguments = @($script, 'cleanup', '--phase-dir', $PhaseDirectory)
if (-not [string]::IsNullOrWhiteSpace($ReportOutput)) {
  $arguments += @('--report-output', $ReportOutput)
}
if ($ForceRunning) { $arguments += '--force-running' }

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
