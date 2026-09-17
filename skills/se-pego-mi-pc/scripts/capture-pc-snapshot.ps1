[CmdletBinding()]
param(
  [ValidateRange(1, 10)]
  [int] $SampleSeconds = 3,

  [string] $OutputDirectory = (Join-Path $env:LOCALAPPDATA 'Codex\Diagnostics\pc-hang')
)

$ErrorActionPreference = 'Stop'
$capturedAt = Get-Date
$logicalProcessors = [Environment]::ProcessorCount
$supplementalIssues = @()

$before = @{}
Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
  try {
    if ($null -ne $_.CPU) {
      $before[$_.Id] = $_.CPU
    }
  } catch {
    # A process can exit while the snapshot is being collected.
  }
}

$sampleTimer = [System.Diagnostics.Stopwatch]::StartNew()
Start-Sleep -Seconds $SampleSeconds

$after = foreach ($process in (Get-Process -ErrorAction SilentlyContinue)) {
  try {
    [pscustomobject]@{
      Name = $process.ProcessName
      Pid = $process.Id
      CpuSeconds = $process.CPU
      WorkingSetMB = [Math]::Round($process.WorkingSet64 / 1MB, 1)
      Threads = $process.Threads.Count
      Handles = $process.HandleCount
    }
  } catch {
    # Preserve the rest of the sample when a process exits mid-read.
  }
}
$sampleTimer.Stop()
$actualSampleSeconds = [Math]::Max(0.001, $sampleTimer.Elapsed.TotalSeconds)

$processes = foreach ($process in $after) {
  $cpuDelta = 0.0
  if ($null -ne $process.CpuSeconds -and $before.ContainsKey($process.Pid)) {
    $cpuDelta = [Math]::Max(0.0, [double] $process.CpuSeconds - [double] $before[$process.Pid])
  }
  [pscustomobject]@{
    Name = $process.Name
    Pid = $process.Pid
    CpuPercent = [Math]::Round(($cpuDelta / $actualSampleSeconds) * 100 / $logicalProcessors, 2)
    WorkingSetMB = $process.WorkingSetMB
    Threads = $process.Threads
    Handles = $process.Handles
  }
}

$topCpu = @($processes | Sort-Object CpuPercent -Descending | Select-Object -First 20)
$topMemory = @($processes | Sort-Object WorkingSetMB -Descending | Select-Object -First 10)
$windowStart = $capturedAt.AddMinutes(-15)

$computer = [ordered]@{
  LogicalProcessors = $logicalProcessors
}
try {
  $os = Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 2
  $computer.OsCaption = $os.Caption
  $computer.OsVersion = $os.Version
  $computer.LastBootUpTime = $os.LastBootUpTime.ToString('o')
  $computer.TotalMemoryMB = [Math]::Round($os.TotalVisibleMemorySize / 1KB, 0)
  $computer.FreeMemoryMB = [Math]::Round($os.FreePhysicalMemory / 1KB, 0)
} catch {
  $supplementalIssues += 'Operating system metadata was unavailable.'
}

$eventCandidates = @()
try {
  $eventCandidates += @(Get-WinEvent -FilterHashtable @{
      LogName = 'Application'
      StartTime = $windowStart
      ProviderName = @('Application Hang', 'Application Error', 'Windows Error Reporting')
    } -MaxEvents 30 -ErrorAction SilentlyContinue)
} catch {
  $supplementalIssues += 'Targeted application events were unavailable.'
}
try {
  $eventCandidates += @(Get-WinEvent -FilterHashtable @{
      LogName = 'Application'
      StartTime = $windowStart
      Level = @(1, 2)
    } -MaxEvents 30 -ErrorAction SilentlyContinue)
} catch {
  $supplementalIssues += 'Critical and error application events were unavailable.'
}

$events = @(
  $eventCandidates |
    Group-Object RecordId |
    ForEach-Object { $_.Group[0] } |
    Sort-Object TimeCreated -Descending |
    Select-Object -First 30 |
    ForEach-Object {
      [pscustomobject]@{
        TimeCreated = $_.TimeCreated.ToString('o')
        LogName = $_.LogName
        Provider = $_.ProviderName
        Id = $_.Id
        RecordId = $_.RecordId
        Level = $_.Level
      }
    }
)

$snapshot = [ordered]@{
  CapturedAt = $capturedAt.ToString('o')
  RequestedSampleSeconds = $SampleSeconds
  ActualSampleSeconds = [Math]::Round($actualSampleSeconds, 3)
  Computer = $computer
  TopCpu = $topCpu
  TopMemory = $topMemory
  RecentApplicationEvents = $events
  SupplementalIssues = $supplementalIssues
  Privacy = 'No command lines, event messages, environment variables, window titles, or file contents were captured.'
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
  New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$fileName = 'pc-hang-{0}.json' -f $capturedAt.ToString('yyyyMMdd-HHmmss')
$outputPath = Join-Path $OutputDirectory $fileName
$snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding utf8

Write-Output "SNAPSHOT_PATH=$outputPath"
Write-Output "CAPTURED_AT=$($snapshot.CapturedAt)"
Write-Output "REQUESTED_SAMPLE_SECONDS=$SampleSeconds"
Write-Output "ACTUAL_SAMPLE_SECONDS=$($snapshot.ActualSampleSeconds)"
Write-Output "FREE_MEMORY_MB=$($snapshot.Computer.FreeMemoryMB)"
$topCpu | Select-Object -First 10 | Format-Table Name, Pid, CpuPercent, WorkingSetMB, Threads -AutoSize
