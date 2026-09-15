param([string] $ScriptPath = (Join-Path $PSScriptRoot 'cerrar-pr.ps1'))

$ErrorActionPreference = 'Stop'
$script:Passed = 0

# These functions shadow every external command used by cerrar-pr.ps1. Unexpected
# commands fail instead of falling back to a real repository, process, or network.
function git {
  $call = @($args)
  $global:CerrarPrTestState.Events.Add('git ' + ($call -join ' '))
  $global:LASTEXITCODE = 0
  switch ($call[0]) {
    'rev-parse' {
      if ($call[1] -eq '--is-inside-work-tree') { return 'true' }
      if ($call[1] -eq '--abbrev-ref') { return $global:CerrarPrTestState.Branch }
      throw 'Unexpected rev-parse call.'
    }
    'remote' {
      if ($call.Count -eq 1) { return @('origin', 'private') }
      if (($call[1..3] -join ' ') -ne 'get-url --push --all' -or $call[4] -ne 'private') {
        throw 'Unexpected remote selection.'
      }
      return $global:CerrarPrTestState.PushUrls
    }
    'status' { return ' M src/feature.ps1' }
    'diff' {
      if ($call -contains '--name-only') { return 'src/feature.ps1' }
      return 'src/feature.ps1 | 1 +'
    }
    'add' { return }
    'commit' { return }
    'push' {
      if ($null -ne $global:CerrarPrTestState.Pr -and -not $global:CerrarPrTestState.Pr.isDraft) {
        throw 'Unsafe push: an existing PR is still ready.'
      }
      $global:LASTEXITCODE = $global:CerrarPrTestState.PushExit
      return
    }
    default { throw "Unexpected git command: $($call -join ' ')" }
  }
}

function gh {
  $call = @($args)
  $global:CerrarPrTestState.Events.Add('gh ' + ($call -join ' '))
  $global:LASTEXITCODE = 0
  $repoIndex = [array]::IndexOf($call, '--repo')
  if ($repoIndex -lt 0 -or $call[$repoIndex + 1] -ne 'github.com/example/private-repo') {
    throw 'GitHub command is not scoped to the selected push repository.'
  }
  switch ($call[1]) {
    'list' {
      if ($call -contains '--base') { throw 'PR lookup must not hide a different-base PR.' }
      $global:LASTEXITCODE = $global:CerrarPrTestState.ListExit
      if ($null -ne $global:CerrarPrTestState.RawJson) { return $global:CerrarPrTestState.RawJson }
      if ($null -eq $global:CerrarPrTestState.Pr) { return '[]' }
      return '[' + ($global:CerrarPrTestState.Pr | ConvertTo-Json -Compress) + ']'
    }
    'ready' {
      if ($call -notcontains '--undo') { throw 'Tests must never mark a PR ready.' }
      $global:LASTEXITCODE = $global:CerrarPrTestState.DraftExit
      if ($global:CerrarPrTestState.DraftExit -eq 0 -and $global:CerrarPrTestState.ConfirmDraft) {
        $global:CerrarPrTestState.Pr.isDraft = $true
      }
      return
    }
    'create' {
      if ($call -notcontains '--draft') { throw 'New PR is not draft.' }
      $bodyIndex = [array]::IndexOf($call, '--body-file')
      $global:CerrarPrTestState.Body = Get-Content -Raw -LiteralPath $call[$bodyIndex + 1]
      $global:LASTEXITCODE = $global:CerrarPrTestState.CreateExit
      return 'https://github.com/example/private-repo/pull/1'
    }
    default { throw "Unexpected gh command: $($call -join ' ')" }
  }
}

function powershell {
  $global:CerrarPrTestState.Events.Add('verification')
  $global:LASTEXITCODE = $global:CerrarPrTestState.VerificationExit
}

function Assert-True {
  param([bool] $Condition, [string] $Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-Case {
  param(
    [string] $Name,
    [hashtable] $Options = @{},
    [scriptblock] $Setup = {},
    [string] $ExpectedError = '',
    [scriptblock] $Verify = {}
  )
  $global:CerrarPrTestState = [pscustomobject]@{
    Events = [System.Collections.Generic.List[string]]::new()
    Branch = 'feature/backup'
    PushUrls = @('https://github.com/example/private-repo.git')
    Pr = $null
    RawJson = $null
    ListExit = 0
    DraftExit = 0
    ConfirmDraft = $true
    VerificationExit = 0
    PushExit = 0
    CreateExit = 0
    Body = ''
  }
  & $Setup
  $parameters = @{
    RepoPath = $PSScriptRoot
    CommitMessage = 'Implement feature'
    PrTitle = 'Implement feature'
    Pathspec = @('src/feature.ps1')
    ConfirmedByUser = $true
    Backup = $true
  }
  foreach ($key in $Options.Keys) { $parameters[$key] = $Options[$key] }
  $caught = ''
  try { & $ScriptPath @parameters *> $null } catch { $caught = $_.Exception.Message }
  if ($ExpectedError) {
    Assert-True ($caught -like "*$ExpectedError*") "$Name expected '$ExpectedError', got '$caught'."
    if ($ExpectedError -notlike '*gh pr create failed*') {
      Assert-True (@($global:CerrarPrTestState.Events | Where-Object { $_ -like 'git push *' }).Count -eq 0) "$Name pushed despite a blocker."
    }
  } else {
    Assert-True (-not $caught) "$Name failed: $caught"
  }
  & $Verify
  $script:Passed++
  Write-Output "PASS $Name"
}

function Set-ExistingPr {
  param([bool] $Draft = $false)
  $global:CerrarPrTestState.Pr = [pscustomobject]@{
    url = 'https://github.com/example/private-repo/pull/1'
    isDraft = $Draft
    baseRefName = 'develop'
    isCrossRepository = $false
  }
}

Invoke-Case 'Unreviewed backup creates a draft' -Verify {
  Assert-True ($global:CerrarPrTestState.Events -contains 'git push -u private feature/backup') 'Backup was not pushed.'
  Assert-True (@($global:CerrarPrTestState.Events | Where-Object { $_ -like 'gh pr create *' }).Count -eq 1) 'Draft was not created.'
  Assert-True ($global:CerrarPrTestState.Body -notmatch 'cerrar-pr|passed|approved') 'Default body claims completion or adds workflow attribution.'
}
Invoke-Case 'Reviewed close-out also leaves draft' -Options @{ Backup = $false; ReviewPassed = $true; VerificationCommand = @('unit-tests') } -Verify {
  Assert-True ($global:CerrarPrTestState.Events -contains 'verification') 'Verification was not executed.'
  Assert-True (@($global:CerrarPrTestState.Events | Where-Object { $_ -like 'gh pr create *' }).Count -eq 1) 'Reviewed draft was not created.'
}
Invoke-Case 'Authorization is still required' -Options @{ ConfirmedByUser = $false } -ExpectedError 'without -ConfirmedByUser'
Invoke-Case 'Reviewed mode still requires its gate' -Options @{ Backup = $false } -ExpectedError 'finish verification'
Invoke-Case 'Modes cannot claim contradictory states' -Options @{ ReviewPassed = $true } -ExpectedError 'not both'
Invoke-Case 'Existing ready PR becomes draft before push' -Setup { Set-ExistingPr } -Verify {
  $events = $global:CerrarPrTestState.Events.ToArray()
  $draftEvent = @($events | Where-Object { $_ -like 'gh pr ready *' })[0]
  Assert-True ([array]::IndexOf($events, $draftEvent) -lt [array]::IndexOf($events, 'git push -u private feature/backup')) 'Conversion happened after push.'
  Assert-True (@($events | Where-Object { $_ -like 'gh pr list *' }).Count -eq 2) 'Draft state was not rechecked.'
  Assert-True (@($events | Where-Object { $_ -like 'gh pr create *' }).Count -eq 0) 'Existing PR was duplicated.'
}
Invoke-Case 'Reviewed updates also return ready PR to draft' -Options @{ Backup = $false; ReviewPassed = $true } -Setup { Set-ExistingPr }
Invoke-Case 'Existing draft is reused' -Setup { Set-ExistingPr -Draft $true } -Verify {
  Assert-True (@($global:CerrarPrTestState.Events | Where-Object { $_ -like 'gh pr ready *' -or $_ -like 'gh pr create *' }).Count -eq 0) 'Existing draft was recreated or changed readiness.'
}
Invoke-Case 'Multiline native JSON is accepted' -Setup {
  $global:CerrarPrTestState.RawJson = @('[', '{"url":"https://github.com/example/private-repo/pull/1","isDraft":true,"baseRefName":"develop","isCrossRepository":false}', ']')
}
Invoke-Case 'Draft conversion failure blocks push' -Setup { Set-ExistingPr; $global:CerrarPrTestState.DraftExit = 1 } -ExpectedError 'Cannot convert existing PR'
Invoke-Case 'Unconfirmed draft blocks push' -Setup { Set-ExistingPr; $global:CerrarPrTestState.ConfirmDraft = $false } -ExpectedError 'Draft state was not confirmed'
Invoke-Case 'PR lookup failure blocks push' -Setup { $global:CerrarPrTestState.ListExit = 1 } -ExpectedError 'Cannot determine existing PR state'
Invoke-Case 'Missing PR state blocks push' -Setup { $global:CerrarPrTestState.RawJson = '[{"url":"https://github.com/example/private-repo/pull/1","baseRefName":"develop","isCrossRepository":false}]' } -ExpectedError 'unknown state'
Invoke-Case 'Fork PR with matching branch cannot be mistaken for target' -Setup { Set-ExistingPr; $global:CerrarPrTestState.Pr.isCrossRepository = $true } -ExpectedError 'cross-repository'
Invoke-Case 'Invalid JSON blocks push' -Setup { $global:CerrarPrTestState.RawJson = 'null' } -ExpectedError 'Invalid PR list'
Invoke-Case 'Different-base PR cannot evade draft guard' -Setup { Set-ExistingPr; $global:CerrarPrTestState.Pr.baseRefName = 'main' } -ExpectedError 'different base'
Invoke-Case 'Multiple PRs require disambiguation' -Setup { $global:CerrarPrTestState.RawJson = '[{},{}]' } -ExpectedError 'Multiple open PRs'
Invoke-Case 'Missing title blocks unpaired push' -Options @{ PrTitle = '' } -ExpectedError 'Provide -PrTitle'
foreach ($branchName in @('main', 'master', 'develop', 'HEAD')) {
  Invoke-Case "Protected or detached branch $branchName" -Setup { $global:CerrarPrTestState.Branch = $branchName } -ExpectedError 'Refusing to push directly'
}
Invoke-Case 'Multiple push URLs require disambiguation' -Setup { $global:CerrarPrTestState.PushUrls = @('https://github.com/example/one.git', 'https://github.com/example/two.git') } -ExpectedError 'Exactly one push URL'
Invoke-Case 'Unknown destination cannot be published' -Setup { $global:CerrarPrTestState.PushUrls = @('C:\local\repo.git') } -ExpectedError 'Cannot safely identify'
Invoke-Case 'SSH push URL selects correct repository' -Setup { $global:CerrarPrTestState.PushUrls = @('git@github.com:example/private-repo.git') }
Invoke-Case 'Failed reviewed verification stops publication' -Options @{ Backup = $false; ReviewPassed = $true; VerificationCommand = @('unit-tests') } -Setup { $global:CerrarPrTestState.VerificationExit = 1 } -ExpectedError 'failed with exit code 1'
Invoke-Case 'Dev server verification remains forbidden' -Options @{ VerificationCommand = @('npm run dev') } -ExpectedError 'dev server'
Invoke-Case 'Conflicting staging options remain forbidden' -Options @{ StageAll = $true } -ExpectedError 'either -StageAll or -Pathspec'
Invoke-Case 'Dry run never mutates or calls GitHub' -Options @{ DryRun = $true; ConfirmedByUser = $false; VerificationCommand = @('unit-tests') } -Verify {
  Assert-True (@($global:CerrarPrTestState.Events | Where-Object { $_ -match '^gh |^git (push|commit|add) |^verification$' }).Count -eq 0) 'Dry run performed an external operation.'
}
Invoke-Case 'PR creation failure is reported after backup push' -Setup { $global:CerrarPrTestState.CreateExit = 1 } -ExpectedError 'gh pr create failed'

Write-Output "Passed $script:Passed offline regression checks. No real Git or GitHub operations were performed."
