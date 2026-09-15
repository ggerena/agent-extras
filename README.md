# agent-extras

Small collection of agent skills and helper scripts.

For the skills listed below, `skills/` is the editable source. Keep the active installation for
the current agent synchronized in the same change; do not maintain divergent copies.

## Current skills

- `skills/agent-handoff`: creates handoff notes for moving work between coding agents.
- `skills/cerrar-pr`: reviews and corrects completed changes, verifies them, commits and pushes a safe branch, and opens or updates its PR.
- `skills/autodev`: executes an existing plan through tests, local review, and reviewed PRs.
- `skills/cambio-minimo`: favors the smallest maintainable implementation that solves the verified need.
- `skills/code-review`: reviews PRs and branch diffs without modifying files.
- `skills/diagnostico-con-evidencia`: diagnoses failures through reproduction and evidence before correction.
- `skills/km-analyze`: analyzes repository health with the `km` metrics CLI.
- `skills/mira`: provides a deliberately shallow README-only repository overview.
- `skills/retrospectiva-agentes`: turns observed agent-session friction into small, evidence-based improvements, with emphasis on reducing repeated context and calls.

## Retired backups

These remain for recovery or historical reference and should not be installed as active skills:

- `skills/differential-review`: superseded by direct review plus the available delegation mechanism.
- `skills/fin-sesion`: superseded by persistent project memory, `code-review`, and `cerrar-pr`.
- `skills/source-command-autodev` and `skills/source-command-fin`: legacy source-command versions.

## Platform notes

Most scripts are written in PowerShell and can run on Windows, macOS, or Linux when PowerShell 7+ (`pwsh`) is installed. `agent-handoff` also includes a Bash implementation for macOS/Linux.

## Repository scope

This repository is intentionally lightweight. It should not contain application code, build artifacts, local backups, private memories, credentials, or machine-specific configuration.
