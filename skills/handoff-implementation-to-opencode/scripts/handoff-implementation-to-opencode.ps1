param(
  [ValidateSet('codex', 'claude')]
  [string] $Invoker = 'codex',
  [string] $Objective = '',
  [string] $ReviewSummary = '',
  [string] $ReviewFile = '',
  [ValidateSet('pass', 'blocked', 'needs-user')]
  [string] $ReviewVerdict = 'pass',
  [string] $Reason = '',
  [string] $NextStep = '',
  [string] $OpenQuestions = '',
  [string] $CommandsExecuted = '',
  [string] $RepoPath = '',
  [string] $OutDir = 'docs',
  [string] $AgentHandoffScript = '',
  [string] $OpenCodeModel = 'opencode-go/glm-5.2',
  [ValidateSet('', 'high', 'max')]
  [string] $OpenCodeVariant = 'max',
  [switch] $SkipReviewGate,
  [switch] $ForceHandoff,
  [switch] $DryRun,
  [switch] $Launch
)

$ErrorActionPreference = 'Stop'

function Invoke-GitSafe {
  param([string] $Repo, [string[]] $GitArgs)
  try {
    $stdout = & git -C $Repo @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($stdout -join "`n")
  } catch {
    return $null
  }
}

function Read-ReviewFile {
  param([string] $Path, [string] $Repo)
  if ([string]::IsNullOrWhiteSpace($Path)) { return '' }

  $reviewPath = $Path
  if (-not [System.IO.Path]::IsPathRooted($reviewPath)) {
    $reviewPath = Join-Path $Repo $reviewPath
  }
  if (-not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) {
    throw "Review file not found: $reviewPath"
  }
  return (Get-Content -Raw -Encoding UTF8 -LiteralPath $reviewPath).Trim()
}

function Normalize-OpenCodeModel {
  param([string] $Model)
  if ([string]::IsNullOrWhiteSpace($Model)) { return 'opencode-go/glm-5.2' }
  $normalized = $Model.Trim()
  $modelAlias = $normalized.ToLowerInvariant() -replace '_', '-' -replace '\s+', ''
  if ($modelAlias -in @('glm', 'glm5.2', 'glm-5.2', 'glm-5-2', 'opencode-go/glm-5-2')) { return 'opencode-go/glm-5.2' }
  return $normalized
}

function Resolve-OpenCodeBinary {
  $candidates = @()
  if ($env:USERPROFILE) { $candidates += (Join-Path $env:USERPROFILE '.bun\bin\opencode.exe') }
  if ($env:HOME) { $candidates += (Join-Path $env:HOME '.bun/bin/opencode') }
  if ($env:APPDATA) { $candidates += (Join-Path $env:APPDATA 'npm\opencode.cmd') }
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }
  $cmd = Get-Command opencode -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  return $null
}

function Convert-ToPromptPath {
  param([string] $Repo, [string] $Path)
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  $repoFull = [System.IO.Path]::GetFullPath($Repo).TrimEnd('\', '/')
  try {
    $repoUri = [System.Uri]::new($repoFull + [System.IO.Path]::DirectorySeparatorChar)
    $pathUri = [System.Uri]::new($pathFull)
    $relative = [System.Uri]::UnescapeDataString($repoUri.MakeRelativeUri($pathUri).ToString())
    $looksAbsolute = $relative -match '^[a-zA-Z][a-zA-Z0-9+.-]*:' -or $relative.StartsWith('/')
    if (-not [string]::IsNullOrWhiteSpace($relative) -and -not $relative.StartsWith('..') -and -not $looksAbsolute) {
      return ($relative -replace '\\', '/')
    }
  } catch {
    # Fall back to the absolute path below.
  }
  return ($pathFull -replace '\\', '/')
}

function Quote-PowerShellArgument {
  param([string] $Value)
  return "'" + ($Value -replace "'", "''") + "'"
}

function Add-Section {
  param(
    [System.Collections.Generic.List[string]] $Lines,
    [string] $Title,
    [string] $Body,
    [string] $EmptyText = '_No reportado._'
  )

  [void] $Lines.Add("## $Title")
  [void] $Lines.Add('')
  if ([string]::IsNullOrWhiteSpace($Body)) {
    [void] $Lines.Add($EmptyText)
  } else {
    foreach ($line in ($Body -split "`r?`n")) { [void] $Lines.Add($line) }
  }
  [void] $Lines.Add('')
}

function Write-HandoffFiles {
  param(
    [string] $Repo,
    [string] $Out,
    [string] $InvokerName,
    [string] $ObjectiveText,
    [string] $ReasonText,
    [string] $NextStepText,
    [string] $OpenQuestionsText,
    [string] $CommandsText,
    [string] $ValidationText,
    [string] $Model,
    [string] $Variant,
    [switch] $Dry,
    [switch] $RunOpenCode
  )

  $branch = Invoke-GitSafe $Repo @('rev-parse', '--abbrev-ref', 'HEAD')
  $head = Invoke-GitSafe $Repo @('rev-parse', 'HEAD')
  $status = Invoke-GitSafe $Repo @('status', '--porcelain')
  $log = Invoke-GitSafe $Repo @('log', '--oneline', '-20')
  $diffStat = Invoke-GitSafe $Repo @('diff', '--stat')
  $diffCachedStat = Invoke-GitSafe $Repo @('diff', '--cached', '--stat')

  $branchLabel = if (-not [string]::IsNullOrWhiteSpace($branch)) { $branch } else { 'no disponible' }
  $headLabel = if (-not [string]::IsNullOrWhiteSpace($head)) { $head } else { 'no disponible' }
  $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  $dateStamp = (Get-Date).ToString('yyyyMMdd')

  $outFull = $Out
  if (-not [System.IO.Path]::IsPathRooted($outFull)) { $outFull = Join-Path $Repo $Out }
  $outPromptPath = Convert-ToPromptPath -Repo $Repo -Path $outFull

  $baseName = "${dateStamp}_HANDOFF-${InvokerName}-to-opencode"
  $handoffName = "$baseName.md"
  $handoffPath = Join-Path $outFull $handoffName
  if ((-not $Dry) -and (Test-Path -LiteralPath $handoffPath)) {
    $seq = 2
    while (Test-Path -LiteralPath (Join-Path $outFull "$baseName-$seq.md")) { $seq++ }
    $handoffName = "$baseName-$seq.md"
    $handoffPath = Join-Path $outFull $handoffName
  }

  $handoffDisplayPath = "$outPromptPath/$handoffName"
  $destPrompt = "Continuas la implementacion que coordina $InvokerName en el repo $Repo. Lee el handoff en $handoffDisplayPath antes de hacer nada. Respeta AGENTS.md y cualquier regla local. Empieza confirmando objetivo, archivos tocados y reglas a respetar. Luego avanza al siguiente paso recomendado. No hagas merge, push ni PR sin autorizacion. No levantes servidores de desarrollo."
  $variantArg = if ([string]::IsNullOrWhiteSpace($Variant)) { '' } else { " --variant $Variant" }
  $suggestedCmd = "opencode run $(Quote-PowerShellArgument $destPrompt) --dir $(Quote-PowerShellArgument $Repo) --model $Model$variantArg --file $(Quote-PowerShellArgument $handoffDisplayPath)"

  $ruleFiles = @('AGENTS.md', 'CLAUDE.md', 'LOCAL_CHANGES.md', 'BITACORA.md')
  $ruleStatus = @()
  foreach ($file in $ruleFiles) {
    $path = Join-Path $Repo $file
    $ruleStatus += "- $file : $(if (Test-Path -LiteralPath $path) { 'presente' } else { 'ausente' })"
  }

  $bitacoraTail = ''
  $bitacoraPath = Join-Path $Repo 'BITACORA.md'
  if (Test-Path -LiteralPath $bitacoraPath) {
    $bitacoraTail = ((Get-Content -LiteralPath $bitacoraPath -Encoding UTF8 | Select-Object -Last 40) -join "`n")
  }

  $md = [System.Collections.Generic.List[string]]::new()
  [void] $md.Add("# Handoff: $InvokerName -> opencode")
  [void] $md.Add('')
  [void] $md.Add("- Fecha: $timestamp")
  [void] $md.Add("- Repo: $Repo")
  [void] $md.Add("- Branch: $branchLabel")
  [void] $md.Add("- Commit actual: $headLabel")
  [void] $md.Add("- Modelo destino: $Model")
  [void] $md.Add("- Variante destino: $(if ([string]::IsNullOrWhiteSpace($Variant)) { 'default' } else { $Variant })")
  [void] $md.Add('')

  Add-Section $md 'Objetivo original' $ObjectiveText '_Pendiente de completar por el agente origen._'
  Add-Section $md 'Motivo del traspaso' $ReasonText '_Pendiente de completar por el agente origen._'

  [void] $md.Add('## Estado actual (hechos comprobados)')
  [void] $md.Add('')
  [void] $md.Add('Capturado automaticamente desde git, no desde la memoria del agente.')
  [void] $md.Add('')
  [void] $md.Add("Branch: $branchLabel")
  [void] $md.Add("HEAD: $headLabel")
  [void] $md.Add('')

  [void] $md.Add('### Archivos modificados o sin confirmar')
  [void] $md.Add('')
  if ([string]::IsNullOrWhiteSpace($status)) {
    [void] $md.Add('_Sin cambios pendientes o git no disponible._')
  } else {
    [void] $md.Add('```text')
    foreach ($line in ($status -split "`r?`n")) { [void] $md.Add($line) }
    [void] $md.Add('```')
  }
  [void] $md.Add('')

  [void] $md.Add('### Historial reciente')
  [void] $md.Add('')
  if ([string]::IsNullOrWhiteSpace($log)) {
    [void] $md.Add('_No disponible._')
  } else {
    [void] $md.Add('```text')
    foreach ($line in ($log -split "`r?`n")) { [void] $md.Add($line) }
    [void] $md.Add('```')
  }
  [void] $md.Add('')

  [void] $md.Add('### Diff sin preparar')
  [void] $md.Add('')
  if ([string]::IsNullOrWhiteSpace($diffStat)) {
    [void] $md.Add('_Sin cambios sin preparar o git no disponible._')
  } else {
    [void] $md.Add('```text')
    foreach ($line in ($diffStat -split "`r?`n")) { [void] $md.Add($line) }
    [void] $md.Add('```')
  }
  [void] $md.Add('')

  [void] $md.Add('### Diff preparado')
  [void] $md.Add('')
  if ([string]::IsNullOrWhiteSpace($diffCachedStat)) {
    [void] $md.Add('_Sin cambios preparados o git no disponible._')
  } else {
    [void] $md.Add('```text')
    foreach ($line in ($diffCachedStat -split "`r?`n")) { [void] $md.Add($line) }
    [void] $md.Add('```')
  }
  [void] $md.Add('')

  Add-Section $md 'Comandos ejecutados' $CommandsText '_No capturado automaticamente._'
  Add-Section $md 'Validaciones' $ValidationText '_No capturado automaticamente._'
  Add-Section $md 'Siguiente paso recomendado' $NextStepText '_Pendiente de completar por el agente origen._'
  Add-Section $md 'Dudas abiertas' $OpenQuestionsText '_Ninguna reportada._'

  [void] $md.Add('## Reglas del repo que debe respetar OpenCode')
  [void] $md.Add('')
  foreach ($rule in $ruleStatus) { [void] $md.Add($rule) }
  [void] $md.Add('')
  [void] $md.Add('OpenCode debe leer los archivos de reglas presentes antes de editar. No debe hacer merge, push, PR, borrar estado ni levantar servidores de desarrollo sin autorizacion explicita.')
  [void] $md.Add('')

  [void] $md.Add('## Cola de BITACORA.md')
  [void] $md.Add('')
  if ([string]::IsNullOrWhiteSpace($bitacoraTail)) {
    [void] $md.Add('_BITACORA.md no encontrada o vacia._')
  } else {
    [void] $md.Add('```markdown')
    foreach ($line in ($bitacoraTail -split "`r?`n")) { [void] $md.Add($line) }
    [void] $md.Add('```')
  }
  [void] $md.Add('')

  [void] $md.Add('## Prompt para OpenCode')
  [void] $md.Add('')
  [void] $md.Add('```text')
  [void] $md.Add($destPrompt)
  [void] $md.Add('```')
  [void] $md.Add('')

  $mdText = $md -join "`n"
  $promptFileName = [System.IO.Path]::GetFileNameWithoutExtension($handoffName) + '-prompt.txt'
  $promptPath = Join-Path $outFull $promptFileName

  if ($Dry) {
    Write-Host '[handoff-implementation-to-opencode] Dry run: no se escriben archivos.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host $mdText
    Write-Host ''
    Write-Host '[handoff-implementation-to-opencode] Comando sugerido:' -ForegroundColor Cyan
    Write-Host $suggestedCmd
    return
  }

  if (-not (Test-Path -LiteralPath $outFull)) {
    New-Item -ItemType Directory -Path $outFull | Out-Null
  }
  Set-Content -LiteralPath $handoffPath -Value $mdText -Encoding UTF8
  Set-Content -LiteralPath $promptPath -Value $destPrompt -Encoding UTF8

  $indexPath = Join-Path $outFull 'HANDOFF-index.md'
  $objectiveLine = if ([string]::IsNullOrWhiteSpace($ObjectiveText)) { '(sin objetivo)' } else { ($ObjectiveText -split "`r?`n")[0] }
  if ($objectiveLine.Length -gt 80) { $objectiveLine = $objectiveLine.Substring(0, 77) + '...' }
  $indexEntry = "- $timestamp - $InvokerName -> opencode - [$handoffName]($handoffName) - objetivo: $objectiveLine"
  if (Test-Path -LiteralPath $indexPath) {
    $existing = Get-Content -LiteralPath $indexPath -Encoding UTF8
    $newLines = [System.Collections.Generic.List[string]]::new()
    $inserted = $false
    foreach ($line in $existing) {
      if (-not $inserted -and $line.StartsWith('- ')) {
        [void] $newLines.Add($indexEntry)
        $inserted = $true
      }
      [void] $newLines.Add($line)
    }
    if (-not $inserted) { [void] $newLines.Add($indexEntry) }
    Set-Content -LiteralPath $indexPath -Value ($newLines -join "`n") -Encoding UTF8
  } else {
    Set-Content -LiteralPath $indexPath -Value "# Handoff index`n`nRegistro de traspasos en este repo. El mas reciente arriba.`n`n$indexEntry`n" -Encoding UTF8
  }

  Write-Host "[handoff-implementation-to-opencode] Handoff escrito: $handoffPath" -ForegroundColor Green
  Write-Host "[handoff-implementation-to-opencode] Prompt escrito: $promptPath" -ForegroundColor Green
  Write-Host "[handoff-implementation-to-opencode] Indice actualizado: $indexPath" -ForegroundColor Green
  Write-Host ''
  Write-Host '[handoff-implementation-to-opencode] Comando sugerido:' -ForegroundColor Cyan
  Write-Host $suggestedCmd

  if ($RunOpenCode) {
    $opencodeBin = Resolve-OpenCodeBinary
    if ([string]::IsNullOrWhiteSpace($opencodeBin)) {
      Write-Host '[handoff-implementation-to-opencode] No se encontro binario opencode; -Launch omitido.' -ForegroundColor Yellow
      return
    }

    Write-Host "[handoff-implementation-to-opencode] Ejecutando opencode: $opencodeBin" -ForegroundColor Cyan
    $launchArgs = @('run', $destPrompt, '--dir', $Repo, '--model', $Model)
    if (-not [string]::IsNullOrWhiteSpace($Variant)) { $launchArgs += @('--variant', $Variant) }
    $launchArgs += @('--file', $handoffPath)
    & $opencodeBin @launchArgs
    exit $LASTEXITCODE
  }
}

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
  $RepoPath = (Get-Location).Path
}
if (-not (Test-Path -LiteralPath $RepoPath -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$RepoPath = (Resolve-Path -LiteralPath $RepoPath).Path

if (-not [string]::IsNullOrWhiteSpace($AgentHandoffScript)) {
  Write-Host '[handoff-implementation-to-opencode] -AgentHandoffScript is ignored; this skill is self-contained.' -ForegroundColor Yellow
}

$fileSummary = Read-ReviewFile -Path $ReviewFile -Repo $RepoPath
if ([string]::IsNullOrWhiteSpace($ReviewSummary) -and -not [string]::IsNullOrWhiteSpace($fileSummary)) {
  $ReviewSummary = $fileSummary
}

if (-not $SkipReviewGate -and [string]::IsNullOrWhiteSpace($ReviewSummary)) {
  throw 'Review gate missing. Provide -ReviewSummary or -ReviewFile, or pass -SkipReviewGate explicitly.'
}

if (($ReviewVerdict -ne 'pass') -and -not $ForceHandoff) {
  throw "Review verdict is '$ReviewVerdict'. Handoff blocked unless -ForceHandoff is passed."
}

if ([string]::IsNullOrWhiteSpace($Objective)) {
  $Objective = "Continue implementation under OpenCode GLM-5.2 with $Invoker retaining review ownership."
}
if ([string]::IsNullOrWhiteSpace($Reason)) {
  $Reason = "$Invoker remains principal coordinator/reviewer; OpenCode GLM-5.2 continues implementation after review gate."
}
if ([string]::IsNullOrWhiteSpace($NextStep)) {
  $NextStep = "Read the handoff, preserve existing work, implement the next scoped change, and leave validation results for $Invoker review."
}

$reviewText = if ($SkipReviewGate -and [string]::IsNullOrWhiteSpace($ReviewSummary)) {
  "Review gate explicitly skipped by the invoking $Invoker agent."
} else {
  "Review verdict: $ReviewVerdict`n`n$ReviewSummary"
}

$commandsText = if ([string]::IsNullOrWhiteSpace($CommandsExecuted)) {
  'handoff-implementation-to-opencode wrapper executed; see current session for any manual review commands.'
} else {
  $CommandsExecuted
}

$OpenCodeModel = Normalize-OpenCodeModel $OpenCodeModel

Write-Host "[handoff-implementation-to-opencode] Review verdict: $ReviewVerdict" -ForegroundColor Cyan
Write-Host "[handoff-implementation-to-opencode] Invoker: $Invoker" -ForegroundColor Cyan
Write-Host "[handoff-implementation-to-opencode] Destination: OpenCode ($OpenCodeModel, variant=$OpenCodeVariant)" -ForegroundColor Cyan
Write-Host '[handoff-implementation-to-opencode] Mode: self-contained handoff writer' -ForegroundColor DarkGray

Write-HandoffFiles `
  -Repo $RepoPath `
  -Out $OutDir `
  -InvokerName $Invoker `
  -ObjectiveText $Objective `
  -ReasonText $Reason `
  -NextStepText $NextStep `
  -OpenQuestionsText $OpenQuestions `
  -CommandsText $commandsText `
  -ValidationText $reviewText `
  -Model $OpenCodeModel `
  -Variant $OpenCodeVariant `
  -Dry:$DryRun `
  -RunOpenCode:$Launch

exit 0
