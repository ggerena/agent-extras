---
name: differential-review
description: >-
  Use when an agent (including Claude Code, Codex, or GLM-5.2 running inside opencode) wants a second
  opinion from Codex, Claude Code, or OpenCode on a plan, analysis, hypothesis, or pending
  implementation, before editing files, or on an existing pull request without pasting the full diff,
  or when the user asks to "validar con Codex", "validar con GLM", "consultar Codex", or
  "consultar OpenCode". Choose exactly one reviewer per run:
  Codex via `codex exec -m gpt-5.5 -c model_reasoning_effort="xhigh" --sandbox read-only` by default, or Claude Code via
  `claude -p --model claude-opus-4-8 --effort max --permission-mode
  plan`, or OpenCode via `opencode run -m opencode-go/glm-5.2 --variant max`
  when explicitly requested. Useful for challenging a recommendation, contrasting hypotheses,
  finding weak assumptions, and detecting scenarios where the current conclusion
  fails. Do not use for small obvious edits or when no real analysis exists to
  challenge.
---

# Differential Review

Call one external reviewer when you already have a written analysis, plan, or hypothesis and want a differential pass that challenges it before acting. Use Codex by default, Claude Code when the user explicitly asks for Claude/Opus, or OpenCode when the user explicitly asks for OpenCode/GLM.

## When to use

- You drafted a Markdown analysis or plan and want a second opinion that tries to refute it.
- You are about to implement a non-trivial change and want Codex to flag weak assumptions, missing files to inspect, edge cases, or simpler alternatives.
- You want case-by-case criteria because the current recommendation overgeneralizes.
- You have an existing PR and want another agent to review the PR by reference, with read-only repo access, instead of pasting the full diff into the prompt.
- The repo explicitly benefits from cross-model review.

## When NOT to use

- Small, obvious edits with no analysis to challenge.
- Pure questions of fact answerable from the repo without an opinion to refute.
- Tasks where Codex has already reviewed and no new evidence appeared.

## How it works

1. You have either:
   - a Markdown analysis file in the repo's docs folder, or
   - a short prompt describing the hypothesis to challenge, or
   - an existing PR number, URL, branch, or `auto` for the current branch.
2. The bundled script invokes exactly one reviewer:
   - `-Reviewer codex` (default): Codex binary resolved from `DIFF_REVIEW_CODEX_PATH`, `CODEX_CLI_PATH`, or common Codex Desktop install paths before PATH, so Claude Code does not accidentally use an older PATH shim. Defaults to `gpt-5.5` with `model_reasoning_effort="xhigh"`, the highest documented Codex reasoning effort. Runs with `--ephemeral` and `--sandbox read-only`, so Codex cannot edit files.
   - `-Reviewer claude`: Claude Code with `--model claude-opus-4-8`, `--effort max`, `--permission-mode plan`, `--no-session-persistence`, empty strict MCP config, temp working directory, and `--add-dir` pointing at the invocation repo. Only `Read`, `LS`, `Glob`, and `Grep` tools are enabled. It does not use `--bare` by default because Claude Code bare mode cannot use the normal claude.ai/keychain login.
   - `-Reviewer opencode`: OpenCode resolved from `DIFF_REVIEW_OPENCODE_PATH`, PATH, or common install paths. Defaults to `opencode-go/glm-5.2` with `--variant max` for the model's highest reasoning level. It runs with `--dir` pointing at the invocation repo and a per-run `differential-review-readonly` agent injected through `OPENCODE_CONFIG_CONTENT`; that agent allows read, list, glob, and grep, and denies edit, bash, tasks, web access, and external directories. If the user asks for `glm-5.2`, route it to `opencode-go/glm-5.2`.
3. The script blocks self-review by default when `-Invoker` or environment detection says the calling agent matches `-Reviewer`. Pass `-Invoker codex|claude|opencode` whenever the current agent is known; environment detection is only a best-effort backup. Use `-AllowSelfReview` only when the user explicitly wants the same agent to review itself.
4. Codex writes its response to a temp file via `--output-last-message`; Claude and OpenCode write to stdout. The script redirects stdout/stderr noise and reads the final response.
5. When `-PullRequest` is passed, the script builds a PR review prompt with the PR reference, small PR metadata when `gh pr view` is available, and the current repo path. It does not paste the PR diff. If `-AnalysisFile` is also passed, the script includes only that file path and asks the reviewer to read it through read-only tools instead of embedding the whole file.
6. The default prompt asks Codex to return:
   - weak assumptions,
   - scenarios that break the conclusion,
   - missing evidence it should have checked,
   - a revised recommendation if the original overgeneralized,
   - stop conditions that warrant revising before implementing.
7. When an analysis file is provided, the response is appended to that file under `## Comentarios IA externa (analisis diferencial)` with timestamp and reviewer metadata.
8. For Codex, the MCP server `figma` is disabled per-invocation to avoid auth noise; pass `-ExtraArgs` only for harmless read-only flags.
9. For Claude, dangerous context/permission overrides are rejected in `-ExtraArgs`; do not pass settings, resume/continue flags, tool overrides, or permission overrides. Claude can inspect the repo only through read-only tools.
10. For OpenCode, the prompt is attached as a temp file and the repo is provided through `--dir` with a per-run read-only agent. The reasoning level is controlled with `-OpenCodeVariant high|max` and defaults to `max`. Do not pass session, attach, directory, command, file, share, interactive, thinking-output, agent, output format, variant, model, or permission-skipping flags in `-ExtraArgs`.

## Run it

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -AnalysisFile <analysis.md>
```

Use Claude Code / Opus 4.8 max instead:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Invoker codex -Reviewer claude -AnalysisFile <analysis.md>
```

Use OpenCode with GLM-5.2 max instead:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Invoker codex -Reviewer opencode -OpenCodeModel opencode-go/glm-5.2 -OpenCodeVariant max -AnalysisFile <analysis.md>
```

Or with a direct prompt:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Prompt "Tu hipotesis o plan a desafiar."
```

Review the current branch PR without pasting its diff:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Invoker claude -Reviewer codex -PullRequest auto -Prompt "Valida mi conclusion: no veo bloqueantes."
```

Review a specific PR by number or URL:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Invoker claude -Reviewer codex -PullRequest 123
```

From Claude Code, when the user asks to validate with Codex, run the installed script directly instead of invoking `codex` yourself or using a Codex subagent/plugin:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\differential-review\scripts\differential-review.ps1" -Invoker claude -Reviewer codex -AnalysisFile <analysis.md>
```

If there is already a PR, prefer `-PullRequest auto` or `-PullRequest <number-or-url>` plus a short conclusion. Do not paste `git diff`, `gh pr diff`, or the full file patch into `-Prompt`.

Defaults:

- `<skill-root>` is the installed `differential-review` skill folder. Prefer the skill folder currently loaded by the agent; common locations are `$env:CODEX_HOME\skills\differential-review`, `~\.codex\skills\differential-review`, `~\.claude\skills\differential-review`, or another checked-out copy.
- `DIFF_REVIEW_PROFILE`: optional Codex profile. If unset, Codex uses its default profile. Sandbox is still forced to `read-only`.
- `DIFF_REVIEW_CODEX_PATH`: optional explicit path to the real Codex binary. If unset, the script tries `CODEX_CLI_PATH`, Codex Desktop install paths, PATH, and common install paths. Avoid PATH-only shims that point to old npm installs or WindowsApps aliases.
- `DIFF_REVIEW_CODEX_MODEL`: `gpt-5.5`.
- `DIFF_REVIEW_CODEX_REASONING_EFFORT`: `xhigh`. Supported values are `minimal`, `low`, `medium`, `high`, and `xhigh`.
- `DIFF_REVIEW_REVIEWER`: `codex`. Set to `claude` to use Claude Code by default.
- `DIFF_REVIEW_PULL_REQUEST`: optional PR selector. Use `auto` to let `gh pr view` resolve the PR for the current branch, or pass a PR number, URL, or branch.
- `DIFF_REVIEW_INVOKER`: optional current agent label: `codex`, `claude`, or `opencode`. If unset, the script detects common Codex, Claude Code, and OpenCode environment variables when available. This backup is not guaranteed in every shell; prefer `-Invoker` for normal use.
- `DIFF_REVIEW_CLAUDE_PATH`: optional explicit path to Claude Code. If unset, the script tries PATH, `~\.local\bin\claude.exe`, and common npm shim paths.
- `DIFF_REVIEW_CLAUDE_MODEL`: `claude-opus-4-8`.
- `DIFF_REVIEW_CLAUDE_EFFORT`: `max`. Local Claude Code help currently accepts `low`, `medium`, `high`, and `max`; use `max` as the highest practical level for this skill.
- `DIFF_REVIEW_CLAUDE_SETTINGS`: optional Claude Code settings file path or JSON string. Mainly useful with `-ClaudeBare` when providing an `apiKeyHelper`.
- `DIFF_REVIEW_OPENCODE_PATH`: optional explicit path to OpenCode. If unset, the script tries PATH, `~\.bun\bin\opencode.exe`, and common npm shim paths.
- `DIFF_REVIEW_OPENCODE_MODEL`: `opencode-go/glm-5.2`. The script normalizes `glm-5.2` to `opencode-go/glm-5.2`.
- `DIFF_REVIEW_OPENCODE_VARIANT`: `max`. Use `high` when you want a cheaper/faster OpenCode review, or an empty value to let OpenCode use its provider default.
- Sandbox is forced to `read-only` regardless of what the profile says. No `--full-auto`, no workspace writes. Codex can read the repo but not change it.
- Claude and OpenCode also receive repo read access by default. Claude is limited to `Read`, `LS`, `Glob`, and `Grep`; OpenCode uses the per-run `differential-review-readonly` agent with read/list/glob/grep allowed and write/shell/web/task/external-directory permissions denied.
- PR mode gives the reviewer the PR reference and the repo path. It may inspect PR metadata or diff through read-only tools, but the wrapper does not paste the diff into the prompt.
- The temp output file is deleted after use unless `-KeepOutputFile` is passed.

Overrides:

- `-Reviewer codex|claude|opencode` to choose one reviewer for this run.
- `-PullRequest` / `-PR` to review an existing PR by `auto`, number, URL, or branch without embedding the full diff.
- `-Invoker codex|claude|opencode` to declare the current calling agent and enable self-review protection even when environment detection is unavailable.
- `-AllowSelfReview` to intentionally allow the reviewer to match the invoker. Avoid this for normal differential review.
- `-Profile` / `$env:DIFF_REVIEW_PROFILE` to use a different Codex profile.
- `-CodexPath` / `$env:DIFF_REVIEW_CODEX_PATH` if Codex moves to a different binary path.
- `-CodexModel` and `-CodexReasoningEffort` to change the Codex invocation.
- `-ClaudePath`, `-ClaudeModel`, and `-ClaudeEffort` to change the Claude Code invocation.
- `-ClaudeBare` to opt into Claude Code bare mode. Bare mode requires `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, or `-ClaudeSettings`/`DIFF_REVIEW_CLAUDE_SETTINGS`; the normal claude.ai login is not available to `--bare`.
- `-ClaudeSettings` / `$env:DIFF_REVIEW_CLAUDE_SETTINGS` to pass dedicated Claude Code settings without using `-ExtraArgs`.
- `-OpenCodePath`, `-OpenCodeModel`, and `-OpenCodeVariant high|max` to change the OpenCode invocation.
- `-PrintPromptOnly` to render the prompt and exit without invoking a reviewer. Use it for debugging or tests.
- `-KeepOutputFile` to preserve the raw codex output in `%TEMP%`.
- `-ExtraArgs` to pass additional harmless flags to the selected tool (use sparingly). The script rejects permission-changing flags for Codex and context/permission/tool overrides for Claude.

## Operational notes

- The script runs the selected reviewer in a background job and prints a progress line every 60 seconds (`codex sigue corriendo...`, `claude sigue corriendo...`, or `opencode sigue corriendo...`) so the user knows it is not hung. The agent using the skill should still tell the user at the start: "te doy feedback cada 1 minuto".
- Keep ownership of the final decision. The external review is input, not authorization to implement.
- Do not include secrets in the analysis file or prompt. The script does not strip them.
- If the selected binary is missing or inaccessible, the script fails with a clear error and prints the resolved binary when available. It does not install Codex, Claude Code, or OpenCode.
- If the selected reviewer returns non-zero, the script surfaces stderr and exits with the same code. The analysis file is not modified on failure.
