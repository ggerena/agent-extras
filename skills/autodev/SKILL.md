---
name: autodev
description: Ejecuta un plan de implementacion existente con respaldo temprano en PRs borrador para repos de codigo, cambios minimos, tests y revision obligatorios antes de darlo por listo. Usar con /autodev o para llevar un plan hasta PRs revisados; no crear el plan, desplegar, operar en Prod ni hacer merge.
---

# Autodev

Take an existing implementation plan through early draft backups and completed, reviewed pull requests. Reuse
`cambio-minimo` for implementation decisions, `code-review` for the read-only review gate,
and `cerrar-pr` for commit, push, and PR creation instead of duplicating those workflows.

## Authorization

An explicit `/autodev` request or an explicit request to execute a plan end to end authorizes the
in-scope local implementation, non-destructive verification, safe feature branches, commits, pushes,
and pull requests required by that plan. It never authorizes merge, deployment, production changes,
destructive actions, or expansion beyond the plan. A narrower user instruction takes precedence.
For code repositories, an applicable standing backup instruction also authorizes early publication
of requested changes without a new routine confirmation. Follow any documentary direct-push
exceptions in the applicable client or project instructions; do not duplicate their repository
list here. Those narrower workflows stay outside this PR workflow.

Do not invent a missing plan. If no usable plan exists, stop after identifying that prerequisite.

## Workflow

1. Locate and read the complete plan plus the applicable `AGENTS.md` and project instructions.
   Identify affected repositories, base branches, dependencies, success criteria, and phases. Before
   changing code, inspect relevant configuration, environment, and data state when they can explain
   or alter the requested behavior.
2. Create or reuse one safe feature branch per repository; never push directly to `main`, `master`,
   or `develop`, except when applicable instructions define a documentary direct-push workflow.
   Use a worktree only when applicable client and project instructions allow it and the isolation
   materially helps preserve local changes or parallel work; otherwise prefer the existing
   checkout and a normal branch.
3. Execute phases in dependency order. Apply `cambio-minimo` principles and include or update tests
   for every feature and bug fix. Follow the current project rules for any permitted delegation.
   Choose the current agent or a suitable subagent available in the current environment for each
   implementation phase, following that client's delegation policy. Keep one writer per repo and
   branch. If no subagent is available, implement directly when capable and authorized; do not
   replace an explicitly required independent reviewer with self-review. Delegation does not
   expand the authorized scope, access, or publication permissions.
4. In code repositories, invoke `cerrar-pr` in `-Backup` mode after the first scoped change and
   at meaningful implementation/correction checkpoints. Check secrets, unrelated staged files,
   outgoing commits and the intended remote before publication. Do not wait for the complete
   plan, tests or reviews to create the draft PR. Reuse the same branch and PR; convert a ready
   PR back to draft before a new push. Do not reproduce the Git/GitHub procedure here.
5. Run the relevant tests, lint, typecheck, build, or equivalent verification in every affected
   repository. Never start development servers. Browser smoke tests require an explicit request.
6. Run `code-review` (`/revisa`) over each complete branch and working-tree diff. Validate every
   finding, immediately correct valid high and medium findings, update tests, rerun verification,
   and repeat the review until no valid high or medium findings remain. Correct low findings only
   when the change is direct, safe, and within the plan.
   If the same verification and review already passed under an enclosing workflow for the exact
   content, base and environment, reuse that evidence. Repeat only after a change, failure,
   uncertainty or an instruction that explicitly requires a fresh run.
7. For repositories using the PR workflow, invoke `cerrar-pr` in reviewed mode after the local gate
   passes. Keep the work incomplete until required tests and reviews for the published head pass.
   Keep the PR draft unless repository rules require `ready` to trigger CI; then readiness starts
   validation but does not prove completion. Never merge automatically.
8. Update the plan only with states proven during this run, then report completed phases, verification
   evidence, branches, PR URLs, and remaining blockers.

## Stop Conditions

Incomplete implementation, failed/pending tests or reviews block completion; readiness follows the
CI trigger exception in step 7. They do not block a safe draft backup in a code repository. Preserve verified progress in the draft and continue
authorized corrections. Stop publication for secrets, unrelated changes that cannot be safely
excluded, uncertain destination, or missing publication authority. Stop the affected work for a
material product decision, destructive action, new access, production operation, or scope expansion
that the original plan did not authorize. Report blockers without claiming completion.

Never merge. Do not add workflow or AI attribution to commit messages, PR titles, or PR bodies.
