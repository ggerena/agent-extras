[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$captureScript = Join-Path $PSScriptRoot 'capture-pc-snapshot.ps1'

function Assert-True {
  param(
    [bool] $Condition,
    [string] $Message
  )
  if (-not $Condition) {
    throw $Message
  }
}

function New-TestDirectory {
  $path = Join-Path ([System.IO.Path]::GetTempPath()) ('se-pego-mi-pc-test-' + [guid]::NewGuid().ToString('N'))
  [System.IO.Directory]::CreateDirectory($path) | Out-Null
  return $path
}

function Remove-TestDirectory {
  param([string] $Path)
  $resolved = [System.IO.Path]::GetFullPath($Path)
  $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  if (-not $resolved.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove a path outside the temporary directory: $resolved"
  }
  if ([System.IO.Directory]::Exists($resolved)) {
    [System.IO.Directory]::Delete($resolved, $true)
  }
}

$normalDirectory = New-TestDirectory
try {
  & $captureScript -SampleSeconds 1 -OutputDirectory $normalDirectory | Out-Null
  $jsonFile = Get-ChildItem -LiteralPath $normalDirectory -Filter '*.json' | Select-Object -First 1
  Assert-True ($null -ne $jsonFile) 'The normal capture did not create a JSON file.'
  $snapshot = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
  Assert-True ($snapshot.ActualSampleSeconds -ge 1) 'The actual sample duration is shorter than requested.'
  Assert-True ($snapshot.TopCpu.Count -gt 0) 'The normal capture contains no process samples.'
  Assert-True (-not ($snapshot.TopCpu[0].PSObject.Properties.Name -contains 'CommandLine')) 'Process command lines must not be captured.'

  $eventDates = @($snapshot.RecentApplicationEvents | ForEach-Object { [datetimeoffset] $_.TimeCreated })
  $eventsNewestFirst = $true
  for ($index = 1; $index -lt $eventDates.Count; $index++) {
    if ($eventDates[$index] -gt $eventDates[$index - 1]) {
      $eventsNewestFirst = $false
    }
  }
  Assert-True $eventsNewestFirst 'Application events are not ordered newest first.'
  if ($snapshot.RecentApplicationEvents.Count -gt 0) {
    Assert-True (-not ($snapshot.RecentApplicationEvents[0].PSObject.Properties.Name -contains 'Message')) 'Event messages must not be captured.'
  }
} finally {
  Remove-TestDirectory -Path $normalDirectory
}

$fallbackDirectory = New-TestDirectory
try {
  function Get-CimInstance { throw 'simulated CIM failure' }
  function Get-WinEvent { throw 'simulated event log failure' }
  & $captureScript -SampleSeconds 1 -OutputDirectory $fallbackDirectory | Out-Null
  $jsonFile = Get-ChildItem -LiteralPath $fallbackDirectory -Filter '*.json' | Select-Object -First 1
  Assert-True ($null -ne $jsonFile) 'The fallback capture did not create a JSON file.'
  $snapshot = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
  Assert-True ($snapshot.TopCpu.Count -gt 0) 'The fallback capture lost the basic process sample.'
  Assert-True ($snapshot.Computer.LogicalProcessors -gt 0) 'The fallback capture lost the logical processor count.'
  Assert-True ($snapshot.SupplementalIssues.Count -eq 3) 'The fallback capture did not record all supplemental failures.'
} finally {
  Remove-Item Function:\Get-CimInstance -ErrorAction SilentlyContinue
  Remove-Item Function:\Get-WinEvent -ErrorAction SilentlyContinue
  Remove-TestDirectory -Path $fallbackDirectory
}

Write-Output 'PASS: capture-pc-snapshot normal and fallback checks.'
