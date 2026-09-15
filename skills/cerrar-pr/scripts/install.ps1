param(
  [switch] $DryRun,
  [switch] $Force
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot
$skillName = Split-Path -Leaf $skillRoot

$destinations = @(
  (Join-Path $env:USERPROFILE ".codex\skills\$skillName"),
  (Join-Path $env:USERPROFILE ".agents\skills\$skillName"),
  (Join-Path $env:USERPROFILE ".claude\skills\$skillName")
)

Write-Host "[install] Source: $skillRoot" -ForegroundColor Cyan

$copied = 0
$skipped = 0
$backedUp = 0

foreach ($dest in $destinations) {
  Write-Host "[install] Target: $dest" -ForegroundColor Cyan
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
    Write-Host "[install] El destino ya existe; se omite. Vuelve a ejecutar con -Force para reemplazarlo despues de crear un respaldo." -ForegroundColor Yellow
    $skipped++
    continue
  }
  if ($DryRun) {
    if ($destResolved -and $Force) {
      Write-Host "[install] Dry run: se crearia respaldo $dest.backup-<timestamp> y luego se copiaria la skill." -ForegroundColor Yellow
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
  $tempBase = Join-Path $parent "$skillName.installing-$stamp"
  $tempDest = $tempBase
  $tempSuffix = 2
  while (Test-Path -LiteralPath $tempDest) {
    $tempDest = "$tempBase-$tempSuffix"
    $tempSuffix++
  }
  Copy-Item -LiteralPath $skillRoot -Destination $tempDest -Recurse
  $backup = $null
  if ($destResolved) {
    $backupBase = "$dest.backup-$stamp"
    $backup = $backupBase
    $suffix = 2
    while (Test-Path -LiteralPath $backup) {
      $backup = "$backupBase-$suffix"
      $suffix++
    }
  }
  try {
    if ($backup) {
      Move-Item -LiteralPath $dest -Destination $backup
      $backedUp++
      Write-Host "[install] Respaldo creado: $backup" -ForegroundColor Yellow
    }
    Move-Item -LiteralPath $tempDest -Destination $dest
  } catch {
    if ($backup -and (Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $dest)) {
      Move-Item -LiteralPath $backup -Destination $dest
      $backedUp--
      Write-Host "[install] Se restauro el destino original tras un error." -ForegroundColor Yellow
    }
    if (Test-Path -LiteralPath $tempDest) {
      Remove-Item -LiteralPath $tempDest -Recurse -Force
    }
    throw
  }
  $copied++
  Write-Host '[install] Copiado OK.' -ForegroundColor Green
}

if ($DryRun) {
  Write-Host '[install] Dry run completo.' -ForegroundColor Yellow
} else {
  Write-Host "[install] Resumen: copiados=$copied, omitidos=$skipped, respaldos=$backedUp." -ForegroundColor Green
}

