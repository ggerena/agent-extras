---
name: autodev
description: Ejecuta un plan de implementación existente de forma autónoma, con cambios mínimos, tests, revisión local obligatoria y PRs abiertos sin merge. Usar con /autodev o cuando el usuario pida llevar un plan completo hasta PRs revisados; no usar para crear el plan, desplegar ni operar en Prod.
---

# Autodev

Take an existing implementation plan through completed, reviewed pull requests. Reuse
`cambio-minimo` for implementation decisions, `code-review` for the read-only review gate,
and `cerrar-pr` for commit, push, and PR creation instead of duplicating those workflows.

## Authorization

An explicit `/autodev` request or an explicit request to execute a plan end to end authorizes the
in-scope local implementation, non-destructive verification, safe feature branches, commits, pushes,
and pull requests required by that plan. It never authorizes merge, deployment, production changes,
destructive actions, or expansion beyond the plan. A narrower user instruction takes precedence.

Do not invent a missing plan. If no usable plan exists, stop after identifying that prerequisite.

## Workflow

1. Locate and read the complete plan plus the applicable `AGENTS.md` and project instructions.
   Identify affected repositories, base branches, dependencies, success criteria, and phases. Before
   changing code, inspect relevant configuration, environment, and data state when they can explain
   or alter the requested behavior.
2. Create or reuse one safe feature branch per repository. Never push directly to `main`, `master`,
   or `develop`, and do not use worktrees unless the user explicitly requested them.
3. Execute phases in dependency order. Apply `cambio-minimo` principles and include or update tests
   for every feature and bug fix. Follow the current project rules for any permitted delegation;
   this skill does not require subagents or a specific external agent.
4. After implementation is complete, run the relevant tests, lint, typecheck, build, or equivalent
   verification in every affected repository. Never start development servers.
5. Run `code-review` (`/revisa`) over each complete branch and working-tree diff. Validate every
   finding, immediately correct valid high and medium findings, update tests, rerun verification,
   and repeat the review until no valid high or medium findings remain. Correct low findings only
   when the change is direct, safe, and within the plan.
6. Invoke `cerrar-pr` once per ready repository. Let that skill own staging, commit, push, and PR
   creation or update. Do not reproduce its Git or GitHub procedure here.
7. Update the plan only with states proven during this run, then report completed phases, verification
   evidence, branches, PR URLs, and remaining blockers.

## Stop Conditions

Stop before publishing a repository when the implementation is incomplete, required verification
fails, or the review gate cannot pass. Also stop for a material product decision, destructive action,
new access, production operation, or scope expansion that the original plan did not authorize.

Never merge. Do not add workflow or AI attribution to commit messages, PR titles, or PR bodies.

