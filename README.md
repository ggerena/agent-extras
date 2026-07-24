# agent-extras

Small collection of agent skills and helper scripts.

## Contents

- `skills/agent-handoff`: creates handoff notes for moving work between coding agents.
- `skills/auto-pr-review`: prepares a branch/PR review flow with an optional external reviewer.
- `skills/differential-review`: asks another agent to challenge an analysis, plan, or pending implementation.
- `skills/handoff-implementation-to-opencode`: keeps Codex as coordinator/reviewer, then hands implementation to OpenCode GLM-5.2.

## Platform notes

Most scripts are written in PowerShell and can run on Windows, macOS, or Linux when PowerShell 7+ (`pwsh`) is installed. `agent-handoff` also includes a Bash implementation for macOS/Linux.

## Repository scope

This repository is intentionally lightweight. It should not contain application code, build artifacts, local backups, private memories, credentials, or machine-specific configuration.
