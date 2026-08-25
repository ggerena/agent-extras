---
name: differential-review
description: >-
  Use only when the user explicitly requests a second opinion from Codex, Claude Code, OpenCode,
  Grok, or Cursor for a plan, analysis, hypothesis, pending implementation, or existing PR; for
  example, when the user says "valida con Codex", "validar con Codex", "valida con GPT", "validar con GPT",
  "validar con GLM", "validar con Cursor", "consultar Codex", "consultar OpenCode",
  "consultar Grok", or "revisa con x.ai". Runs exactly one reviewer per invocation, always in a
  read-only sandbox, and blocks self-review. Use to challenge assumptions and detect scenarios
  where a conclusion fails. Do not use for small obvious edits, and do not use to hand over the
  work itself: that is `agent-handoff` (switch owner) or `handoff-implementation-to-grok`
  (delegate implementation). For reviewing your own branch or PR without a second agent, use
  `code-review`.
---

> **Nombres de modelo:** los IDs concretos viven en `scripts/differential-review.ps1` y en la
> sección Defaults de este archivo, nunca en la descripción de arriba. Envejecen rápido. Si un
> reviewer falla porque el modelo ya no existe, verificar el catálogo vigente antes de tocar nada
> más: `grok models`, `cursor-agent models`, `claude --help`, o la documentación del proveedor.
> Actualizar el default en el script y en Defaults, en un solo lugar cada uno.

# Differential Review

Call an external reviewer only when the user explicitly asks for one. Never add a differential review to a plan, implementation, PR, or close-out on your own initiative. Use Codex when the user asks for Codex or GPT; use Claude Code when the user explicitly asks for Claude/Fable or Claude/Opus, OpenCode when the user explicitly asks for OpenCode/GLM, Grok when the user explicitly asks for Grok/x.ai, or Cursor only when the user explicitly asks for Cursor.

## When to use

- The user explicitly asks to validate, consult, or review something with one of the supported agents.
- The user explicitly asks for an external review of a plan, implementation, or existing PR.

## When NOT to use

- Small, obvious edits with no analysis to challenge.
- Pure questions of fact answerable from the repo without an opinion to refute.
- Tasks where Codex has already reviewed and no new evidence appeared.
- Any task where the user did not explicitly request an external review, even if the plan or change is non-trivial.

## How it works

1. You have either:
   - a Markdown analysis file in the repo's docs folder, or
   - a short prompt describing the hypothesis to challenge, or
   - an existing PR number, URL, branch, or `auto` for the current branch.
2. The bundled script invokes exactly one reviewer:
   - `-Reviewer codex` (default): Codex binary resolved from `DIFF_REVIEW_CODEX_PATH`, `CODEX_CLI_PATH`, or common Codex Desktop install paths before PATH, so Claude Code does not accidentally use an older PATH shim. Defaults to `gpt-5.6-sol` with `model_reasoning_effort="xhigh"` (extra high). Runs with `--ephemeral` and `--sandbox read-only`, so Codex cannot edit files.
   - `-Reviewer claude`: Claude Code with `-ClaudePreset opus` (`--model claude-opus-5`, `--effort max`) by default, or explicit `-ClaudePreset fable` (`--model claude-fable-5`, `--effort high`), `--permission-mode plan`, `--no-session-persistence`, empty strict MCP config, temp working directory, and `--add-dir` pointing at the invocation repo. Only `Read`, `LS`, `Glob`, and `Grep` tools are enabled. It does not use `--bare` by default because Claude Code bare mode cannot use the normal claude.ai/keychain login.
   - `-Reviewer opencode`: OpenCode resolved from `DIFF_REVIEW_OPENCODE_PATH`, PATH, or common install paths. Defaults to `opencode-go/glm-5.2` with `--variant max` for the model's highest reasoning level. It runs with `--dir` pointing at the invocation repo and a per-run `differential-review-readonly` agent injected through `OPENCODE_CONFIG_CONTENT`; that agent allows read, list, glob, and grep, and denies edit, bash, tasks, web access, and external directories. If the user asks for `glm`, `glm-5-2`, or `glm-5.2`, route it to OpenCode Go as `opencode-go/glm-5.2`.
   - `-Reviewer grok`: Grok Build CLI resolved from `DIFF_REVIEW_GROK_PATH`, `~/.grok/bin/grok`, or PATH. Defaults to `grok-4.5` and runs with `--permission-mode plan`, `--sandbox read-only`, `--no-subagents`, `--no-memory`, and `--disable-web-search`. It can inspect the repository but cannot edit it or use web tools.
   - `-Reviewer cursor`: Cursor CLI (`cursor-agent`) resolved from `DIFF_REVIEW_CURSOR_PATH`, PATH, or common install paths (`~/.local/bin` on macOS/Linux, `%LOCALAPPDATA%\cursor-agent` on Windows). Defaults to `gpt-5.5` and runs `cursor-agent -p --mode ask --output-format json`, which is read-only by design. The prompt is passed as a positional argument (the CLI does not read stdin), and the JSON `result` field is read back. It requires `CURSOR_API_KEY` and fails fast if missing, to avoid hanging on an interactive login. Note: the Cursor CLI exposes no reasoning-effort control, so GPT-5.5 runs at a fixed "medium"; this reviewer is not equivalent to Codex at `xhigh`.
3. The script blocks self-review by default when `-Invoker` or environment detection says the calling agent matches `-Reviewer`. Pass `-Invoker codex|claude|opencode|grok|cursor` whenever the current agent is known; environment detection is only a best-effort backup. When Codex is the invoker and the user explicitly says "valida con Codex" or "valida con GPT", pass `-Invoker codex -Reviewer codex -AllowSelfReview`. Do not use `-AllowSelfReview` unless the user explicitly requests that same-agent review.
4. Codex writes its response to a temp file via `--output-last-message`; Claude, OpenCode, and Grok Build write to stdout. The script redirects stdout/stderr noise and reads the final response.
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
10. For OpenCode, the prompt is attached as a temp file and the repo is provided through `--dir` with a per-run read-only agent. The reasoning level is controlled with `-OpenCodeVariant high|max` and defaults to `max` for GLM. For Grok Build, the script supplies the prompt file directly and rejects flags that could alter its read-only plan-mode execution.

## Run it

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -AnalysisFile <analysis.md>
```

From Codex, when the user explicitly asks "valida con Codex" or "valida con GPT", allow the requested Codex self-review:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Invoker codex -Reviewer codex -AllowSelfReview -AnalysisFile <analysis.md>
```

Use Claude Code / Fable 5 high explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Invoker codex -Reviewer claude -ClaudePreset fable -AnalysisFile <analysis.md>
```

Use Claude Code / Opus 4.8 max instead:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Invoker codex -Reviewer claude -ClaudePreset opus -AnalysisFile <analysis.md>
```

Use OpenCode with GLM-5.2 through OpenCode Go max instead:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Invoker codex -Reviewer opencode -OpenCodeModel opencode-go/glm-5.2 -OpenCodeVariant max -AnalysisFile <analysis.md>
```

Use Grok Build CLI with Grok 4.5 instead:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Invoker codex -Reviewer grok -GrokModel grok-4.5 -AnalysisFile <analysis.md>
```

Use Cursor with GPT-5.5 (read-only, fixed medium reasoning) instead:

```powershell
$env:CURSOR_API_KEY = "..."  # required; the CLI can hang on interactive login otherwise
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\differential-review.ps1 -Invoker claude -Reviewer cursor -AnalysisFile <analysis.md>
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

From Claude Code, when the user asks to validate with Codex or GPT, run the installed script directly instead of invoking `codex` yourself or using a Codex subagent/plugin:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\differential-review\scripts\differential-review.ps1" -Invoker claude -Reviewer codex -AnalysisFile <analysis.md>
```

If there is already a PR, prefer `-PullRequest auto` or `-PullRequest <number-or-url>` plus a short conclusion. Do not paste `git diff`, `gh pr diff`, or the full file patch into `-Prompt`.

Defaults:

- `<skill-root>` is the installed `differential-review` skill folder. Prefer the skill folder currently loaded by the agent; common locations are `$env:CODEX_HOME\skills\differential-review`, `~\.codex\skills\differential-review`, `~\.claude\skills\differential-review`, or another checked-out copy.
- `DIFF_REVIEW_PROFILE`: optional Codex profile. If unset, Codex uses its default profile. Sandbox is still forced to `read-only`.
- `DIFF_REVIEW_CODEX_PATH`: optional explicit path to the real Codex binary. If unset, the script tries `CODEX_CLI_PATH`, Codex Desktop install paths, PATH, and common install paths. Avoid PATH-only shims that point to old npm installs or WindowsApps aliases.
- `DIFF_REVIEW_CODEX_MODEL`: `gpt-5.6-sol`.
- `DIFF_REVIEW_CODEX_REASONING_EFFORT`: `xhigh`. Supported values are `minimal`, `low`, `medium`, `high`, and `xhigh`.
- `DIFF_REVIEW_REVIEWER`: `codex`. Set to `claude` to use Claude Code by default.
- `DIFF_REVIEW_PULL_REQUEST`: optional PR selector. Use `auto` to let `gh pr view` resolve the PR for the current branch, or pass a PR number, URL, or branch.
- `DIFF_REVIEW_INVOKER`: optional current agent label: `codex`, `claude`, `opencode`, `grok`, or `cursor`. If unset, the script detects common Codex, Claude Code, and OpenCode environment variables when available. This backup is not guaranteed in every shell; prefer `-Invoker` for normal use.
- `DIFF_REVIEW_CLAUDE_PATH`: optional explicit path to Claude Code. If unset, the script tries PATH, `~\.local\bin\claude.exe`, and common npm shim paths.
- `DIFF_REVIEW_CLAUDE_PRESET`: `opus` by default. Use `fable` only when the user explicitly asks for Claude Fable.
- `DIFF_REVIEW_CLAUDE_MODEL`: derived from the preset (`claude-fable-5` for `fable`, `claude-opus-5` for `opus`) unless explicitly overridden.
- `DIFF_REVIEW_CLAUDE_EFFORT`: derived from the preset (`high` for `fable`, `max` for `opus`) unless explicitly overridden. Local Claude Code help currently accepts `low`, `medium`, `high`, and `max`.
- `DIFF_REVIEW_CLAUDE_SETTINGS`: optional Claude Code settings file path or JSON string. Mainly useful with `-ClaudeBare` when providing an `apiKeyHelper`.
- `DIFF_REVIEW_GROK_PATH`: optional explicit path to Grok Build CLI. If unset, the script tries `~/.grok/bin/grok` and PATH.
- `DIFF_REVIEW_GROK_MODEL`: `grok-4.5`. Verify the models available to the current Grok Build login with `grok models`.
- `DIFF_REVIEW_OPENCODE_PATH`: optional explicit path to OpenCode. If unset, the script tries PATH, `~\.bun\bin\opencode.exe`, and common npm shim paths.
- `DIFF_REVIEW_OPENCODE_MODEL`: `opencode-go/glm-5.2`. The script normalizes `glm`, `glm-5-2`, and `glm-5.2` to `opencode-go/glm-5.2`.
- `DIFF_REVIEW_OPENCODE_VARIANT`: `max`. Use `high` when you want a cheaper/faster OpenCode review, or an empty value to let OpenCode use its provider default.
- `DIFF_REVIEW_CURSOR_PATH`: optional explicit path to `cursor-agent`. If unset, the script tries PATH, `~/.local/bin/cursor-agent`, `~/.local/bin/agent`, and `%LOCALAPPDATA%\cursor-agent\cursor-agent.exe`.
- `DIFF_REVIEW_CURSOR_MODEL`: `gpt-5.5`. Verify availability for your account with `cursor-agent models`.
- `DIFF_REVIEW_CURSOR_MODE`: `ask` (read-only Q&A); `plan` is also read-only. Both avoid edits and shell. Cursor requires `CURSOR_API_KEY`; the script refuses to run without it to avoid a headless hang. The Cursor CLI has no reasoning-effort control (fixed medium), so it is not equivalent to Codex `xhigh`.
- Sandbox is forced to `read-only` regardless of what the profile says. No `--full-auto`, no workspace writes. Codex can read the repo but not change it.
- Claude, OpenCode, and Grok Build also receive read-only repo access by default. Claude is limited to `Read`, `LS`, `Glob`, and `Grep`; OpenCode uses the per-run `differential-review-readonly` agent with read/list/glob/grep allowed and write/shell/web/task/external-directory permissions denied; Grok Build is forced to plan mode with a read-only sandbox, no subagents, memory, or web search.
- PR mode gives the reviewer the PR reference and the repo path. It may inspect PR metadata or diff through read-only tools, but the wrapper does not paste the diff into the prompt.
- The temp output file is deleted after use unless `-KeepOutputFile` is passed.
- Each reviewer has a maximum runtime of 1800 seconds by default. Set `DIFF_REVIEW_MAX_RUNTIME_SECONDS=0` or pass `-MaxRuntimeSeconds 0` to disable the timeout.

Overrides:

- `-Reviewer codex|claude|opencode|grok|cursor` to choose one reviewer for this run.
- `-PullRequest` / `-PR` to review an existing PR by `auto`, number, URL, or branch without embedding the full diff.
- `-Invoker codex|claude|opencode|grok|cursor` to declare the current calling agent and enable self-review protection even when environment detection is unavailable.
- `-AllowSelfReview` to intentionally allow the reviewer to match the invoker. Avoid this for normal differential review.
- `-Profile` / `$env:DIFF_REVIEW_PROFILE` to use a different Codex profile.
- `-CodexPath` / `$env:DIFF_REVIEW_CODEX_PATH` if Codex moves to a different binary path.
- `-CodexModel` and `-CodexReasoningEffort` to change the Codex invocation.
- `-ClaudePreset fable|opus` to choose the Claude model by request. When the user says "revisa con Claude Fable", use `fable`; when the user says "revisa con Claude Opus", use `opus`.
- `-ClaudePath`, `-ClaudeModel`, and `-ClaudeEffort` to change the Claude Code invocation manually.
- `-ClaudeBare` to opt into Claude Code bare mode. Bare mode requires `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, or `-ClaudeSettings`/`DIFF_REVIEW_CLAUDE_SETTINGS`; the normal claude.ai login is not available to `--bare`.
- `-ClaudeSettings` / `$env:DIFF_REVIEW_CLAUDE_SETTINGS` to pass dedicated Claude Code settings without using `-ExtraArgs`.
- `-OpenCodePath`, `-OpenCodeModel`, and `-OpenCodeVariant high|max` to change the OpenCode invocation.
- `-GrokPath` and `-GrokModel` to change the Grok Build invocation. Prefer `grok-4.5` unless `grok models` shows a newer text/reasoning model.
- `-CursorPath`, `-CursorModel`, and `-CursorMode ask|plan` to change the Cursor invocation. Cursor needs `CURSOR_API_KEY`.
- `-PrintPromptOnly` to render the prompt and exit without invoking a reviewer. Use it for debugging or tests.
- `-KeepOutputFile` to preserve the raw codex output in `%TEMP%`.
- `-MaxRuntimeSeconds` / `$env:DIFF_REVIEW_MAX_RUNTIME_SECONDS` to limit a stuck reviewer. Defaults to 1800 seconds; `0` disables the limit.
- `-ExtraArgs` to pass additional harmless flags to the selected tool (use sparingly). The script rejects permission-changing flags for Codex and context/permission/tool overrides for Claude.

## Operational notes

- The script runs the selected reviewer in a background job and prints a progress line every 60 seconds (`codex sigue corriendo...`, `claude sigue corriendo...`, `opencode sigue corriendo...`, or `grok sigue corriendo...`) so the user knows it is not hung. The agent using the skill should still tell the user at the start: "te doy feedback cada 1 minuto".
- Keep ownership of the final decision. The external review is input, not authorization to implement.
- Do not include secrets in the analysis file or prompt. The script does not strip them.
- If the selected binary is missing or inaccessible, the script fails with a clear error and prints the resolved binary when available. It does not install Codex, Claude Code, OpenCode, or Grok Build.
- If the selected reviewer returns non-zero, the script surfaces stderr and exits with the same code. The analysis file is not modified on failure.
