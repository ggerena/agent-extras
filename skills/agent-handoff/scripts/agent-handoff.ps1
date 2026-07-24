param(
  [ValidateSet('codex', 'claude', 'opencode', 'grok')]
  [string] $From = 'codex',
  [ValidateSet('codex', 'claude', 'opencode', 'grok')]
  [string] $To = 'opencode',
  [string] $Objective = '',
  [string] $Reason = '',
  [string] $NextStep = '',
  [string] $OpenQuestions = '',
  [string] $CommandsExecuted = '',
  [string] $Validations = '',
  [string] $Blockers = '',
  [string] $NotesFile = '',
  [string] $OutDir = 'docs',
  [string] $RepoPath = '',
  [string] $OpenCodeModel = 'opencode-go/glm-5.2',
  [ValidateSet('', 'high', 'max')]
  [string] $OpenCodeVariant = 'max',
  [string] $ClaudeModel = 'claude-opus-4-8',
  [ValidateSet('low', 'medium', 'high', 'max')]
  [string] $ClaudeEffort = 'medium',
  [string] $ClaudePermissionMode = 'plan',
  [string] $GrokModel = 'grok-4.5',
  [int] $BitacoraTail = 40,
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

function Parse-NotesSections {
  param([string] $Path)
  $result = @{}
  if (-not (Test-Path -LiteralPath $Path)) { return $result }
  $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
  $lines = $raw -split "`r?`n"
  $current = $null
  $buffer = New-Object System.Collections.Generic.List[string]
  foreach ($line in $lines) {
    if ($line -match '^##\s+(.+?)\s*$') {
      if ($null -ne $current) { $result[$current] = (($buffer -join "`n").Trim()) }
      $current = $Matches[1].Trim()
      $buffer.Clear()
    } else {
      if ($null -ne $current) { [void] $buffer.Add($line) }
    }
  }
  if ($null -ne $current) { $result[$current] = (($buffer -join "`n").Trim()) }
  return $result
}

function Get-NotesField {
  param([hashtable] $Notes, [string[]] $Keys)
  foreach ($key in $Notes.Keys) {
    $lower = $key.ToLowerInvariant().Trim()
    foreach ($candidate in $Keys) {
      if ($lower -eq $candidate) { return $Notes[$key] }
    }
  }
  return ''
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
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  $cmd = Get-Command opencode -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  return $null
}

function Resolve-GrokBinary {
  $candidates = @()
  if ($env:USERPROFILE) { $candidates += (Join-Path $env:USERPROFILE '.grok\bin\grok.exe') }
  if ($env:HOME) { $candidates += (Join-Path $env:HOME '.grok/bin/grok') }
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  $cmd = Get-Command grok -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
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

function Quote-PowerShellExpandableArgument {
  param([string] $Value)
  return '"' + ($Value -replace '`', '``' -replace '"', '`"') + '"'
}

if ([string]::IsNullOrWhiteSpace($RepoPath)) { $RepoPath = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $RepoPath -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}

$notes = @{}
if (-not [string]::IsNullOrWhiteSpace($NotesFile)) {
  $notesPath = $NotesFile
  if (-not [System.IO.Path]::IsPathRooted($notesPath)) { $notesPath = (Join-Path $RepoPath $notesPath) }
  if (-not (Test-Path -LiteralPath $notesPath)) {
    throw "Notes file not found: $notesPath"
  }
  $notes = Parse-NotesSections -Path $notesPath
}

if ([string]::IsNullOrWhiteSpace($Objective)) { $Objective = Get-NotesField $notes @('objetivo', 'objetivo original') }
if ([string]::IsNullOrWhiteSpace($Reason)) { $Reason = Get-NotesField $notes @('motivo', 'motivo del traspaso') }
if ([string]::IsNullOrWhiteSpace($NextStep)) { $NextStep = Get-NotesField $notes @('siguiente paso', 'siguiente paso recomendado') }
if ([string]::IsNullOrWhiteSpace($OpenQuestions)) { $OpenQuestions = Get-NotesField $notes @('dudas', 'dudas abiertas') }
if ([string]::IsNullOrWhiteSpace($CommandsExecuted)) { $CommandsExecuted = Get-NotesField $notes @('comandos ejecutados', 'comandos') }
if ([string]::IsNullOrWhiteSpace($Validations)) { $Validations = Get-NotesField $notes @('validaciones') }
if ([string]::IsNullOrWhiteSpace($Blockers)) { $Blockers = Get-NotesField $notes @('problemas o bloqueos', 'problemas', 'bloqueos') }

$branch = Invoke-GitSafe $RepoPath @('rev-parse', '--abbrev-ref', 'HEAD')
$head = Invoke-GitSafe $RepoPath @('rev-parse', 'HEAD')
$status = Invoke-GitSafe $RepoPath @('status', '--porcelain')
$log = Invoke-GitSafe $RepoPath @('log', '--oneline', '-20')
$diffStat = Invoke-GitSafe $RepoPath @('diff', '--stat')
$diffCachedStat = Invoke-GitSafe $RepoPath @('diff', '--cached', '--stat')

$gitAvailable = -not [string]::IsNullOrWhiteSpace($branch)
$branchLabel = if ($gitAvailable) { $branch } else { 'no disponible (repo sin git o git no encontrado)' }
$headLabel = if (-not [string]::IsNullOrWhiteSpace($head)) { $head } else { 'no disponible' }

$ruleFiles = @('AGENTS.md', 'CLAUDE.md', 'LOCAL_CHANGES.md', 'BITACORA.md')
$ruleStatus = @()
foreach ($f in $ruleFiles) {
  $p = Join-Path $RepoPath $f
  $exists = Test-Path -LiteralPath $p
  $ruleStatus += "- $f : $(if ($exists) { 'presente' } else { 'ausente' })"
}

$bitacoraTailText = ''
$bitacoraPath = Join-Path $RepoPath 'BITACORA.md'
if (Test-Path -LiteralPath $bitacoraPath) {
  $bitLines = Get-Content -LiteralPath $bitacoraPath -Encoding UTF8
  $tail = $bitLines | Select-Object -Last $BitacoraTail
  $bitacoraTailText = ($tail -join "`n")
}

$timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm')
$dateStamp = (Get-Date).ToString('yyyyMMdd')

$outDirFull = $OutDir
if (-not [System.IO.Path]::IsPathRooted($outDirFull)) { $outDirFull = (Join-Path $RepoPath $OutDir) }
$outDirPromptPath = Convert-ToPromptPath -Repo $RepoPath -Path $outDirFull

$baseName = "${dateStamp}_HANDOFF-${From}-to-${To}"
$handoffName = "${baseName}.md"
$handoffPath = Join-Path $outDirFull $handoffName
if (Test-Path -LiteralPath $handoffPath) {
  $seq = 2
  while (Test-Path -LiteralPath (Join-Path $outDirFull "${baseName}-${seq}.md")) { $seq++ }
  $handoffName = "${baseName}-${seq}.md"
  $handoffPath = Join-Path $outDirFull $handoffName
}

function Format-Section {
  param([string] $Title, [string] $Body)
  if ([string]::IsNullOrWhiteSpace($Body)) { return @() }
  $lines = @("## $Title", '', ($Body -split "`r?`n"), '')
  return $lines
}

$md = New-Object System.Collections.Generic.List[string]
[void] $md.Add("# Handoff: $From -> $To")
[void] $md.Add('')
[void] $md.Add("- Fecha: $timestamp")
[void] $md.Add("- Repo: $RepoPath")
[void] $md.Add("- Branch: $branchLabel")
[void] $md.Add("- Commit actual: $headLabel")
[void] $md.Add('')
[void] $md.Add('## Objetivo original')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($Objective)) {
  [void] $md.Add('_Pendiente de completar por el agente origen._')
} else {
  foreach ($l in ($Objective -split "`r?`n")) { [void] $md.Add($l) }
}
[void] $md.Add('')
[void] $md.Add('## Motivo del traspaso')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($Reason)) {
  [void] $md.Add('_Pendiente de completar por el agente origen. Si el traspaso ocurre porque el agente se perdio, decirlo aqui._')
} else {
  foreach ($l in ($Reason -split "`r?`n")) { [void] $md.Add($l) }
}
[void] $md.Add('')
[void] $md.Add('## Estado actual (hechos comprobados)')
[void] $md.Add('')
[void] $md.Add('Capturado automaticamente desde git, no desde la memoria del agente.')
[void] $md.Add('')
[void] $md.Add("- Branch: $branchLabel")
[void] $md.Add("- HEAD: $headLabel")
[void] $md.Add('')
[void] $md.Add('### Archivos modificados o sin confirmar (git status --porcelain)')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($status)) {
  [void] $md.Add('_Sin cambios pendientes o git no disponible._')
} else {
  [void] $md.Add('```text')
  foreach ($l in ($status -split "`r?`n")) { [void] $md.Add($l) }
  [void] $md.Add('```')
}
[void] $md.Add('')
[void] $md.Add('### Historial reciente (git log --oneline -20)')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($log)) {
  [void] $md.Add('_No disponible._')
} else {
  [void] $md.Add('```text')
  foreach ($l in ($log -split "`r?`n")) { [void] $md.Add($l) }
  [void] $md.Add('```')
}
[void] $md.Add('')
[void] $md.Add('### Cambios sin confirmar (git diff --stat)')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($diffStat)) {
  [void] $md.Add('_Sin cambios sin confirmar o git no disponible._')
} else {
  [void] $md.Add('```text')
  foreach ($l in ($diffStat -split "`r?`n")) { [void] $md.Add($l) }
  [void] $md.Add('```')
}
[void] $md.Add('')
[void] $md.Add('### Cambios preparados (git diff --cached --stat)')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($diffCachedStat)) {
  [void] $md.Add('_Sin cambios preparados o git no disponible._')
} else {
  [void] $md.Add('```text')
  foreach ($l in ($diffCachedStat -split "`r?`n")) { [void] $md.Add($l) }
  [void] $md.Add('```')
}
[void] $md.Add('')
[void] $md.Add('## Comandos ejecutados')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($CommandsExecuted)) {
  [void] $md.Add('_No capturado automaticamente. El agente origen puede completar a mano los comandos relevantes que ya corrio._')
} else {
  foreach ($l in ($CommandsExecuted -split "`r?`n")) { [void] $md.Add($l) }
}
[void] $md.Add('')
[void] $md.Add('## Validaciones')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($Validations)) {
  [void] $md.Add('_No capturado automaticamente. El agente origen puede completar a mano las validaciones ya hechas._')
} else {
  foreach ($l in ($Validations -split "`r?`n")) { [void] $md.Add($l) }
}
[void] $md.Add('')
[void] $md.Add('## Problemas o bloqueos')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($Blockers)) {
  [void] $md.Add('_Ninguno reportado._')
} else {
  foreach ($l in ($Blockers -split "`r?`n")) { [void] $md.Add($l) }
}
[void] $md.Add('')
[void] $md.Add('## Decisiones tomadas (cola de BITACORA.md)')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($bitacoraTailText)) {
  [void] $md.Add('_BITACORA.md no encontrada o vacia._')
} else {
  [void] $md.Add("Ultimas $BitacoraTail lineas de BITACORA.md:")
  [void] $md.Add('')
  [void] $md.Add('```markdown')
  foreach ($l in ($bitacoraTailText -split "`r?`n")) { [void] $md.Add($l) }
  [void] $md.Add('```')
}
[void] $md.Add('')
[void] $md.Add('## Reglas del repo que debe respetar el agente destino')
[void] $md.Add('')
[void] $md.Add('Archivos de reglas detectados en la raiz del repo:')
[void] $md.Add('')
foreach ($r in $ruleStatus) { [void] $md.Add($r) }
[void] $md.Add('')
[void] $md.Add('El agente destino debe leer AGENTS.md y CLAUDE.md antes de hacer cambios. Respetar en particular: no hacer merge ni push sin autorizacion, no levantar servidores de desarrollo, no borrar archivos o estado sin confirmacion, mantener el traspaso factual y no esconder errores.')
[void] $md.Add('')
[void] $md.Add('## Siguiente paso recomendado')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($NextStep)) {
  [void] $md.Add('_Pendiente de completar por el agente origen._')
} else {
  foreach ($l in ($NextStep -split "`r?`n")) { [void] $md.Add($l) }
}
[void] $md.Add('')
[void] $md.Add('## Dudas abiertas')
[void] $md.Add('')
if ([string]::IsNullOrWhiteSpace($OpenQuestions)) {
  [void] $md.Add('_Ninguna reportada._')
} else {
  foreach ($l in ($OpenQuestions -split "`r?`n")) { [void] $md.Add($l) }
}
[void] $md.Add('')

$handoffPromptPath = "$outDirPromptPath/$handoffName"
$promptObj = "Continuas el trabajo que dejo $From en el repo $RepoPath."
$promptRead = "Lee el handoff en $handoffPromptPath antes de hacer nada."
$promptRules = "Respeta las reglas del repo en AGENTS.md y CLAUDE.md."
$promptConfirm = "Empieza confirmando en una linea: objetivo, archivos tocados y reglas a respetar."
$promptNext = "Luego avanza al siguiente paso recomendado del handoff."
$promptGuard = "No pisar el trabajo ya hecho. No hacer merge ni push sin autorizacion. No levantar servidores de desarrollo."
$destPrompt = "$promptObj $promptRead $promptRules $promptConfirm $promptNext $promptGuard"

[void] $md.Add('## Prompt para el agente destino')
[void] $md.Add('')
[void] $md.Add('```text')
[void] $md.Add($destPrompt)
[void] $md.Add('```')
[void] $md.Add('')

$mdText = ($md -join "`n")

$OpenCodeModel = Normalize-OpenCodeModel $OpenCodeModel
$opencodeBin = Resolve-OpenCodeBinary
$grokBin = Resolve-GrokBinary
$promptFileName = "${baseName}-prompt.txt"
if ($handoffName -ne "${baseName}.md") {
  $seqMatch = [regex]::Match($handoffName, '-(\d+)\.md$')
  if ($seqMatch.Success) { $promptFileName = "${baseName}-$($seqMatch.Groups[1].Value)-prompt.txt" }
}
$promptDisplayPath = "$outDirPromptPath/$promptFileName"
$handoffDisplayPath = "$outDirPromptPath/$handoffName"
$sessionName = "handoff $From-to-$To $dateStamp"
$variantArg = if ([string]::IsNullOrWhiteSpace($OpenCodeVariant)) { '' } else { " --variant $OpenCodeVariant" }
$suggestedCmd = "opencode run $(Quote-PowerShellArgument $destPrompt) --dir $(Quote-PowerShellArgument $RepoPath) --model $OpenCodeModel$variantArg --file $(Quote-PowerShellArgument $handoffDisplayPath)"
if ($To -eq 'opencode') {
  $launchCmd = $suggestedCmd
} elseif ($To -eq 'claude') {
  $claudePermissionArg = if ([string]::IsNullOrWhiteSpace($ClaudePermissionMode)) { '' } else { " --permission-mode $(Quote-PowerShellArgument $ClaudePermissionMode)" }
  $promptSubexpression = Quote-PowerShellExpandableArgument "`$(Get-Content -Raw -LiteralPath $(Quote-PowerShellArgument $promptDisplayPath))"
  $launchCmd = "claude --model $(Quote-PowerShellArgument $ClaudeModel) --effort $(Quote-PowerShellArgument $ClaudeEffort)$claudePermissionArg --add-dir $(Quote-PowerShellArgument $RepoPath) --name $(Quote-PowerShellArgument $sessionName) $promptSubexpression"
} elseif ($To -eq 'grok') {
  $launchCmd = "grok --model $(Quote-PowerShellArgument $GrokModel) --cwd $(Quote-PowerShellArgument $RepoPath) --prompt-file $(Quote-PowerShellArgument $promptDisplayPath)"
} else {
  $launchCmd = "Get-Content -Raw -LiteralPath $(Quote-PowerShellArgument $promptDisplayPath) | codex exec --sandbox read-only -m gpt-5.5 -c model_reasoning_effort=`"xhigh`""
}

if ($DryRun) {
  Write-Host "[agent-handoff] Dry run: no se escriben archivos." -ForegroundColor Yellow
  Write-Host ''
  Write-Host $mdText
  Write-Host ''
  Write-Host '[agent-handoff] Prompt sugerido para el agente destino:' -ForegroundColor Cyan
  Write-Host $destPrompt
  Write-Host ''
  Write-Host '[agent-handoff] Comando sugerido:' -ForegroundColor Cyan
  Write-Host $launchCmd
  exit 0
}

if (-not (Test-Path -LiteralPath $outDirFull)) {
  New-Item -ItemType Directory -Path $outDirFull | Out-Null
}

Set-Content -LiteralPath $handoffPath -Value $mdText -Encoding UTF8
Write-Host "[agent-handoff] Handoff escrito: $handoffPath" -ForegroundColor Green

$promptFilePath = Join-Path $outDirFull $promptFileName
Set-Content -LiteralPath $promptFilePath -Value $destPrompt -Encoding UTF8
Write-Host "[agent-handoff] Prompt escrito: $promptFilePath" -ForegroundColor Green

$indexPath = Join-Path $outDirFull 'HANDOFF-index.md'
$objectiveLine = if ([string]::IsNullOrWhiteSpace($Objective)) { '(sin objetivo)' } else { ($Objective -split "`r?`n")[0] }
if ($objectiveLine.Length -gt 80) { $objectiveLine = $objectiveLine.Substring(0, 77) + '...' }
$indexEntry = "- $timestamp - $From -> $To - [$handoffName]($handoffName) - objetivo: $objectiveLine"
if (Test-Path -LiteralPath $indexPath) {
  $existingLines = Get-Content -LiteralPath $indexPath -Encoding UTF8
  $inserted = $false
  $newLines = New-Object System.Collections.Generic.List[string]
  foreach ($line in $existingLines) {
    if (-not $inserted -and $line.StartsWith('- ')) {
      [void] $newLines.Add($indexEntry)
      $inserted = $true
    }
    [void] $newLines.Add($line)
  }
  if (-not $inserted) { [void] $newLines.Add($indexEntry) }
  Set-Content -LiteralPath $indexPath -Value ($newLines -join "`n") -Encoding UTF8
} else {
  $newContent = @"
# Handoff index

Registro de traspasos en este repo. El mas reciente arriba.

$indexEntry
"@
  Set-Content -LiteralPath $indexPath -Value $newContent -Encoding UTF8
}
Write-Host "[agent-handoff] Indice actualizado: $indexPath" -ForegroundColor Green

Write-Host ''
Write-Host '[agent-handoff] Prompt para el agente destino:' -ForegroundColor Cyan
Write-Host $destPrompt
Write-Host ''
Write-Host '[agent-handoff] Comando sugerido:' -ForegroundColor Cyan
Write-Host $launchCmd
Write-Host ''
if ($To -eq 'claude') {
  Write-Host '[agent-handoff] Claude Code se inicia en modo interactivo y la sesion queda nombrada para /resume.' -ForegroundColor DarkGray
} elseif ($To -eq 'opencode') {
  Write-Host '[agent-handoff] opencode run registra una sesion visible en OpenCode Desktop. Abre Desktop y continua esa sesion; no hace falta abrir otra ventana de PowerShell.' -ForegroundColor DarkGray
} elseif ($To -eq 'grok') {
  Write-Host '[agent-handoff] El comando inicia una sesion interactiva de Grok Build en el repo. Usa los permisos normales de Grok; no agrega aprobacion automatica.' -ForegroundColor DarkGray
}

if ($Launch -and $To -eq 'opencode') {
  if ([string]::IsNullOrWhiteSpace($opencodeBin)) {
    Write-Host "[agent-handoff] No se encontro binario opencode; -Launch omitido." -ForegroundColor Yellow
  } else {
    Write-Host "[agent-handoff] Ejecutando opencode (no interactivo): $opencodeBin" -ForegroundColor Cyan
    $launchArgs = @('run', $destPrompt, '--dir', $RepoPath, '--model', $OpenCodeModel)
    if (-not [string]::IsNullOrWhiteSpace($OpenCodeVariant)) { $launchArgs += @('--variant', $OpenCodeVariant) }
    $launchArgs += @('--file', $handoffPath)
    & $opencodeBin @launchArgs
    exit $LASTEXITCODE
  }
} elseif ($Launch -and $To -eq 'grok') {
  if ([string]::IsNullOrWhiteSpace($grokBin)) {
    Write-Host "[agent-handoff] No se encontro binario grok; -Launch omitido." -ForegroundColor Yellow
  } else {
    Write-Host "[agent-handoff] Ejecutando Grok Build interactivo: $grokBin" -ForegroundColor Cyan
    & $grokBin --model $GrokModel --cwd $RepoPath --prompt-file $promptFilePath
    exit $LASTEXITCODE
  }
}

exit 0
