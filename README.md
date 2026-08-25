# agent-extras

Small collection of agent skills and helper scripts.

## Contents

- `skills/agent-handoff`: creates handoff notes for moving work between coding agents.
- `skills/cerrar-pr`: reviews and corrects completed changes, verifies them, commits and pushes a safe branch, and opens or updates its PR.
- `skills/differential-review`: asks another agent to challenge an analysis, plan, or pending implementation.
- `skills/autodev`: executes an existing plan through tests, local review, and reviewed PRs.
- `skills/fin-sesion`: preserves session context and closes completed changes through `cerrar-pr`.

## Platform notes

Most scripts are written in PowerShell and can run on Windows, macOS, or Linux when PowerShell 7+ (`pwsh`) is installed. `agent-handoff` also includes a Bash implementation for macOS/Linux.

## Repository scope

This repository is intentionally lightweight. It should not contain application code, build artifacts, local backups, private memories, credentials, or machine-specific configuration.
