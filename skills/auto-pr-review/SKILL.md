---
name: auto-pr-review
description: >-
  Use when Codex, OpenCode, or Claude Code has finished an implementation and the user has explicitly
  authorized the operational close-out in the current session: verify locally, show git status/diff,
  commit, push a feature branch, create or update a PR, and request external code review from another
  agent before merge. Prefer Claude as reviewer for Codex/OpenCode work. Never use for merging PRs,
  pushing protected branches, or committing without explicit user authorization.
---

# Auto PR Review

Finish an implementation by turning local changes into a PR and asking another agent to review it.
This skill orchestrates close-out; it does not replace repo rules.

## Before Running

Use this skill only when all are true:

- The implementation is complete enough to review.
- The user explicitly authorized commit, push, and PR creation in the current session.
- The current branch is a feature branch, not `develop`, `main`, or `master`.
- Local verification appropriate for the repo has run or is passed through `-VerificationCommand`.

Do not use this skill to merge. A PR opened by this skill must remain open until the user explicitly asks for merge in the same session.

## Reviewer Choice

- From Codex: use `-Invoker codex -Reviewer claude` by default.
- From OpenCode: use `-Invoker opencode -Reviewer claude` by default.
- From Claude Code: use `-Invoker claude -Reviewer codex`.
- Use `-Reviewer opencode` only when the user requests GLM/OpenCode or Claude is unavailable.

The bundled script calls `differential-review`, so self-review protection still applies.

## Run It

From the repo root:

```powershell
$checks = @("cargo fmt --check", "cargo test --lib")
$paths = @("src", "tests", "docs")
& <skill-root>\scripts\auto-pr-review.ps1 `
  -Invoker codex `
  -Reviewer claude `
  -BaseBranch develop `
  -CommitMessage "Implement feature" `
  -PrTitle "Implement feature" `
  -Pathspec $paths `
  -VerificationCommand $checks `
  -ConfirmedByUser
```

Use `-StageAll` only when every changed file belongs to the implementation. Prefer `-Pathspec` for scoped changes.

Dry run:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\auto-pr-review.ps1 -DryRun -ConfirmedByUser -CommitMessage "..." -PrTitle "..."
```

## Script Behavior

`scripts/auto-pr-review.ps1`:

1. Reads repo state and blocks protected branches.
2. Prints `git status --short`, `git diff --stat`, and staged diff stats.
3. Runs provided verification commands after rejecting known dev-server commands.
4. Stages either explicit `-Pathspec` entries or all files when `-StageAll` is passed.
5. Creates a commit only when staged changes exist and `-CommitMessage` is provided.
6. Pushes the feature branch to `private` when available, otherwise `origin`.
7. Creates a PR toward `-BaseBranch`, or reuses an existing PR for the branch.
8. Requests external review with `differential-review`, preferring Claude.

## Safety Rules

- Require `-ConfirmedByUser` unless `-DryRun` is used only for inspection.
- Never run `gh pr merge`, `git merge`, force-push, rebase, or amend.
- Never push directly to `develop`, `main`, or `master`.
- Never start dev servers. The script rejects common commands such as `npm run dev`, `yarn dev`, `npm start`, and `preview_start`.
- Keep review ownership with the current agent. External review is input, not authorization to merge.

## Install

Single source lives in `skills/auto-pr-review` in this repo. Replicate it to the three agent homes:

```powershell
powershell -ExecutionPolicy Bypass -File skills\auto-pr-review\scripts\install.ps1 -Force
```

Targets:

- `%USERPROFILE%\.codex\skills\auto-pr-review`
- `%USERPROFILE%\.agents\skills\auto-pr-review`
- `%USERPROFILE%\.claude\skills\auto-pr-review`
