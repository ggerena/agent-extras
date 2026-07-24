---
name: handoff-implementation-to-opencode
description: Use when Codex or Claude Code should remain the principal coordinator/reviewer but hand off implementation work to OpenCode with GLM-5.2 after a review gate. Triggers include "pasale la implementacion a OpenCode", "Claude principal y OpenCode implementa", "Codex principal y OpenCode implementa", "handoff implementation to GLM", or requests to review current state and then let OpenCode continue development. Do not use for PR close-out, merging, pushing, or a pure second opinion where ownership stays with the current agent.
---

# Handoff Implementation To OpenCode

Keep the current agent, Codex or Claude Code, in charge of planning and review, then transfer the implementation loop to OpenCode GLM-5.2 with a factual handoff.

## Workflow

1. Read the repo rules before acting.
2. Review the current state first:
   - If there is a PR or branch diff, use the local code review workflow when available.
   - If there is only a plan/spec, review the plan for gaps, risks, and missing context.
3. If the review finds blockers, stop and report them. Do not hand off unless the user explicitly says to continue anyway.
4. If the review passes, run `scripts/handoff-implementation-to-opencode.ps1` with the review summary and the correct `-Invoker`.
5. Tell the user where the handoff was written and whether OpenCode was launched.

The script writes the handoff itself, so this skill can work even when `agent-handoff` is not installed. It still follows the same safety rules: no merge, no push, no dev server, no deletion, and no remote operations.

## Run

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File skills\handoff-implementation-to-opencode\scripts\handoff-implementation-to-opencode.ps1 `
  -Invoker codex `
  -Objective "Implementar la siguiente fase de X" `
  -ReviewSummary "Review del agente coordinador: sin bloqueantes; validar tests despues de implementar." `
  -NextStep "Implementar X respetando AGENTS.md y correr validaciones razonables."
```

From Claude Code, pass `-Invoker claude`:

```powershell
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\.claude\skills\handoff-implementation-to-opencode\scripts\handoff-implementation-to-opencode.ps1 `
  -Invoker claude `
  -Objective "Implementar la siguiente fase de X" `
  -ReviewSummary "Review de Claude Code: sin bloqueantes; devolver validaciones para revision." `
  -NextStep "Implementar X en OpenCode GLM-5.2 y dejar un resumen de cambios."
```

Dry run:

```powershell
powershell -ExecutionPolicy Bypass -File skills\handoff-implementation-to-opencode\scripts\handoff-implementation-to-opencode.ps1 `
  -Invoker codex `
  -Objective "Probar handoff" `
  -ReviewSummary "Review del agente coordinador: sin bloqueantes." `
  -NextStep "Continuar implementacion." `
  -DryRun
```

Launch OpenCode after writing the handoff:

```powershell
powershell -ExecutionPolicy Bypass -File skills\handoff-implementation-to-opencode\scripts\handoff-implementation-to-opencode.ps1 `
  -Invoker codex `
  -Objective "Implementar X" `
  -ReviewSummary "Review del agente coordinador: sin bloqueantes." `
  -NextStep "Continuar implementacion." `
  -Launch
```

## Script Behavior

`scripts/handoff-implementation-to-opencode.ps1`:

1. Requires `-ReviewSummary` or `-ReviewFile` unless `-SkipReviewGate` is explicit.
2. Blocks handoff when `-ReviewVerdict blocked` or `-ReviewVerdict needs-user` unless `-ForceHandoff` is passed.
3. Captures repo state directly with git: branch, HEAD, status, recent log, unstaged diff stat, and staged diff stat.
4. Writes `docs/YYYYMMDD_HANDOFF-<invoker>-to-opencode.md`, a prompt file, and `docs/HANDOFF-index.md`.
5. Defaults to `opencode-go/glm-5.2` and `-OpenCodeVariant max`; treat any user request for GLM as OpenCode Go with `opencode-go/glm-5.2`.
6. Records the review gate inside the handoff `Validaciones` section.

## Defaults

- `-RepoPath`: current working directory.
- `-OutDir`: `docs`.
- `-Invoker`: `codex`. Use `claude` when running from Claude Code.
- `-Reason`: `<invoker> remains principal coordinator/reviewer; OpenCode GLM-5.2 continues implementation after review gate.`
- `-OpenCodeModel`: `opencode-go/glm-5.2`.
- `-OpenCodeVariant`: `max`.

## Safety

- Keep the invoking agent as the planner/reviewer and OpenCode as the implementation worker.
- Do not hand off if the review found concrete blockers unless the user explicitly accepts that risk.
- Do not use this skill for commit, push, PR creation, or merge. Use `auto-pr-review` only when the user explicitly authorizes those operations.
- Do not start dev servers.
- Keep review notes factual and concise; do not include secrets.
- Do not require or call `agent-handoff`; keep this skill self-contained.
