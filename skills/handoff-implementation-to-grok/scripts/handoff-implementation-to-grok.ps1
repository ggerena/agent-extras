param(
  [ValidateSet('codex', 'claude')]
  [string] $Invoker = 'codex',
  [string] $Objective = '',
  [string] $ReviewSummary = '',
  [ValidateSet('pass', 'blocked', 'needs-user')]
  [string] $ReviewVerdict = 'pass',
  [string] $NextStep = '',
  [string] $RepoPath = '',
  [string] $OutDir = 'docs',
  [string] $GrokModel = 'grok-4.5',
  [switch] $SkipReviewGate,
  [switch] $ForceHandoff,
  [switch] $DryRun,
  [switch] $Launch
)

$ErrorActionPreference = 'Stop'

function Invoke-GitSafe {
  param([string] $Repo, [string[]] $GitArgs)
  try {
    $result = & git -C $Repo @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    return ($result -join "`n")
  } catch {
    return ''
  }
}

function Resolve-GrokBinary {
  $candidates = @()
  if ($env:USERPROFILE) { $candidates += (Join-Path $env:USERPROFILE '.grok\bin\grok.exe') }
  if ($env:HOME) { $candidates += (Join-Path $env:HOME '.grok/bin/grok') }
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }
  $command = Get-Command grok -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
  if ($command -and $command.Source) { return $command.Source }
  return ''
}

function Quote-PowerShellArgument {
  param([string] $Value)
  return "'" + ($Value -replace "'", "''") + "'"
}

if ([string]::IsNullOrWhiteSpace($RepoPath)) { $RepoPath = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $RepoPath -PathType Container)) { throw "Repo path not found: $RepoPath" }
$RepoPath = (Resolve-Path -LiteralPath $RepoPath).Path

if ([string]::IsNullOrWhiteSpace($Objective)) { throw 'Objective is required.' }
if (-not $SkipReviewGate -and [string]::IsNullOrWhiteSpace($ReviewSummary)) {
  throw 'Review gate missing. Provide -ReviewSummary or pass -SkipReviewGate explicitly.'
}
if ($ReviewVerdict -ne 'pass' -and -not $ForceHandoff) {
  throw "Review verdict is '$ReviewVerdict'. Delegation blocked unless -ForceHandoff is passed."
}
if ([string]::IsNullOrWhiteSpace($NextStep)) {
  $NextStep = 'Implementar solo el alcance indicado, ejecutar validaciones razonables y completar el reporte para revision de Codex.'
}

$branch = Invoke-GitSafe $RepoPath @('rev-parse', '--abbrev-ref', 'HEAD')
$head = Invoke-GitSafe $RepoPath @('rev-parse', 'HEAD')
$status = Invoke-GitSafe $RepoPath @('status', '--porcelain')
$log = Invoke-GitSafe $RepoPath @('log', '--oneline', '-10')
$diffStat = Invoke-GitSafe $RepoPath @('diff', '--stat')
$dateStamp = Get-Date -Format 'yyyyMMdd'
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$outFull = if ([System.IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $RepoPath $OutDir }
$baseName = "${dateStamp}_DELEGATION-${Invoker}-to-grok"
$handoffName = "$baseName.md"
$handoffPath = Join-Path $outFull $handoffName
$suffix = 2
while (Test-Path -LiteralPath $handoffPath) {
  $handoffName = "$baseName-$suffix.md"
  $handoffPath = Join-Path $outFull $handoffName
  $suffix++
}
$promptName = ([System.IO.Path]::GetFileNameWithoutExtension($handoffName)) + '-prompt.txt'
$statusName = ([System.IO.Path]::GetFileNameWithoutExtension($handoffName)) + '-status.md'
$promptPath = Join-Path $outFull $promptName
$statusPath = Join-Path $outFull $statusName
$relativeOut = if ([System.IO.Path]::IsPathRooted($OutDir)) { $outFull } else { $OutDir }
$promptDisplayPath = (Join-Path $relativeOut $promptName) -replace '\\', '/'
$statusDisplayPath = (Join-Path $relativeOut $statusName) -replace '\\', '/'

$reviewText = if ($SkipReviewGate -and [string]::IsNullOrWhiteSpace($ReviewSummary)) { 'Review gate omitido explicitamente.' } else { "Veredicto: $ReviewVerdict`n`n$ReviewSummary" }
$destinationPrompt = @"
Eres el implementador. Codex conserva la coordinacion, las decisiones y la revision final. Trabaja solo en este objetivo: $Objective

Lee primero el handoff en $((Join-Path $relativeOut $handoffName) -replace '\\', '/'), respeta AGENTS.md y cualquier regla local. Siguiente paso: $NextStep

No hagas commit, push, PR, merge, cambios fuera del alcance ni decisiones de producto/arquitectura no definidas. Ejecuta validaciones razonables. Al terminar o si necesitas una decision, completa el reporte $statusDisplayPath con cambios, validaciones, bloqueos y una pregunta concreta para Codex. Si existe un bloqueo, detente despues del reporte.
"@.Trim()

$handoff = @"
# Delegacion supervisada: $Invoker -> Grok Build

- Fecha: $timestamp
- Coordinador: $Invoker
- Implementador: Grok Build ($GrokModel)
- Repo: $RepoPath
- Rama: $(if ($branch) { $branch } else { 'no disponible' })
- HEAD: $(if ($head) { $head } else { 'no disponible' })

## Objetivo acotado

$Objective

## Review previo

$reviewText

## Siguiente paso para Grok

$NextStep

## Estado objetivo del repo

### Cambios pendientes

````text
$(if ($status) { $status } else { 'Sin cambios pendientes o git no disponible.' })
````

### Historial reciente

````text
$(if ($log) { $log } else { 'No disponible.' })
````

### Resumen del diff actual

````text
$(if ($diffStat) { $diffStat } else { 'Sin cambios sin confirmar o git no disponible.' })
````

## Regla de coordinacion

Grok implementa; $Invoker revisa y decide. Si falta una decision, Grok documenta una pregunta concreta en $statusDisplayPath y se detiene.
"@

$statusTemplate = @"
# Reporte de Grok para Codex

## Resultado

_Pendiente._

## Cambios realizados

_Pendiente._

## Validaciones ejecutadas

_Pendiente._

## Bloqueos o decisiones que necesita Codex

_Ninguno por ahora. Si hay uno, explicar el contexto, las opciones y la recomendacion._

## Siguiente paso propuesto

_Pendiente de revision de Codex._
"@

$suggestedCommand = "grok --model $(Quote-PowerShellArgument $GrokModel) --cwd $(Quote-PowerShellArgument $RepoPath) --prompt-file $(Quote-PowerShellArgument $promptPath)"

if ($DryRun) {
  Write-Host '[handoff-implementation-to-grok] Dry run: no se escriben archivos.' -ForegroundColor Yellow
  Write-Host $handoff
  Write-Host '[handoff-implementation-to-grok] Comando sugerido:' -ForegroundColor Cyan
  Write-Host $suggestedCommand
  exit 0
}

New-Item -ItemType Directory -Force -Path $outFull | Out-Null
Set-Content -LiteralPath $handoffPath -Value $handoff -Encoding UTF8
Set-Content -LiteralPath $promptPath -Value $destinationPrompt -Encoding UTF8
Set-Content -LiteralPath $statusPath -Value $statusTemplate -Encoding UTF8
Write-Host "[handoff-implementation-to-grok] Handoff escrito: $handoffPath" -ForegroundColor Green
Write-Host "[handoff-implementation-to-grok] Reporte para Codex: $statusPath" -ForegroundColor Green
Write-Host '[handoff-implementation-to-grok] Comando sugerido:' -ForegroundColor Cyan
Write-Host $suggestedCommand

if ($Launch) {
  $grokBin = Resolve-GrokBinary
  if ([string]::IsNullOrWhiteSpace($grokBin)) {
    Write-Host '[handoff-implementation-to-grok] No se encontro grok; -Launch omitido.' -ForegroundColor Yellow
  } else {
    & $grokBin --model $GrokModel --cwd $RepoPath --prompt-file $promptPath
    exit $LASTEXITCODE
  }
}
