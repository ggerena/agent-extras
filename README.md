# agent-extras

Small collection of agent skills and helper scripts.

## Contents

- `skills/agent-handoff`: creates handoff notes for moving work between coding agents.
- `skills/cerrar-pr`: reviews and corrects completed changes, verifies them, commits and pushes a safe branch, and opens or updates its PR.
- `skills/differential-review`: asks another agent to challenge an analysis, plan, or pending implementation.
- `skills/source-command-autodev`: runs a planned implementation autonomously and leaves PRs open.
- `skills/source-command-fin`: records session context and backs up unfinished work in a PR.

## Platform notes

Most scripts are written in PowerShell and can run on Windows, macOS, or Linux when PowerShell 7+ (`pwsh`) is installed. `agent-handoff` also includes a Bash implementation for macOS/Linux.

## Repository scope

This repository is intentionally lightweight. It should not contain application code, build artifacts, local backups, private memories, credentials, or machine-specific configuration.
