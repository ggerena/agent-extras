param(
  [string] $RepoPath = (Get-Location).Path,
  [string] $BaseBranch = 'develop',
  [string] $Remote = '',
  [string] $Branch = '',
  [string] $CommitMessage,
  [string] $PrTitle,
  [string] $PrBody = '',
  [string[]] $Pathspec = @(),
  [string[]] $VerificationCommand = @(),
  [switch] $StageAll,
  [switch] $SkipCommit,
  [switch] $DryRun,
  [switch] $Backup,
  [switch] $ReviewPassed,
  [switch] $ConfirmedByUser
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
  param([string[]] $Arguments)
  & git @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function Get-GitOutput {
  param([string[]] $Arguments)
  $output = & git @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
  return $output
}

function Invoke-External {
  param(
    [string] $Label,
    [string] $Command
  )

  Write-Host "[cerrar-pr] $Label" -ForegroundColor Cyan
  if ($DryRun) {
    Write-Host "[cerrar-pr] Dry run: $Command" -ForegroundColor Yellow
    return
  }

  powershell -NoProfile -ExecutionPolicy Bypass -Command $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE"
  }
}

function Assert-VerificationCommandSafe {
  param([string] $Command)

  $normalized = ($Command -replace '\s+', ' ').Trim().ToLowerInvariant()
  $blockedPatterns = @(
    '(^|[;&|]\s*)npm (run )?dev(\s|$)',
    '(^|[;&|]\s*)npm start(\s|$)',
    '(^|[;&|]\s*)yarn (dev|develop)(\s|$)',
    '(^|[;&|]\s*)pnpm (run )?(dev|start)(\s|$)',
    '(^|[;&|]\s*)preview_start(\s|$)',
    '(^|[;&|]\s*)vite(\s|$)',
    '(^|[;&|]\s*)next dev(\s|$)',
    '(^|[;&|]\s*)cargo run(\s|$)',
    '(^|[;&|]\s*)python -m http\.server(\s|$)'
  )

  foreach ($pattern in $blockedPatterns) {
    if ($normalized -match $pattern) {
      throw "Verification command looks like a dev server and is blocked: $Command"
    }
  }
}

function Resolve-RemoteName {
  param([string] $RequestedRemote)

  if (-not [string]::IsNullOrWhiteSpace($RequestedRemote)) {
    return $RequestedRemote
  }

  $remotes = @(Get-GitOutput -Arguments @('remote'))
  if ($remotes -contains 'private') {
    return 'private'
  }
  if ($remotes -contains 'origin') {
    return 'origin'
  }
  if ($remotes.Count -gt 0) {
    return [string] $remotes[0]
  }

  throw 'No git remote found.'
}

function Resolve-GitHubRepository {
  param([string] $RemoteName)

  $pushUrls = @(Get-GitOutput -Arguments @('remote', 'get-url', '--push', '--all', $RemoteName))
  if ($pushUrls.Count -ne 1) {
    throw 'Exactly one push URL is required to identify the PR repository safely.'
  }
  $remoteUrl = $pushUrls[0].Trim().TrimEnd('/')
  if ($remoteUrl -notmatch '^(?:https://|ssh://git@|git@)([a-zA-Z0-9.-]+)[:/]([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+)$') {
    throw 'Cannot safely identify host/owner/repository from the selected push URL.'
  }
  return "$($Matches[1])/$($Matches[2])/$($Matches[3] -replace '\.git$', '')"
}

function Get-ExistingPr {
  param(
    [string] $HeadBranch,
    [string] $TargetBase,
    [string] $Repository
  )

  $json = (gh pr list --repo $Repository --head $HeadBranch --state open --json url,isDraft,baseRefName,isCrossRepository) -join "`n"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) {
    throw 'Cannot determine existing PR state; refusing to push.'
  }

  if (-not $json.Trim().StartsWith('[')) {
    throw 'Invalid PR list response; refusing to push.'
  }
  $parsedItems = ConvertFrom-Json -InputObject $json
  $items = @($parsedItems)
  if ($items.Count -gt 1) {
    throw 'Multiple open PRs for this branch; refusing to push until the target is resolved.'
  }
  if ($items.Count -eq 1) {
    $pr = $items[0]
    if ($pr.isCrossRepository -isnot [bool] -or $pr.isCrossRepository) {
      throw 'PR head repository is unknown or cross-repository; refusing to push.'
    }
    if ([string]::IsNullOrWhiteSpace($pr.url) -or $pr.isDraft -isnot [bool] -or $pr.baseRefName -ne $TargetBase) {
      throw 'Existing PR has an unknown state or different base; refusing to push.'
    }
    return $pr
  }

  return $null
}

if (-not $DryRun -and -not $ConfirmedByUser) {
  throw 'Refusing to commit, push, or create PR without -ConfirmedByUser.'
}

if ($Backup -and $ReviewPassed) {
  throw 'Use -Backup for incomplete checkpoints or -ReviewPassed for reviewed close-out, not both.'
}

if (-not $DryRun -and -not $Backup -and -not $ReviewPassed) {
  throw 'Use -Backup for a draft checkpoint, or finish verification and /revisa before passing -ReviewPassed.'
}

$repoRoot = (Resolve-Path -LiteralPath $RepoPath).Path
Push-Location $repoRoot
try {
  $inside = Get-GitOutput -Arguments @('rev-parse', '--is-inside-work-tree')
  if (($inside | Select-Object -First 1) -ne 'true') {
    throw "Not a git repository: $repoRoot"
  }

  $headBranch = (Get-GitOutput -Arguments @('rev-parse', '--abbrev-ref', 'HEAD') | Select-Object -First 1)
  if (-not [string]::IsNullOrWhiteSpace($Branch) -and $Branch -ne $headBranch) {
    throw "Branch override '$Branch' does not match current HEAD branch '$headBranch'."
  }
  $currentBranch = $headBranch

  $protectedBranches = @('develop', 'main', 'master')
  if (($protectedBranches -contains $currentBranch) -or ($currentBranch -eq $BaseBranch) -or ($currentBranch -eq 'HEAD')) {
    throw "Refusing to push directly to '$currentBranch'."
  }

  $remoteName = Resolve-RemoteName $Remote
  $githubRepository = Resolve-GitHubRepository $remoteName
  Write-Host "[cerrar-pr] Repo: $repoRoot" -ForegroundColor Cyan
  Write-Host "[cerrar-pr] Branch: $currentBranch -> $BaseBranch via $remoteName" -ForegroundColor Cyan
  Write-Host "[cerrar-pr] Local review gate: $(if ($ReviewPassed) { 'passed (caller assertion)' } elseif ($Backup) { 'not asserted; draft backup only' } else { 'dry-run only; not asserted' })" -ForegroundColor Cyan
  Write-Host '[cerrar-pr] External review is handled separately.' -ForegroundColor Cyan

  Write-Host "[cerrar-pr] git status --short" -ForegroundColor Cyan
  git status --short
  Write-Host "[cerrar-pr] git diff --stat" -ForegroundColor Cyan
  git diff --stat
  Write-Host "[cerrar-pr] git diff --cached --stat" -ForegroundColor Cyan
  git diff --cached --stat

  foreach ($command in $VerificationCommand) {
    Assert-VerificationCommandSafe $command
    Invoke-External -Label "Verification: $command" -Command $command
  }

  if ($StageAll -and $Pathspec.Count -gt 0) {
    throw 'Use either -StageAll or -Pathspec, not both.'
  }

  if ($StageAll) {
    if ($DryRun) {
      Write-Host '[cerrar-pr] Dry run: git add --sparse --all' -ForegroundColor Yellow
    } else {
      Invoke-Git -Arguments @('add', '--sparse', '--all')
    }
  } elseif ($Pathspec.Count -gt 0) {
    if ($DryRun) {
      Write-Host "[cerrar-pr] Dry run: git add --sparse -- $($Pathspec -join ' ')" -ForegroundColor Yellow
    } else {
      Invoke-Git -Arguments (@('add', '--sparse', '--') + $Pathspec)
    }
  }

  if (-not $SkipCommit) {
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
      throw 'Provide -CommitMessage or pass -SkipCommit.'
    }

    $staged = Get-GitOutput -Arguments @('diff', '--cached', '--name-only')
    if ($staged.Count -gt 0) {
      Write-Host '[cerrar-pr] Staged files:' -ForegroundColor Cyan
      $staged | ForEach-Object { Write-Host "  $_" }
      if ($DryRun) {
        Write-Host "[cerrar-pr] Dry run: git commit -m `"$CommitMessage`"" -ForegroundColor Yellow
      } else {
        Invoke-Git -Arguments @('commit', '-m', $CommitMessage)
      }
    } else {
      Write-Host '[cerrar-pr] No staged changes to commit.' -ForegroundColor Yellow
    }
  }

  if ($DryRun) {
    Write-Host '[cerrar-pr] Dry run: inspect existing PR; convert ready PR to draft before push.' -ForegroundColor Yellow
    Write-Host "[cerrar-pr] Dry run: git push -u $remoteName $currentBranch" -ForegroundColor Yellow
    Write-Host "[cerrar-pr] Dry run: create/reuse draft PR in $githubRepository for $currentBranch -> $BaseBranch" -ForegroundColor Yellow
    return
  }

  $existingPr = Get-ExistingPr -HeadBranch $currentBranch -TargetBase $BaseBranch -Repository $githubRepository
  if ($null -eq $existingPr -and [string]::IsNullOrWhiteSpace($PrTitle)) {
    throw 'Provide -PrTitle when creating a new PR.'
  }
  if ($null -ne $existingPr -and -not $existingPr.isDraft) {
    gh pr ready $existingPr.url --undo --repo $githubRepository
    if ($LASTEXITCODE -ne 0) {
      throw 'Cannot convert existing PR to draft; refusing to push.'
    }
    $existingPr = Get-ExistingPr -HeadBranch $currentBranch -TargetBase $BaseBranch -Repository $githubRepository
    if ($null -eq $existingPr -or -not $existingPr.isDraft) {
      throw 'Draft state was not confirmed; refusing to push.'
    }
  }

  Invoke-Git -Arguments @('push', '-u', $remoteName, $currentBranch)

  $prUrl = if ($null -ne $existingPr) { [string] $existingPr.url } else { '' }
  if ($null -eq $existingPr) {
    $bodyFile = Join-Path $env:TEMP ("cerrar-pr-body-" + [guid]::NewGuid().ToString('N') + '.md')
    $body = if ([string]::IsNullOrWhiteSpace($PrBody)) {
      "Work in progress.`n`nRequired tests and reviews must be confirmed for the published head before marking ready."
    } else {
      $PrBody
    }
    Set-Content -LiteralPath $bodyFile -Value $body -Encoding UTF8
    try {
      $prUrl = gh pr create --repo $githubRepository --draft --base $BaseBranch --head $currentBranch --title $PrTitle --body-file $bodyFile
      if ($LASTEXITCODE -ne 0) {
        throw 'gh pr create failed.'
      }
    } finally {
      Remove-Item -LiteralPath $bodyFile -Force -ErrorAction SilentlyContinue
    }
  } else {
    Write-Host "[cerrar-pr] Reusing existing PR: $prUrl" -ForegroundColor Cyan
  }

  Write-Host "[cerrar-pr] PR: $prUrl" -ForegroundColor Green

  Write-Host '[cerrar-pr] Backup published. PR left draft; readiness and merge were not performed.' -ForegroundColor Green
} finally {
  Pop-Location
}
