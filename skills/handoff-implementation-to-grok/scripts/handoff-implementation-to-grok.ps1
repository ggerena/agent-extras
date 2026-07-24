param(
  [ValidatePattern('^[A-Za-z0-9._-]+$')]
  [string] $Invoker = 'codex',
  [ValidateSet('implement', 'review', 'closeout')]
  [string] $Mode = 'implement',
  [string] $Objective = '',
  [string] $ReviewSummary = '',
  [ValidateSet('pass', 'blocked', 'needs-user')]
  [string] $ReviewVerdict = 'pass',
  [string] $NextStep = '',
  [string] $RepoPath = '',
  [string] $WorkspaceRoot = '',
  [string] $HandoffRoot = '',
  [string] $PhaseId = '',
  [string] $PhaseDirectory = '',
  [string] $PlanPath = '',
  [ValidateSet('auto', 'full', 'verify', 'none')]
  [string] $PlanReadPolicy = 'auto',
  [switch] $RequireFullPlanRead,
  [string[]] $AllowedPaths = @(),
  [string[]] $ValidationCommands = @(),
  [string] $RuntimeSetupCommand = '',
  [string] $ReviewSkillPath = '',
  [string] $CloseoutAction = '',
  [switch] $AllowGitCloseout,
  [string] $GitRemote = 'origin',
  [string] $BaseBranch = 'develop',
  [string] $CommitMessage = '',
  [string] $PrTitle = '',
  [string] $PrBody = '',
  [switch] $UpdateExistingPr,
  [string] $GrokModel = 'grok-4.5',
  [ValidateSet('medium', 'high')]
  [string] $GrokReasoningEffort = '',
  [string] $ReasoningRationale = '',
  [switch] $RequireReviewAfter,
  [switch] $SkipReviewGate,
  [switch] $ForceHandoff,
  [string] $ForceReason = '',
  [switch] $DryRun,
  [switch] $Launch
)

$ErrorActionPreference = 'Stop'

function Resolve-PythonCommand {
  $python = Get-Command python -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandType -in @('Application', 'ExternalScript') } |
    Select-Object -First 1
  if ($python -and $python.Source) {
    return [ordered]@{ executable = $python.Source; prefix = @() }
  }
  $launcher = Get-Command py -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandType -in @('Application', 'ExternalScript') } |
    Select-Object -First 1
  if ($launcher -and $launcher.Source) {
    return [ordered]@{ executable = $launcher.Source; prefix = @('-3') }
  }
  throw 'Python 3 is required. Install it or invoke scripts/grok_handoff.py from a Python 3 environment.'
}

function Add-StringArgument {
  param(
    [System.Collections.Generic.List[string]] $List,
    [string] $Name,
    [string] $Value
  )
  if (-not [string]::IsNullOrWhiteSpace($Value)) {
    $List.Add($Name)
    $List.Add($Value)
  }
}

function Add-SwitchArgument {
  param(
    [System.Collections.Generic.List[string]] $List,
    [string] $Name,
    [bool] $Enabled
  )
  if ($Enabled) { $List.Add($Name) }
}

$pythonCommand = Resolve-PythonCommand
$script = Join-Path $PSScriptRoot 'grok_handoff.py'
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
  throw "Portable handoff script not found: $script"
}

$arguments = [System.Collections.Generic.List[string]]::new()
foreach ($prefix in $pythonCommand.prefix) { $arguments.Add($prefix) }
$arguments.Add($script)
$arguments.Add('start')
Add-StringArgument $arguments '--invoker' $Invoker
Add-StringArgument $arguments '--mode' $Mode
Add-StringArgument $arguments '--objective' $Objective
Add-StringArgument $arguments '--review-summary' $ReviewSummary
Add-StringArgument $arguments '--review-verdict' $ReviewVerdict
Add-StringArgument $arguments '--next-step' $NextStep
Add-StringArgument $arguments '--repo-path' $RepoPath
Add-StringArgument $arguments '--workspace-root' $WorkspaceRoot
Add-StringArgument $arguments '--handoff-root' $HandoffRoot
Add-StringArgument $arguments '--phase-id' $PhaseId
Add-StringArgument $arguments '--phase-dir' $PhaseDirectory
Add-StringArgument $arguments '--plan-path' $PlanPath
Add-StringArgument $arguments '--plan-read-policy' $PlanReadPolicy
foreach ($path in $AllowedPaths) {
  Add-StringArgument $arguments '--allowed-path' $path
}
foreach ($command in $ValidationCommands) {
  Add-StringArgument $arguments '--validation-command' $command
}
Add-StringArgument $arguments '--runtime-setup-command' $RuntimeSetupCommand
Add-StringArgument $arguments '--review-skill-path' $ReviewSkillPath
Add-StringArgument $arguments '--closeout-action' $CloseoutAction
Add-StringArgument $arguments '--git-remote' $GitRemote
Add-StringArgument $arguments '--base-branch' $BaseBranch
Add-StringArgument $arguments '--commit-message' $CommitMessage
Add-StringArgument $arguments '--pr-title' $PrTitle
Add-StringArgument $arguments '--pr-body' $PrBody
Add-StringArgument $arguments '--model' $GrokModel
Add-StringArgument $arguments '--reasoning-effort' $GrokReasoningEffort
Add-StringArgument $arguments '--reasoning-rationale' $ReasoningRationale
Add-StringArgument $arguments '--force-reason' $ForceReason
Add-SwitchArgument $arguments '--require-full-plan-read' $RequireFullPlanRead.IsPresent
Add-SwitchArgument $arguments '--allow-git-closeout' $AllowGitCloseout.IsPresent
Add-SwitchArgument $arguments '--update-existing-pr' $UpdateExistingPr.IsPresent
Add-SwitchArgument $arguments '--require-review-after' $RequireReviewAfter.IsPresent
Add-SwitchArgument $arguments '--skip-review-gate' $SkipReviewGate.IsPresent
Add-SwitchArgument $arguments '--force-handoff' $ForceHandoff.IsPresent
Add-SwitchArgument $arguments '--dry-run' $DryRun.IsPresent
Add-SwitchArgument $arguments '--launch' $Launch.IsPresent

& $pythonCommand.executable @arguments
exit $LASTEXITCODE
