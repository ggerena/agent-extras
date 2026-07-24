param(
  [switch] $DryRun,
  [switch] $Force
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot
$agentsInstallBase = Join-Path $env:USERPROFILE '.agents\skills'
$codexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path $env:USERPROFILE '.codex' } else { $env:CODEX_HOME }
$codexInstallBase = Join-Path $codexHome 'skills'

$destinations = @(
  (Join-Path $agentsInstallBase 'agent-handoff'),
  (Join-Path $codexInstallBase 'agent-handoff')
)

function Assert-InstallPath {
  param([string] $Path)
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  foreach ($base in @($agentsInstallBase, $codexInstallBase)) {
    $baseFull = [System.IO.Path]::GetFullPath($base).TrimEnd([char[]] @('\', '/'))
    if ($pathFull.StartsWith($baseFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
      return
    }
  }
  throw "Ruta fuera de los directorios de skills permitidos: $pathFull"
}

Write-Host "[install] Source: $skillRoot" -ForegroundColor Cyan

$copied = 0
$skipped = 0

foreach ($dest in $destinations) {
  Write-Host "[install] Target: $dest" -ForegroundColor Cyan
  Assert-InstallPath -Path $dest
  $sourceResolved = (Resolve-Path -LiteralPath $skillRoot).Path
  $destResolved = $null
  if (Test-Path -LiteralPath $dest) {
    $destResolved = (Resolve-Path -LiteralPath $dest).Path
  }
  if ($destResolved -and ($destResolved -ieq $sourceResolved)) {
    Write-Host "[install] El destino es la carpeta fuente; se omite." -ForegroundColor Yellow
    $skipped++
    continue
  }
  if ($destResolved -and -not $Force) {
    Write-Host "[install] El destino ya existe; se omite. Vuelve a ejecutar con -Force para reemplazarlo desde la fuente del repo." -ForegroundColor Yellow
    $skipped++
    continue
  }
  if ($DryRun) {
    if ($destResolved -and $Force) {
      Write-Host "[install] Dry run: se reemplazaria la skill instalada desde la fuente del repo." -ForegroundColor Yellow
    } else {
      Write-Host "[install] Dry run: se copiaria la skill si el destino no existe." -ForegroundColor Yellow
    }
    $skipped++
    continue
  }
  $parent = Split-Path -Parent $dest
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent | Out-Null
  }
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $tempBase = Join-Path $parent "agent-handoff.installing-$stamp"
  $tempDest = $tempBase
  $tempSuffix = 2
  while (Test-Path -LiteralPath $tempDest) {
    $tempDest = "$tempBase-$tempSuffix"
    $tempSuffix++
  }
  Assert-InstallPath -Path $tempDest
  Copy-Item -LiteralPath $skillRoot -Destination $tempDest -Recurse
  try {
    if ($destResolved) {
      Remove-Item -LiteralPath $dest -Recurse -Force
    }
    Move-Item -LiteralPath $tempDest -Destination $dest
  } catch {
    if (Test-Path -LiteralPath $tempDest) {
      Remove-Item -LiteralPath $tempDest -Recurse -Force
    }
    throw
  }
  $copied++
  Write-Host "[install] Copiado OK." -ForegroundColor Green
}

if ($DryRun) {
  Write-Host "[install] Dry run completo." -ForegroundColor Yellow
} else {
  Write-Host "[install] Resumen: copiados=$copied, omitidos=$skipped. Destinos: .agents y Codex." -ForegroundColor Green
}
