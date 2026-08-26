---
name: mira
description: "Use when the user says \"mira\" about a repository, asks to \"mirar este repo por encima\", or asks to read only the README and explain what the repository does at a high level. This skill is for a shallow repository overview only: clone if needed, read the README, and explain the project simply without code review, tests, servers, or file edits."
---

# Mira

## Scope

Do only a superficial repository overview based on the README.

Use this meaning for prompts such as:

- "mira este repo"
- "mira este repo por encima"
- "mira microsoft/presidio"
- "mira este repo y dime que hace"
- "mira este repo, clonalo si hace falta"

## Workflow

1. If the repository is not local and the user gave a URL or `owner/repo`, clone it under `C:\Users\gery_\Code`.
2. Read only the main README file from the repository root, preferring `README.md`, `README.MD`, then other README variants.
3. Explain in simple Spanish:
   - what the project is for;
   - what problem it solves;
   - its main components or features, only if the README mentions them;
   - how someone would use it at a very high level, only if the README mentions it.
4. Keep the answer short and non-technical unless the README itself requires technical terms.

## Boundaries

Do not inspect source code, tests, issues, pull requests, CI files, examples, docs outside the README, or package configuration.

Do not run builds, tests, linters, install commands, development servers, Docker, or dependency setup.

Do not edit files, create commits, push, create PRs, or make recommendations unless the user explicitly asks for that after the overview.

If the README is missing, say that no root README was found and give only the minimal repository facts available from the file listing.
