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

function Resolve-RepositoryName {
  param(
    [string] $RemoteName,
    [string] $RepositoryRoot
  )

  $remoteUrl = (Get-GitOutput -Arguments @('remote', 'get-url', $RemoteName) | Select-Object -First 1)
  if (-not [string]::IsNullOrWhiteSpace($remoteUrl)) {
    $normalizedUrl = $remoteUrl.Trim().TrimEnd('/').Replace('\', '/')
    $remoteLeaf = ($normalizedUrl -split '/')[-1]
    $remoteRepositoryName = $remoteLeaf -replace '\.git$', ''
    if (-not [string]::IsNullOrWhiteSpace($remoteRepositoryName)) {
      return $remoteRepositoryName
    }
  }

  return (Split-Path -Leaf $RepositoryRoot)
}

function Get-ExistingPrUrl {
  param(
    [string] $HeadBranch,
    [string] $TargetBase
  )

  $json = gh pr list --head $HeadBranch --base $TargetBase --state open --json url 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) {
    return ''
  }

  $items = $json | ConvertFrom-Json
  if ($items.Count -gt 0) {
    return [string] $items[0].url
  }

  return ''
}

if (-not $DryRun -and -not $ConfirmedByUser) {
  throw 'Refusing to commit, push, or create PR without -ConfirmedByUser.'
}

if (-not $DryRun -and -not $ReviewPassed) {
  throw 'Refusing to close the PR before the mandatory local review loop passes. Run /revisa, correct valid high and medium findings, rerun verification, then pass -ReviewPassed.'
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
  if (($protectedBranches -contains $currentBranch) -or ($currentBranch -eq $BaseBranch)) {
    throw "Refusing to push directly to '$currentBranch'."
  }

  $remoteName = Resolve-RemoteName $Remote
  Write-Host "[cerrar-pr] Repo: $repoRoot" -ForegroundColor Cyan
  Write-Host "[cerrar-pr] Branch: $currentBranch -> $BaseBranch via $remoteName" -ForegroundColor Cyan
  Write-Host "[cerrar-pr] Local review gate: $(if ($ReviewPassed) { 'passed' } else { 'dry-run only; not asserted' })" -ForegroundColor Cyan
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
    Write-Host "[cerrar-pr] Dry run: git push -u $remoteName $currentBranch" -ForegroundColor Yellow
    Write-Host "[cerrar-pr] Dry run: gh pr create/list for $currentBranch -> $BaseBranch" -ForegroundColor Yellow
    return
  }

  Invoke-Git -Arguments @('push', '-u', $remoteName, $currentBranch)

  $prUrl = Get-ExistingPrUrl -HeadBranch $currentBranch -TargetBase $BaseBranch
  if ([string]::IsNullOrWhiteSpace($prUrl)) {
    if ([string]::IsNullOrWhiteSpace($PrTitle)) {
      throw 'Provide -PrTitle when creating a new PR.'
    }
    $bodyFile = Join-Path $env:TEMP ("cerrar-pr-body-" + (Get-Date).ToString('yyyyMMddHHmmss') + '.md')
    $body = if ([string]::IsNullOrWhiteSpace($PrBody)) {
      "Close-out PR created by cerrar-pr.`n`nNo merge is performed by this skill."
    } else {
      $PrBody
    }
    Set-Content -LiteralPath $bodyFile -Value $body -Encoding UTF8
    try {
      $prUrl = gh pr create --base $BaseBranch --head $currentBranch --title $PrTitle --body-file $bodyFile
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

  Write-Host '[cerrar-pr] Done. PR left open; no merge performed.' -ForegroundColor Green
} finally {
  Pop-Location
}
