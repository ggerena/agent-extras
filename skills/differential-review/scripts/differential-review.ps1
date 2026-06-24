param(
  [string] $AnalysisFile,
  [string] $Prompt,
  [Alias('PR')]
  [string] $PullRequest = $(if ($env:DIFF_REVIEW_PULL_REQUEST) { $env:DIFF_REVIEW_PULL_REQUEST } else { '' }),
  [ValidateSet('codex', 'claude', 'opencode')]
  [string] $Reviewer = $(if ($env:DIFF_REVIEW_REVIEWER) { $env:DIFF_REVIEW_REVIEWER } else { 'codex' }),
  [ValidateSet('', 'codex', 'claude', 'opencode')]
  [string] $Invoker = $(if ($env:DIFF_REVIEW_INVOKER) { $env:DIFF_REVIEW_INVOKER } else { '' }),
  [switch] $AllowSelfReview,
  [string] $Profile = $(if ($env:DIFF_REVIEW_PROFILE) { $env:DIFF_REVIEW_PROFILE } else { '' }),
  [string] $CodexPath = $(if ($env:DIFF_REVIEW_CODEX_PATH) { $env:DIFF_REVIEW_CODEX_PATH } else { '' }),
  [string] $CodexModel = $(if ($env:DIFF_REVIEW_CODEX_MODEL) { $env:DIFF_REVIEW_CODEX_MODEL } else { 'gpt-5.5' }),
  [ValidateSet('minimal', 'low', 'medium', 'high', 'xhigh')]
  [string] $CodexReasoningEffort = $(if ($env:DIFF_REVIEW_CODEX_REASONING_EFFORT) { $env:DIFF_REVIEW_CODEX_REASONING_EFFORT } else { 'xhigh' }),
  [string] $ClaudePath = $(if ($env:DIFF_REVIEW_CLAUDE_PATH) { $env:DIFF_REVIEW_CLAUDE_PATH } else { '' }),
  [string] $OpenCodePath = $(if ($env:DIFF_REVIEW_OPENCODE_PATH) { $env:DIFF_REVIEW_OPENCODE_PATH } else { '' }),
  [string] $OpenCodeModel = $(if ($env:DIFF_REVIEW_OPENCODE_MODEL) { $env:DIFF_REVIEW_OPENCODE_MODEL } else { 'opencode-go/glm-5.2' }),
  [ValidateSet('', 'high', 'max')]
  [string] $OpenCodeVariant = $(if ($env:DIFF_REVIEW_OPENCODE_VARIANT) { $env:DIFF_REVIEW_OPENCODE_VARIANT } else { 'max' }),
  [string] $ClaudeModel = $(if ($env:DIFF_REVIEW_CLAUDE_MODEL) { $env:DIFF_REVIEW_CLAUDE_MODEL } else { 'claude-opus-4-8' }),
  [ValidateSet('low', 'medium', 'high', 'max')]
  [string] $ClaudeEffort = $(if ($env:DIFF_REVIEW_CLAUDE_EFFORT) { $env:DIFF_REVIEW_CLAUDE_EFFORT } else { 'max' }),
  [switch] $ClaudeBare,
  [string] $ClaudeSettings = $(if ($env:DIFF_REVIEW_CLAUDE_SETTINGS) { $env:DIFF_REVIEW_CLAUDE_SETTINGS } else { '' }),
  [switch] $PrintPromptOnly,
  [switch] $KeepOutputFile,
  [string[]] $ExtraArgs
)

$ErrorActionPreference = 'Stop'

# Carpeta temporal portable: en Windows resuelve a %TEMP%, en macOS/Linux a $TMPDIR (o /tmp).
# $tempRoot no existe fuera de Windows, asi que Join-Path $tempRoot fallaria en macOS/Linux.
$tempRoot = [System.IO.Path]::GetTempPath()

function Resolve-ExecutablePath {
  param(
    [string] $ExplicitPath,
    [string] $CommandName,
    [string[]] $GlobCandidates = @(),
    [switch] $RejectWindowsAppsAlias,
    [switch] $PreferGlobCandidates
  )

  if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
    if (Test-Path -LiteralPath $ExplicitPath) {
      $resolved = (Resolve-Path -LiteralPath $ExplicitPath).Path
      if ($RejectWindowsAppsAlias -and ($resolved -like '*\WindowsApps\*')) {
        throw "$CommandName resolved to the WindowsApps alias, which may fail with Access denied: $resolved. Set the matching DIFF_REVIEW_*_PATH variable to the real binary."
      }
      return $resolved
    }
    throw "$CommandName binary not found at: $ExplicitPath"
  }

  if ($PreferGlobCandidates) {
    foreach ($glob in $GlobCandidates) {
      $match = Get-ChildItem -Path $glob -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
      if ($match) {
        return $match.FullName
      }
    }
  }

  $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandType -eq 'Application' } |
    Select-Object -First 1
  if ($cmd -and $cmd.Source) {
    if (-not ($RejectWindowsAppsAlias -and ($cmd.Source -like '*\WindowsApps\*'))) {
      return $cmd.Source
    }
  }

  foreach ($glob in $GlobCandidates) {
    $match = Get-ChildItem -Path $glob -ErrorAction SilentlyContinue |
      Where-Object { -not $_.PSIsContainer } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($match) {
      return $match.FullName
    }
  }

  $hint = switch ($CommandName) {
    'codex' { 'DIFF_REVIEW_CODEX_PATH' }
    'claude' { 'DIFF_REVIEW_CLAUDE_PATH' }
    'opencode' { 'DIFF_REVIEW_OPENCODE_PATH' }
    default { 'PATH' }
  }
  throw "$CommandName binary not found. Install it, add it to PATH, or set $hint to the real executable path."
}

function Get-ExecutableVersion {
  param([string] $Path)

  try {
    $versionText = & $Path --version 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($versionText)) {
      return (($versionText | Select-Object -First 1).ToString().Trim())
    }
  } catch {
  }

  return ''
}

function Normalize-OpenCodeModel {
  param([string] $Model)

  if ([string]::IsNullOrWhiteSpace($Model)) {
    return 'opencode-go/glm-5.2'
  }

  $normalized = $Model.Trim()
  if ($normalized -eq 'glm-5.2') {
    return 'opencode-go/glm-5.2'
  }

  return $normalized
}

function Resolve-InvokerAgent {
  param([string] $ExplicitInvoker)

  if (-not [string]::IsNullOrWhiteSpace($ExplicitInvoker)) {
    return $ExplicitInvoker.Trim().ToLowerInvariant()
  }

  if ($env:CODEX_SHELL -or $env:CODEX_THREAD_ID -or $env:CODEX_INTERNAL_ORIGINATOR_OVERRIDE) {
    return 'codex'
  }

  if ($env:CLAUDECODE -or $env:CLAUDE_CODE -or $env:CLAUDE_PROJECT_DIR -or $env:CLAUDE_SESSION_ID) {
    return 'claude'
  }

  if ($env:OPENCODE_SESSION_ID -or $env:OPENCODE_AGENT -or $env:OPENCODE_WORKSPACE -or $env:OPENCODE_PROJECT) {
    return 'opencode'
  }

  return ''
}

function Get-ReadOnlyCommandOutput {
  param(
    [string] $CommandName,
    [string[]] $Arguments
  )

  $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandType -eq 'Application' } |
    Select-Object -First 1

  if (-not $cmd -or -not $cmd.Source) {
    return ''
  }

  try {
    $output = & $cmd.Source @Arguments 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($output)) {
      return (($output | Out-String).Trim())
    }
  } catch {
  }

  return ''
}

function Get-RepositorySummary {
  param([string] $WorkingDirectory)

  $lines = @("- Working directory: $WorkingDirectory")
  $gitRoot = Get-ReadOnlyCommandOutput 'git' @('-C', $WorkingDirectory, 'rev-parse', '--show-toplevel')
  if (-not [string]::IsNullOrWhiteSpace($gitRoot)) {
    $lines += "- Git root: $gitRoot"
  }

  $branch = Get-ReadOnlyCommandOutput 'git' @('-C', $WorkingDirectory, 'branch', '--show-current')
  if (-not [string]::IsNullOrWhiteSpace($branch)) {
    $lines += "- Current branch: $branch"
  }

  return ($lines -join "`n")
}

function Get-PullRequestSummary {
  param(
    [string] $Selector,
    [string] $WorkingDirectory
  )

  $selectorLabel = if ([string]::IsNullOrWhiteSpace($Selector)) { 'auto' } else { $Selector.Trim() }
  $lines = @(
    "- PR selector: $selectorLabel",
    "- Wrapper included no PR diff in this prompt."
  )

  $gh = Get-Command 'gh' -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandType -eq 'Application' } |
    Select-Object -First 1

  if (-not $gh -or -not $gh.Source) {
    $lines += "- GitHub CLI: unavailable to wrapper; reviewer should inspect with its own read-only tools if available."
    return ($lines -join "`n")
  }

  $ghArgs = @('pr', 'view')
  if ($selectorLabel -ne 'auto') {
    $ghArgs += $selectorLabel
  }
  $ghArgs += @(
    '--json',
    'number,url,title,state,isDraft,baseRefName,headRefName,author,reviewDecision,mergeable,changedFiles,additions,deletions'
  )

  try {
    Push-Location -LiteralPath $WorkingDirectory
    $jsonText = & $gh.Source @ghArgs 2>$null
    $exitCode = $LASTEXITCODE
  } catch {
    $jsonText = ''
    $exitCode = 1
  } finally {
    Pop-Location -ErrorAction SilentlyContinue
  }

  if ($exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($jsonText)) {
    $lines += "- GitHub CLI: could not resolve PR metadata from wrapper context."
    return ($lines -join "`n")
  }

  try {
    $pr = (($jsonText | Out-String).Trim()) | ConvertFrom-Json -ErrorAction Stop
  } catch {
    $lines += "- GitHub CLI: returned metadata that could not be parsed."
    return ($lines -join "`n")
  }

  if ($null -ne $pr.number) { $lines += "- Number: #$($pr.number)" }
  if (-not [string]::IsNullOrWhiteSpace($pr.url)) { $lines += "- URL: $($pr.url)" }
  if (-not [string]::IsNullOrWhiteSpace($pr.title)) { $lines += "- Title: $($pr.title)" }
  if (-not [string]::IsNullOrWhiteSpace($pr.state)) { $lines += "- State: $($pr.state)" }
  if ($null -ne $pr.isDraft) { $lines += "- Draft: $($pr.isDraft)" }
  if (-not [string]::IsNullOrWhiteSpace($pr.baseRefName)) { $lines += "- Base branch: $($pr.baseRefName)" }
  if (-not [string]::IsNullOrWhiteSpace($pr.headRefName)) { $lines += "- Head branch: $($pr.headRefName)" }
  if ($pr.author -and -not [string]::IsNullOrWhiteSpace($pr.author.login)) { $lines += "- Author: $($pr.author.login)" }
  if (-not [string]::IsNullOrWhiteSpace($pr.reviewDecision)) { $lines += "- Review decision: $($pr.reviewDecision)" }
  if (-not [string]::IsNullOrWhiteSpace($pr.mergeable)) { $lines += "- Mergeable: $($pr.mergeable)" }
  if ($null -ne $pr.changedFiles) { $lines += "- Changed files: $($pr.changedFiles)" }
  if ($null -ne $pr.additions) { $lines += "- Additions: $($pr.additions)" }
  if ($null -ne $pr.deletions) { $lines += "- Deletions: $($pr.deletions)" }
  return ($lines -join "`n")
}

function New-PullRequestReviewPrompt {
  param(
    [string] $PullRequestSelector,
    [string] $WorkingDirectory,
    [string] $AnalysisPath,
    [string] $PromptText
  )

  $repoSummary = Get-RepositorySummary $WorkingDirectory
  $prSummary = Get-PullRequestSummary $PullRequestSelector $WorkingDirectory
  $contextLines = @()

  if (-not [string]::IsNullOrWhiteSpace($AnalysisPath)) {
    $contextLines += "Additional analysis file path: $AnalysisPath"
    $contextLines += "Read that file only if it is available through read-only repository/file tools. Treat it as another agent's conclusion, not as evidence."
  }

  if (-not [string]::IsNullOrWhiteSpace($PromptText)) {
    $contextLines += "Caller context or conclusion:"
    $contextLines += $PromptText
  }

  $extraContext = if ($contextLines.Count -gt 0) { $contextLines -join "`n" } else { "No extra caller context provided." }

  return @"
You are doing a differential code review of an existing GitHub pull request for another AI agent.

Use the PR reference and read-only access to the repository. The caller intentionally did not paste the full diff. Inspect the PR yourself with read-only tools when available, such as `gh pr view`, `gh pr diff`, `git diff`, file reads, and search. Do not ask the caller to paste the diff.

Do not edit files or change repository state. Do not checkout, fetch, merge, rebase, commit, push, or create/update PRs. If a tool needed to inspect the PR is unavailable in read-only mode, say exactly what was unavailable and continue with the evidence you do have.

Repository context:
$repoSummary

Pull request context:
$prSummary

$extraContext

Return findings first:
1. Bugs or behavior regressions.
2. Missing tests or weak validation.
3. Security, secrets, data loss, permissions, or unsafe workflow issues.
4. Simpler implementation if the PR overcomplicates the change.
5. Evidence checked and any read-only checks that were unavailable.

Finish with one recommendation: ready as-is, ready after small fix, or not ready.
"@
}

function New-OpenCodeReadOnlyConfig {
  $config = @{
    agent = @{
      'differential-review-readonly' = @{
        mode = 'primary'
        description = 'Read-only differential review agent'
        permission = @{
          read = 'allow'
          glob = 'allow'
          grep = 'allow'
          list = 'allow'
          edit = 'deny'
          bash = 'deny'
          task = 'deny'
          external_directory = 'deny'
          todowrite = 'deny'
          question = 'deny'
          webfetch = 'deny'
          websearch = 'deny'
          codesearch = 'deny'
          lsp = 'deny'
          skill = 'deny'
          doom_loop = 'deny'
        }
      }
    }
    experimental = @{
      continue_loop_on_deny = $true
    }
  }

  return $config | ConvertTo-Json -Depth 10 -Compress
}

if ([string]::IsNullOrWhiteSpace($AnalysisFile) -and
    [string]::IsNullOrWhiteSpace($Prompt) -and
    [string]::IsNullOrWhiteSpace($PullRequest)) {
  throw "Provide -AnalysisFile, -Prompt, or -PullRequest."
}

$invokerAgent = Resolve-InvokerAgent $Invoker
if (-not $AllowSelfReview -and
    -not [string]::IsNullOrWhiteSpace($invokerAgent) -and
    $invokerAgent -eq $Reviewer) {
  throw "Self-review blocked: invoker '$invokerAgent' matches reviewer '$Reviewer'. Choose a different reviewer or pass -AllowSelfReview if this is intentional."
}

$workingDirectory = (Get-Location).Path

$analysisPath = $null
if (-not [string]::IsNullOrWhiteSpace($AnalysisFile)) {
  if (-not (Test-Path -LiteralPath $AnalysisFile)) {
    throw "Analysis file not found: $AnalysisFile"
  }
  $analysisPath = (Resolve-Path -LiteralPath $AnalysisFile).Path
}

if (-not [string]::IsNullOrWhiteSpace($PullRequest)) {
  $finalPrompt = New-PullRequestReviewPrompt -PullRequestSelector $PullRequest -WorkingDirectory $workingDirectory -AnalysisPath $analysisPath -PromptText $Prompt
} elseif ($analysisPath) {
  $analysis = Get-Content -Raw -Encoding UTF8 -LiteralPath $analysisPath
  $finalPrompt = @"
You are doing a differential review of an analysis or plan drafted by another AI agent before files are edited.

Read the Markdown analysis below. Your job is to challenge it, not to approve it.

Return:
1. Weak assumptions
   - claims presented as facts without evidence,
   - unstated dependencies on context, files, or state,
   - terms used inconsistently.
2. Scenarios that break the conclusion
   - concrete cases where the recommendation fails,
   - edge cases the analysis ignored.
3. Missing evidence
   - facts the author should have checked in the repo before concluding,
   - tests or checks that could disprove the plan.
4. Revised recommendation
   - a more precise version if the original overgeneralized,
   - case-by-case criteria if a fixed rule is not enough.
5. Stop conditions
   - any reason the agent should revise the analysis before implementing.

Do not edit files. Do not include secrets. If read-only repository tools are available, use them only to verify claims. Keep it concise and self-contained.

Analysis file: $analysisPath

$analysis
"@
} else {
  $finalPrompt = $Prompt
}

if ($PrintPromptOnly) {
  [Console]::Out.WriteLine($finalPrompt)
  exit 0
}

$promptFile = Join-Path $tempRoot ("$Reviewer-prompt-" + (Get-Date).ToString('yyyyMMddHHmmss') + '.txt')
Set-Content -LiteralPath $promptFile -Value $finalPrompt -Encoding UTF8

$toolLabel = switch ($Reviewer) {
  'claude' { 'claude-code' }
  'opencode' { 'opencode-run' }
  default { 'codex-exec' }
}
$outFile = Join-Path $tempRoot ("$Reviewer-differential-review-" + (Get-Date).ToString('yyyyMMddHHmmss') + '.md')

$exePath = $null
$args = @()
$reviewerDetails = @()
$opencodeConfigContent = ''

if ($Reviewer -eq 'codex') {
  $codexCandidates = @()
  if ($env:CODEX_CLI_PATH) {
    $codexCandidates += $env:CODEX_CLI_PATH
  }
  if ($env:LOCALAPPDATA) {
    $codexCandidates += (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin\*\codex.exe')
    $codexCandidates += (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin\codex.exe')
  }
  if ($env:HOME) {
    $codexCandidates += (Join-Path $env:HOME '.local/bin/codex')
  }
  $exePath = Resolve-ExecutablePath -ExplicitPath $CodexPath -CommandName 'codex' -RejectWindowsAppsAlias -GlobCandidates $codexCandidates -PreferGlobCandidates
  $exeVersion = Get-ExecutableVersion $exePath
  $args = @(
    'exec',
    '--ephemeral',
    '--sandbox', 'read-only',
    '-m', $CodexModel,
    '-c', "model_reasoning_effort=`"$CodexReasoningEffort`"",
    '-c', 'mcp_servers.figma.enabled=false',
    '--output-last-message', $outFile
  )
  if (-not [string]::IsNullOrWhiteSpace($Profile)) {
    $args = @('exec', '--profile', $Profile) + $args[1..($args.Length - 1)]
  }
  $reviewerDetails = @(
    "- Herramienta: $toolLabel",
    "- Model: $CodexModel",
    "- Reasoning effort: $CodexReasoningEffort",
    "- Profile: $(if ([string]::IsNullOrWhiteSpace($Profile)) { 'default' } else { $Profile })",
    "- Binary: $exePath",
    "- Version: $(if ([string]::IsNullOrWhiteSpace($exeVersion)) { 'unknown' } else { $exeVersion })",
    "- Sandbox: read-only"
  )
  if ($ExtraArgs) {
    $blockedExtraArgs = @(
      '--sandbox',
      '-s',
      '--dangerously-bypass-approvals-and-sandbox',
      '--yolo',
      '--add-dir',
      '-m',
      '--model'
    )
    foreach ($arg in $ExtraArgs) {
      if (($blockedExtraArgs -contains $arg) -or ($arg -match '^(--sandbox|-s|--dangerously-bypass-approvals-and-sandbox|--yolo|--add-dir|-m|--model)(=|,|$)')) {
        throw "-ExtraArgs cannot include '$arg' because differential-review must remain read-only."
      }
      if ($arg -match '^(sandbox|sandbox_|approval_policy|model|model_reasoning_effort)\s*=') {
        throw "-ExtraArgs cannot override '$($Matches[1])' because differential-review must remain read-only."
      }
    }
    $args += $ExtraArgs
  }
} elseif ($Reviewer -eq 'claude') {
  $claudeCandidates = @()
  if ($env:USERPROFILE) {
    $claudeCandidates += (Join-Path $env:USERPROFILE '.local\bin\claude.exe')
  }
  if ($env:HOME) {
    $claudeCandidates += (Join-Path $env:HOME '.local/bin/claude')
  }
  if ($env:APPDATA) {
    $claudeCandidates += (Join-Path $env:APPDATA 'npm\claude.cmd')
  }
  $exePath = Resolve-ExecutablePath -ExplicitPath $ClaudePath -CommandName 'claude' -GlobCandidates $claudeCandidates
  if ($ClaudeBare -and
      [string]::IsNullOrWhiteSpace($env:ANTHROPIC_API_KEY) -and
      [string]::IsNullOrWhiteSpace($env:ANTHROPIC_AUTH_TOKEN) -and
      [string]::IsNullOrWhiteSpace($ClaudeSettings)) {
    throw "Claude bare mode requires ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN, or -ClaudeSettings/DIFF_REVIEW_CLAUDE_SETTINGS. The normal claude.ai login is not available to --bare."
  }

  $args = @('-p')
  if ($ClaudeBare) {
    $args += '--bare'
  }
  $args += @(
    '--model', $ClaudeModel,
    '--effort', $ClaudeEffort,
    '--permission-mode', 'plan',
    '--no-session-persistence',
    '--output-format', 'json',
    '--disable-slash-commands',
    '--mcp-config', '{"mcpServers":{}}',
    '--strict-mcp-config',
    '--setting-sources', 'project',
    '--add-dir', $workingDirectory
  )
  if (-not [string]::IsNullOrWhiteSpace($ClaudeSettings)) {
    $args += @('--settings', $ClaudeSettings)
  }
  $reviewerDetails = @(
    "- Herramienta: $toolLabel",
    "- Model: $ClaudeModel",
    "- Effort: $ClaudeEffort",
    "- Permission mode: plan",
    "- Bare mode: $($ClaudeBare.IsPresent)",
    "- Tools: Read, LS, Glob, Grep",
    "- MCP config: empty strict",
    "- Settings sources: project",
    "- Working directory: temp",
    "- Repository access: read-only $workingDirectory"
  )
  if ($ExtraArgs) {
    foreach ($arg in $ExtraArgs) {
      if ($arg -match '^(--bare|--dangerously-skip-permissions|--allow-dangerously-skip-permissions|--permission-mode|--add-dir|--tools|--allowedTools|--allowed-tools|--setting-sources|--settings|--mcp-config|--strict-mcp-config|--output-format|--continue|-c|--resume|-r)(=|,|$)') {
        throw "-ExtraArgs cannot include '$arg' because claude differential-review must stay non-mutating and isolated from saved context."
      }
    }
    $args += $ExtraArgs
  }
  $args += @('--tools', 'Read,LS,Glob,Grep')
} else {
  $OpenCodeModel = Normalize-OpenCodeModel $OpenCodeModel
  $opencodeConfigContent = New-OpenCodeReadOnlyConfig
  $opencodeCandidates = @()
  if ($env:USERPROFILE) {
    $opencodeCandidates += (Join-Path $env:USERPROFILE '.bun\bin\opencode.exe')
  }
  if ($env:APPDATA) {
    $opencodeCandidates += (Join-Path $env:APPDATA 'npm\opencode.cmd')
  }
  $exePath = Resolve-ExecutablePath -ExplicitPath $OpenCodePath -CommandName 'opencode' -GlobCandidates $opencodeCandidates
  $args = @(
    'run',
    '--pure',
    '--format', 'default',
    '--file', $promptFile,
    '--dir', $workingDirectory,
    '--agent', 'differential-review-readonly'
  )
  if (-not [string]::IsNullOrWhiteSpace($OpenCodeModel)) {
    $args += @('--model', $OpenCodeModel)
  }
  if (-not [string]::IsNullOrWhiteSpace($OpenCodeVariant)) {
    $args += @('--variant', $OpenCodeVariant)
  }
  $args += 'Read the attached prompt file. Follow its instructions exactly and return only the requested differential review.'
  $reviewerDetails = @(
    "- Herramienta: $toolLabel",
    "- Model: $(if ([string]::IsNullOrWhiteSpace($OpenCodeModel)) { 'opencode default' } else { $OpenCodeModel })",
    "- Variant: $(if ([string]::IsNullOrWhiteSpace($OpenCodeVariant)) { 'opencode default' } else { $OpenCodeVariant })",
    "- Agent: differential-review-readonly",
    "- Working directory: repo",
    "- Repository access: read-only $workingDirectory"
  )
  if ($ExtraArgs) {
    foreach ($arg in $ExtraArgs) {
      if ($arg -match '^(--dangerously-skip-permissions|--continue|-c|--session|-s|--attach|--dir|--port|--file|-f|--command|--share|--interactive|-i|--fork|--model|-m|--variant|--thinking|--agent|--format)(=|,|$)') {
        throw "-ExtraArgs cannot include '$arg' because opencode differential-review must stay isolated and non-mutating."
      }
    }
    $insertAt = $args.Length - 1
    $args = $args[0..($insertAt - 1)] + $ExtraArgs + $args[$insertAt]
  }
}

Write-Host "[differential-review] Reviewer: $Reviewer" -ForegroundColor Cyan
if ($Reviewer -eq 'codex') {
  $profileLabel = if ([string]::IsNullOrWhiteSpace($Profile)) { 'default profile' } else { "profile $Profile" }
  Write-Host "[differential-review] Invoking codex exec --model $CodexModel -c model_reasoning_effort=$CodexReasoningEffort ($profileLabel, sandbox=read-only, ephemeral) ..." -ForegroundColor Cyan
  Write-Host "[differential-review] Codex binary: $exePath$(if ([string]::IsNullOrWhiteSpace($exeVersion)) { '' } else { " ($exeVersion)" })" -ForegroundColor DarkGray
} elseif ($Reviewer -eq 'claude') {
  $claudeModeLabel = if ($ClaudeBare) { 'bare' } else { 'compatible' }
  Write-Host "[differential-review] Invoking Claude Code --model $ClaudeModel --effort $ClaudeEffort ($claudeModeLabel, plan, no session persistence, read-only repo tools) ..." -ForegroundColor Cyan
} else {
  $modelLabel = if ([string]::IsNullOrWhiteSpace($OpenCodeModel)) { 'opencode default model' } else { $OpenCodeModel }
  $variantLabel = if ([string]::IsNullOrWhiteSpace($OpenCodeVariant)) { 'opencode default variant' } else { $OpenCodeVariant }
  Write-Host "[differential-review] Invoking opencode run --model $modelLabel --variant $variantLabel (read-only repo agent) ..." -ForegroundColor Cyan
}
Write-Host "[differential-review] Output target: $outFile" -ForegroundColor DarkGray
Write-Host "[differential-review] Te doy feedback cada 1 minuto mientras $Reviewer corre." -ForegroundColor Cyan

$errFile = Join-Path $tempRoot ("$Reviewer-stderr-" + (Get-Date).ToString('yyyyMMddHHmmss') + '.txt')
$stdoutFile = Join-Path $tempRoot ("$Reviewer-stdout-" + (Get-Date).ToString('yyyyMMddHHmmss') + '.txt')
$jobWorkingDirectory = if ($Reviewer -eq 'opencode' -or $Reviewer -eq 'claude') { $tempRoot } else { $workingDirectory }

if ($Reviewer -eq 'codex') {
  $argString = ($args | ForEach-Object {
      if ($_ -match '\s') { "`"$_`"" } else { [string] $_ }
  }) -join ' '
  $job = Start-Job -ScriptBlock {
      param($JobExePath, $JobArgString, $JobPromptFile, $JobStdoutFile, $JobErrFile, $JobWorkingDirectory)
      $p = Start-Process -FilePath $JobExePath -ArgumentList $JobArgString -WorkingDirectory $JobWorkingDirectory -NoNewWindow -Wait -PassThru -RedirectStandardInput $JobPromptFile -RedirectStandardOutput $JobStdoutFile -RedirectStandardError $JobErrFile
      $p.ExitCode
  } -ArgumentList $exePath, $argString, $promptFile, $stdoutFile, $errFile, $jobWorkingDirectory
} else {
  $job = Start-Job -ScriptBlock {
      param($JobExePath, [string[]] $JobArgs, $JobPromptFile, $JobStdoutFile, $JobErrFile, $JobWorkingDirectory, $JobOpenCodeConfigContent)
      function Quote-ProcessArg {
        param([string] $Value)
        if ($null -eq $Value) { return '""' }
        return '"' + $Value.Replace('"', '\"') + '"'
      }

      $promptText = Get-Content -Raw -Encoding UTF8 -LiteralPath $JobPromptFile
      $psi = [System.Diagnostics.ProcessStartInfo]::new()
      $isCmdShim = $JobExePath -match '\.(cmd|bat)$'
      if ($isCmdShim) {
        $psi.FileName = if ($env:ComSpec) { $env:ComSpec } else { 'cmd.exe' }
        $cmdArgs = ($JobArgs | ForEach-Object { Quote-ProcessArg ([string]$_) }) -join ' '
        $psi.Arguments = '/d /s /c "call ' + (Quote-ProcessArg $JobExePath) + ' ' + $cmdArgs + '"'
      } else {
        $psi.FileName = $JobExePath
        $psi.Arguments = ($JobArgs | ForEach-Object { Quote-ProcessArg ([string]$_) }) -join ' '
      }
      $psi.WorkingDirectory = $JobWorkingDirectory
      $psi.UseShellExecute = $false
      $psi.RedirectStandardInput = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true
      if (-not [string]::IsNullOrWhiteSpace($JobOpenCodeConfigContent)) {
        $psi.Environment['OPENCODE_CONFIG_CONTENT'] = $JobOpenCodeConfigContent
      }
      $p = [System.Diagnostics.Process]::Start($psi)
      $p.StandardInput.Write($promptText)
      $p.StandardInput.Close()
      $stdoutText = $p.StandardOutput.ReadToEnd()
      $stderrText = $p.StandardError.ReadToEnd()
      $p.WaitForExit()
      Set-Content -LiteralPath $JobStdoutFile -Value $stdoutText -Encoding UTF8
      Set-Content -LiteralPath $JobErrFile -Value $stderrText -Encoding UTF8
      $p.ExitCode
  } -ArgumentList $exePath, $args, $promptFile, $stdoutFile, $errFile, $jobWorkingDirectory, $opencodeConfigContent
}

$elapsedSeconds = 0
while ($job.State -eq 'Running') {
    Start-Sleep -Seconds 5
    $elapsedSeconds += 5
    if ($job.State -eq 'Running') {
        if (($elapsedSeconds % 60) -eq 0) {
            $elapsedMinutes = [int]($elapsedSeconds / 60)
            Write-Host "[differential-review] $Reviewer sigue corriendo... ($elapsedMinutes min)" -ForegroundColor Cyan
        }
    }
}
$jobResult = Receive-Job -Job $job -ErrorAction SilentlyContinue
if ($job.State -eq 'Failed') {
  Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
  throw "$Reviewer job failed before an exit code was produced."
}
Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

if ($jobResult -is [array]) {
  $exitCode = [int]$jobResult[-1]
} elseif ($null -ne $jobResult) {
  $exitCode = [int]$jobResult
} else {
  $exitCode = 1
}

$stderrText = ''
if (Test-Path -LiteralPath $errFile) {
    $stderrText = Get-Content -Raw -Encoding UTF8 -LiteralPath $errFile -ErrorAction SilentlyContinue
}
$stdoutText = ''
if (Test-Path -LiteralPath $stdoutFile) {
    $stdoutText = Get-Content -Raw -Encoding UTF8 -LiteralPath $stdoutFile -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $promptFile -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue

if ($exitCode -ne 0) {
  Remove-Item -LiteralPath $stdoutFile -Force -ErrorAction SilentlyContinue
  if (-not [string]::IsNullOrWhiteSpace($stdoutText)) {
    [Console]::Error.WriteLine($stdoutText)
  }
  if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
    [Console]::Error.WriteLine($stderrText)
  }
  Write-Host "[differential-review] $Reviewer exited with code $exitCode. Analysis file not modified." -ForegroundColor Yellow
  exit $exitCode
}

if ($Reviewer -eq 'claude') {
  if (Test-Path -LiteralPath $stdoutFile) {
    $reviewerStdout = Get-Content -Raw -Encoding UTF8 -LiteralPath $stdoutFile
    try {
      $claudeResult = $reviewerStdout | ConvertFrom-Json -ErrorAction Stop
    } catch {
      Remove-Item -LiteralPath $stdoutFile -Force -ErrorAction SilentlyContinue
      [Console]::Error.WriteLine($reviewerStdout)
      Write-Host "[differential-review] Claude Code did not return valid JSON. Analysis file not modified." -ForegroundColor Yellow
      exit 1
    }

    if ($claudeResult.is_error -eq $true) {
      Remove-Item -LiteralPath $stdoutFile -Force -ErrorAction SilentlyContinue
      $errorMessage = if ($null -ne $claudeResult.result) { [string] $claudeResult.result } else { $reviewerStdout }
      [Console]::Error.WriteLine($errorMessage)
      Write-Host "[differential-review] Claude Code returned an error result. Analysis file not modified." -ForegroundColor Yellow
      exit 1
    }

    if ($null -eq $claudeResult.result) {
      Remove-Item -LiteralPath $stdoutFile -Force -ErrorAction SilentlyContinue
      [Console]::Error.WriteLine($reviewerStdout)
      Write-Host "[differential-review] Claude Code JSON did not include a result field. Analysis file not modified." -ForegroundColor Yellow
      exit 1
    }

    Set-Content -LiteralPath $outFile -Value ([string] $claudeResult.result) -Encoding UTF8
  }
} elseif ($Reviewer -eq 'opencode') {
  if (Test-Path -LiteralPath $stdoutFile) {
    $reviewerStdout = Get-Content -Raw -Encoding UTF8 -LiteralPath $stdoutFile
    $reviewerStdout = $reviewerStdout -replace "`e\[[0-9;?]*[ -/]*[@-~]", ''
    Set-Content -LiteralPath $outFile -Value $reviewerStdout -Encoding UTF8
  }
}
Remove-Item -LiteralPath $stdoutFile -Force -ErrorAction SilentlyContinue

if (-not (Test-Path -LiteralPath $outFile)) {
  if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
    [Console]::Out.WriteLine($stderrText)
  }
  Write-Host "[differential-review] No output file produced by $Reviewer. Nothing to append." -ForegroundColor Yellow
  exit 0
}

$responseText = Get-Content -Raw -Encoding UTF8 -LiteralPath $outFile

if ([string]::IsNullOrWhiteSpace($responseText)) {
  Write-Host "[differential-review] $Reviewer produced an empty response. Nothing to append." -ForegroundColor Yellow
  if (-not $KeepOutputFile) { Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue }
  exit 0
}

[Console]::Out.WriteLine($responseText)

if ($analysisPath) {
  $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  $header = @(
    '',
    '## Comentarios IA externa (analisis diferencial)',
    '',
    "- Fecha UTC: $timestamp"
  ) + $reviewerDetails + @(
    '',
    '```text'
  )
  Add-Content -LiteralPath $analysisPath -Value $header -Encoding UTF8
  Add-Content -LiteralPath $analysisPath -Value $responseText -Encoding UTF8
  Add-Content -LiteralPath $analysisPath -Value '```' -Encoding UTF8
  Write-Host "[differential-review] Response appended to: $analysisPath" -ForegroundColor Green
}

if (-not $KeepOutputFile) {
  Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
} else {
  Write-Host "[differential-review] Output file kept at: $outFile" -ForegroundColor DarkGray
}

exit 0
