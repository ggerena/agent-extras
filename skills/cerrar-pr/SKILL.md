---
name: cerrar-pr
description: Respalda temprano cambios de repositorios de codigo en una rama y PR borrador, y cierra la implementacion con pruebas y revision obligatorias. Usar durante cambios solicitados cuando las instrucciones vigentes autoricen ese respaldo, o con autorizacion puntual de commit, push y PR; no hacer merge ni sustituir excepciones documentales aplicables.
---

# Cerrar PR

Back up requested code changes early in a feature branch and draft PR, then stabilize the same
branch and PR through verification and review. Request review from another agent only when the
user or applicable instructions ask for it. This skill does not replace repo rules.

## Before Running

Before either mode:

- Confirm publication is authorized: a standing instruction to back up requested code changes
  covers their scoped commits, pushes, and draft PR without asking again. A narrower restriction
  takes precedence. Follow documentary direct-push exceptions in applicable client or project
  instructions; do not duplicate their repository list here. Those workflows remain outside this
  PR workflow and script.
- The current branch is a feature branch, not `develop`, `main`, or `master`.
- Inspect the complete outgoing diff, staged files and unpushed commits for secrets, sensitive
  data, unrelated changes, generated files, and unwanted attribution. Do not publish these. The
  script does not replace this inspection. Use scoped staging and preserve others' local changes.
- Resolve the intended remote repository and base branch. Do not publish if their identity or
  access is uncertain.

Choose one mode:

- **Early backup (`-Backup`):** publish the first scoped code change without waiting for complete
  tests or reviews. Create a draft PR and repeat checkpoints after meaningful changes/corrections,
  updating that same branch and PR. Report failed, pending or unrun checks honestly (`NO PROBADO`
  when unverified); they block completion, not safe backup. Do not claim `-ReviewPassed` here.
- **Reviewed close-out (without `-Backup`):** finish the mandatory loop below and pass
  `-ReviewPassed` only for the exact current diff. The script still leaves the PR draft; after
  publication, follow step 7 for remote checks, reviews and any readiness needed to trigger CI.

If an existing PR is ready, return it to draft before pushing another iteration. Keep the work
incomplete until all required tests and reviews pass with no pending findings or reviews. Keep the
PR draft too, unless applicable repository rules require `ready` to trigger CI; in that case,
readiness starts validation and does not assert completion. A new commit invalidates prior
completion evidence for that head. Approval or readiness never authorizes merge: require an
explicit merge request in the current session.

## Mandatory Local Review Loop

Run this loop after implementation and before declaring completion, not before early backup:

Evidence from an enclosing workflow satisfies the same gate when it covers the exact content,
base and environment. Do not rerun an unchanged check or review merely because both skills mention
it; repeat after a change, failure, uncertainty or an explicit fresh-run requirement.

1. Run the repo's relevant tests, lint, build, or equivalent non-destructive verification.
2. Invoke `code-review` (`/revisa`) against the complete current branch and working-tree diff. The review itself stays read-only.
3. Validate every finding. Immediately correct valid high and medium findings. Correct low findings only when the change is direct, safe, and remains within the original scope.
4. Add or update tests for each correction, then rerun the relevant verification.
5. Repeat `/revisa` until no valid high or medium findings remain. Keep other unresolved findings
   visible; they block completion, while readiness follows the CI trigger policy in step 7.
6. Publish corrections with `-Backup` as needed. Invoke the reviewed mode with `-ReviewPassed`
   only after the relevant verification and local review passed for the current diff.
7. Confirm the published head matches the locally verified code and follow the repository's CI
   trigger policy. If required CI runs only for ready PRs, use `gh pr ready` after the local gate to
   start it, without declaring completion. Otherwise keep the PR draft until required remote checks
   and reviews pass. Address remaining failures or findings and return the PR to draft before any
   corrective push. Completion still requires all applicable evidence on the current head.

The correction loop is already part of finishing the authorized implementation; do not pause merely
because a valid high or medium finding appeared. Stop and ask only when a correction requires a
material product decision, broader scope, destructive action, new access, or another authorization.

## Optional External Review

External review is separate from this script and requires authorization for that
PR. Use a suitable subagent available in the current environment, after the PR exists, following
that client's delegation policy and preserving the requested reviewer and read-only or
implementation scope. Another review must come from a distinct agent or session; if unavailable,
report the limitation rather than substituting self-review. Sending work outside the current
environment requires explicit authorization. Do not make external review a prerequisite for
creating the PR.

## Run It

Early backup from the repo root, after the publication-safety inspection:

```powershell
& <skill-root>\scripts\cerrar-pr.ps1 `
  -BaseBranch develop -CommitMessage "Start feature" -PrTitle "Implement feature" `
  -Pathspec @("src", "tests") -Backup -ConfirmedByUser
```

`-ConfirmedByUser` asserts the publication authority checked above, including an applicable
standing instruction; it does not require a new routine confirmation for every code checkpoint.

Reviewed close-out, after the mandatory local loop:

```powershell
$paths = @("src", "tests", "docs")
& <skill-root>\scripts\cerrar-pr.ps1 `
  -BaseBranch develop `
  -CommitMessage "Implement feature" `
  -PrTitle "Implement feature" `
  -Pathspec $paths `
  -ReviewPassed `
  -ConfirmedByUser
```

Use `-VerificationCommand` only for a relevant check that has not already run for this exact
content; it is not a reason to duplicate verified work.

Use `-StageAll` only when every changed file belongs to the implementation. Prefer `-Pathspec` for scoped changes.

Dry run:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\cerrar-pr.ps1 -DryRun -Backup -CommitMessage "..." -PrTitle "..."
```

## Script Behavior

`scripts/cerrar-pr.ps1`:

1. Reads repo state and blocks protected branches.
2. Requires publication authority; reviewed mode also requires `-ReviewPassed` as the caller's
   assertion that the mandatory local review loop passed. `-Backup` never asserts completion.
3. Prints `git status --short`, `git diff --stat`, and staged diff stats.
4. Runs provided verification commands after rejecting known dev-server commands.
5. Stages either explicit `-Pathspec` entries or all files when `-StageAll` is passed.
6. Creates a commit only when staged changes exist and `-CommitMessage` is provided.
7. Checks for an existing PR and converts it to draft before pushing; an unreadable PR state or
   failed conversion stops the push. Pushes to `private` when available, otherwise `origin`.
8. Creates a draft PR toward `-BaseBranch`, or reuses the existing draft. It never marks ready or
   merges. The caller follows step 7 for remote-head evidence and readiness.

Offline regression checks: `powershell -NoProfile -File <skill-root>\scripts\test-cerrar-pr.ps1`.
These checks mock Git and GitHub; they do not publish anything.

## Safety Rules

- Require `-ConfirmedByUser` unless `-DryRun` is used only for inspection.
- Require `-ReviewPassed` before reviewed close-out; use `-Backup` for incomplete code checkpoints.
- Never run `gh pr merge`, `git merge`, force-push, rebase, or amend.
- Never push directly to `develop`, `main`, or `master`.
- Never start dev servers. The script rejects common commands such as `npm run dev`, `yarn dev`, `npm start`, and `preview_start`.
- Run browser smoke tests only when explicitly requested; ordinary relevant automated tests,
  lint and builds remain required. Report an unperformed required check rather than claiming it.
- Keep external review outside this script and require explicit authorization before sending it.
- Keep review ownership with the current agent. External review is input, not authorization to merge.

## Install

Single source lives in `skills/cerrar-pr` in this repo. Install only to authorized agent homes;
the installer can also modify other agents, so do not run it without that explicit scope:

```powershell
powershell -ExecutionPolicy Bypass -File skills\cerrar-pr\scripts\install.ps1 -Force
```

Targets:

- `%USERPROFILE%\.codex\skills\cerrar-pr`
- `%USERPROFILE%\.agents\skills\cerrar-pr`
- `%USERPROFILE%\.claude\skills\cerrar-pr`
