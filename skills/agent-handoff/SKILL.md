---
name: agent-handoff
description: >-
  Use when an agent (Codex, Claude Code, or OpenCode) needs to hand off ongoing work to another
  agent because it got lost, hit a wall, started wasting time, or the user wants to switch who is
  in charge. Builds a self-contained handoff Markdown from objective repo state (git status, git
  log, git diff, BITACORA, repo rules) plus agent-supplied objective/reason/next step, and emits a
  ready prompt for the destination agent. First supported direction: Codex to OpenCode. Do not use
  for consultative second opinions that keep the same agent in charge; use differential-review for
  that.
---

# Agent Handoff

Transfer ownership of a piece of work to another agent with a ready-to-resume package. The first and validated direction is Codex -> OpenCode. Other directions (Claude -> Codex, OpenCode -> Claude, etc.) are parameterized but not yet validated end to end.

This is not a review. The origin agent stops being in charge and the destination agent continues.

## When to use

- The current agent got lost, is looping, or is making poor progress and the user wants another agent to take over.
- The user explicitly asks to "pass the ball" / "pasa la pelota" / "handoff" / "continua desde OpenCode" / "seguir en Codex" / "traspasa a Claude".
- A context switch is needed and manually summarizing state would lose facts.
- You are inside Codex and want OpenCode (or another agent) to continue from the exact repo state.

## When NOT to use

- You only want a second opinion while keeping ownership. Use `differential-review` instead.
- The task is small and a fresh agent can re-derive state in a few seconds.
- The destination agent has no way to read the repo (no shared filesystem). Hand off only when the destination can access the same repo path.

## How it works (modo portable)

1. The bundled script captures objective state from the repo, not from the agent's memory:
   - `git rev-parse --abbrev-ref HEAD` (current branch)
   - `git rev-parse HEAD` (current commit)
   - `git status --porcelain` (modified/untracked files)
   - `git log --oneline -20` (recent history)
   - `git diff --stat` (unstaged changes) and `git diff --cached --stat` (staged changes)
2. It detects repo rule files and notes which exist: `AGENTS.md`, `CLAUDE.md`, `LOCAL_CHANGES.md`, `BITACORA.md`. When `BITACORA.md` exists, the last 40 lines are embedded so the destination agent sees recent decisions without re-reading everything.
3. It reads agent-supplied context from parameters or a notes file:
   - objetivo original
   - motivo del traspaso
   - siguiente paso recomendado
   - dudas abiertas
4. It writes `docs/YYYYMMDD_HANDOFF-<from>-to-<to>.md` filled with facts, separating hechos comprobados, inferencias and dudas.
5. It writes `docs/HANDOFF-index.md` (or updates it) with the newest handoff at the top, so chained handoffs stay navigable.
6. It prints a ready prompt for the destination agent and the suggested launch command.

The origin agent does not push, merge, or start servers. It only writes the handoff Markdown and the index.

## Direction Codex -> OpenCode

From a Codex session, run the installed script:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\agent-handoff\scripts\agent-handoff.ps1" -From codex -To opencode -Objective "objetivo original en una linea" -Reason "por que se traspasa" -NextStep "siguiente paso recomendado"
```

On macOS/Linux from a Codex session:

```bash
bash ~/.agents/skills/agent-handoff/scripts/agent-handoff.sh -From codex -To opencode -Objective "objetivo original" -Reason "motivo" -NextStep "siguiente paso"
```

Output:

- `docs/YYYYMMDD_HANDOFF-codex-to-opencode.md`
- A prompt you can paste into an OpenCode session.
- A suggested `opencode run` one-shot command. In the observed local setup, that command records a session that appears in OpenCode Desktop, so the user can continue it there without opening another terminal.

The script does not auto-launch OpenCode by default. Pass `-Launch` to opt into a non-interactive `opencode run` first pass. The default is to print the command; when run, OpenCode Desktop can show the recorded session for continuation.

## Direction Codex -> Claude Code

Use the same script with `-To claude`. The command generator supports Claude model and effort options; for example, Codex high to Claude Code Opus 4.8 medium:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\agent-handoff\scripts\agent-handoff.ps1" -From codex -To claude -ClaudeModel claude-opus-4-8 -ClaudeEffort medium -Objective "objetivo original en una linea" -Reason "por que se traspasa" -NextStep "siguiente paso recomendado"
```

This writes the handoff Markdown and a prompt file, then prints a Claude Code command without `-p`, so Claude starts an interactive session. The command includes `--name`, making the handoff easy to find from `/resume`.

## Run it

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\agent-handoff.ps1 -From codex -To opencode -Objective "..." -Reason "..." -NextStep "..."
```

Read objective/reason/next step from a notes file the agent leaves:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\agent-handoff.ps1 -From codex -To opencode -NotesFile docs\handoff-notes.md
```

Dry run (print the Markdown and prompt without writing files):

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\agent-handoff.ps1 -From codex -To opencode -DryRun
```

Defaults:

- `<skill-root>` is the installed `agent-handoff` skill folder. The shared installed location is `~\.agents\skills\agent-handoff`; a checked-out repo copy can also run the scripts.
- `-From` defaults to `codex`, `-To` defaults to `opencode`.
- `-OutDir` defaults to `docs` inside the repo.
- `-RepoPath` defaults to the current working directory.
- `-OpenCodeModel` defaults to `opencode-go/glm-5.2`. The script normalizes `glm-5.2` to `opencode-go/glm-5.2`.
- `-OpenCodeVariant` defaults to `max`.
- `-ClaudeModel` defaults to `claude-opus-4-8`.
- `-ClaudeEffort` defaults to `medium`.
- `-ClaudePermissionMode` defaults to `plan`.
- `-BitacoraTail` defaults to `40` lines.

Overrides:

- `-From codex|claude|opencode` and `-To codex|claude|opencode` choose the direction.
- `-Objective`, `-Reason`, `-NextStep`, `-OpenQuestions` supply agent context inline.
- `-NotesFile` reads the same fields from a Markdown file (sections `## Objetivo`, `## Motivo`, `## Siguiente paso`, `## Dudas`).
- `-ClaudeModel`, `-ClaudeEffort`, and `-ClaudePermissionMode` customize the generated Claude Code command.
- `-Launch` opts into a non-interactive `opencode run` first pass when `-To opencode`.
- `-DryRun` prints without writing.

## Post-handoff protocol

After the handoff Markdown is written:

1. The origin agent stops making changes. It does not keep editing the repo in parallel.
2. The origin agent tells the user the handoff file path and the suggested command.
3. The destination agent starts by confirming: it read the objective, it saw the files touched, and it will respect the repo rules listed in the handoff. Only then does it proceed to the recommended next step.
4. If the destination agent also gets stuck, it writes a new handoff with `-From <itself> -To <next>`. The index keeps them navigable.

## Safety rules

- No merge, no push, no force-push. The script never touches git remotes.
- No starting dev servers. The script never launches long-running services.
- No deleting files or state. The script only writes the handoff Markdown and the index.
- No hiding errors. If the handoff happens because the agent got lost, the `-Reason` field must say so.
- Keep the handoff factual: hechos comprobados, inferencias, and dudas are separate sections.
- Do not include secrets in objective/reason/next step. The script does not strip them.

## Relation with differential-review

- `differential-review`: "review this and come back". Ownership stays.
- `agent-handoff`: "take the context and continue". Ownership moves.

They share some plumbing (path resolution, temp files, progress printing) but stay separate skills with separate scripts.

## Install

Single source lives in `skills/agent-handoff` in this repo. Run the installer to update the shared `.agents` skill install:

```powershell
powershell -ExecutionPolicy Bypass -File skills\agent-handoff\scripts\install.ps1
```

By default the installer skips a target if `agent-handoff` is already installed there, so it never replaces local edits silently. To replace an existing install from the repo source, run:

```powershell
powershell -ExecutionPolicy Bypass -File skills\agent-handoff\scripts\install.ps1 -Force
```

With `-Force`, the installer replaces the existing `.agents` install from the repo version. Previous versions should be recovered from Git history, not from installed backup folders.

The installer copies the skill to:

- `%USERPROFILE%\.agents\skills\agent-handoff`

Re-run it with `-Force` after any change to update the installed copy.

## Modes still pending

- Modo integrado Codex App: create/continue a Codex thread directly when the internal tools (`create_thread`, `fork_thread`, `send_message_to_thread`) are available. Not validated yet.
- OpenCode Desktop launch: `opencode run` creates a recorded session visible in OpenCode Desktop in the observed local setup. The script should not open a separate PowerShell window; continue from the Desktop session instead.
- Claude Code handoff to an already-open session: the script creates a new named interactive session; injecting into an existing Claude Code session is still manual.
- Handoff to an existing session instead of a fresh one: not supported yet.
