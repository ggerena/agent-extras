---
name: cerrar-pr
description: Cierra una implementación terminada con un ciclo obligatorio de revisión local, corrección de hallazgos altos y medios, verificación, commit, push en una rama segura y creación o actualización de un PR. Usar solo cuando el usuario autorice explícitamente commit, push y PR en la sesión actual; no usar para iniciar una implementación ni hacer merge.
---

# Cerrar PR

Finish an implementation by reviewing and stabilizing the local changes before turning them into a PR.
Request review from another agent only when the user explicitly asks for it. This skill orchestrates
close-out; it does not replace repo rules.

## Before Running

Use this skill only when all are true:

- The implementation is complete enough to review.
- The user explicitly authorized commit, push, and PR creation in the current session.
- The current branch is a feature branch, not `develop`, `main`, or `master`.
- The mandatory local review loop below has finished with no valid high or medium findings.

Do not use this skill to merge. A PR opened by this skill must remain open until the user explicitly asks for merge in the same session.

## Mandatory Local Review Loop

Run this loop after every implementation and before invoking the script:

1. Run the repo's relevant tests, lint, build, or equivalent non-destructive verification.
2. Invoke `code-review` (`/revisa`) against the complete current branch and working-tree diff. The review itself stays read-only.
3. Validate every finding. Immediately correct valid high and medium findings. Correct low findings only when the change is direct, safe, and remains within the original scope.
4. Add or update tests for each correction, then rerun the relevant verification.
5. Repeat `/revisa` until no valid high or medium findings remain.
6. Invoke the script with `-ReviewPassed` only after this stopping condition is true.

The correction loop is already part of finishing the authorized implementation; do not pause merely
because a valid high or medium finding appeared. Stop and ask only when a correction requires a
material product decision, broader scope, destructive action, new access, or another authorization.

## Optional External Review

External review is separate from this close-out script and requires explicit authorization for that
PR. From Codex, use `mandalo-por-buzz` after the PR exists, preserving the requested reviewer and
read-only or implementation scope. In other agents, use the available explicitly authorized
delegation mechanism. Do not make external review a prerequisite for creating the PR.

## Run It

From the repo root:

```powershell
$checks = @("cargo fmt --check", "cargo test --lib")
$paths = @("src", "tests", "docs")
& <skill-root>\scripts\cerrar-pr.ps1 `
  -BaseBranch develop `
  -CommitMessage "Implement feature" `
  -PrTitle "Implement feature" `
  -Pathspec $paths `
  -VerificationCommand $checks `
  -ReviewPassed `
  -ConfirmedByUser
```

Use `-StageAll` only when every changed file belongs to the implementation. Prefer `-Pathspec` for scoped changes.

Dry run:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\cerrar-pr.ps1 -DryRun -ReviewPassed -ConfirmedByUser -CommitMessage "..." -PrTitle "..."
```

## Script Behavior

`scripts/cerrar-pr.ps1`:

1. Reads repo state and blocks protected branches.
2. Requires `-ReviewPassed` as the caller's assertion that the mandatory local review loop passed.
3. Prints `git status --short`, `git diff --stat`, and staged diff stats.
4. Runs provided verification commands after rejecting known dev-server commands.
5. Stages either explicit `-Pathspec` entries or all files when `-StageAll` is passed.
6. Creates a commit only when staged changes exist and `-CommitMessage` is provided.
7. Pushes the feature branch to `private` when available, otherwise `origin`.
8. Creates a PR toward `-BaseBranch`, or reuses an existing PR for the branch.

## Safety Rules

- Require `-ConfirmedByUser` unless `-DryRun` is used only for inspection.
- Require `-ReviewPassed` before any non-dry-run close-out operation.
- Never run `gh pr merge`, `git merge`, force-push, rebase, or amend.
- Never push directly to `develop`, `main`, or `master`.
- Never start dev servers. The script rejects common commands such as `npm run dev`, `yarn dev`, `npm start`, and `preview_start`.
- Keep external review outside this script and require explicit authorization before sending it.
- Keep review ownership with the current agent. External review is input, not authorization to merge.

## Install

Single source lives in `skills/cerrar-pr` in this repo. Replicate it to the three agent homes:

```powershell
powershell -ExecutionPolicy Bypass -File skills\cerrar-pr\scripts\install.ps1 -Force
```

Targets:

- `%USERPROFILE%\.codex\skills\cerrar-pr`
- `%USERPROFILE%\.agents\skills\cerrar-pr`
- `%USERPROFILE%\.claude\skills\cerrar-pr`
