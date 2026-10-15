# agent-extras

Reusable agent skills, small helper scripts, and portable templates for Codex and Claude Code.

See [sources and adaptations](docs/SOURCES.md) for original skill references and licenses, and [portability and validation](docs/PORTABILITY.md) before installing.

## Maintained workflows

`agent-handoff`, `autodev`, `cambio-minimo`, `cerrar-pr`, `code-review`, `diagnostico-con-evidencia`, `handoff-implementation-to-codex`, `handoff-implementation-to-grok`, `km-analyze`, `mira`, `retrospectiva-agentes`, `revisa-grok`, and `se-pego-mi-pc`.

For these skills, `skills/` is the editable source. Synchronize authorized changes with the active installation; preserve supporting files and do not maintain accidental divergent copies. Presence in this repository does not mean every skill is installed.

## Portable exports requiring local configuration

`actualiza-todo`, `crear-release`, `crear-spec`, `daily`, `whatsapp-notify`, and `mandalo-por-buzz`.

These are neutral adaptations, not identical backups of private operating rules. Configure repositories, recipients, environments, paths and permissions locally. Do not overwrite a private installation with these templates without reconciling its requirements. Buzz requires a separately configured helper; no private transport script is included.

## Third-party snapshots

`cloudflare`, `cloudflare-email-service`, `cloudflare-one`, `durable-objects`, `frontend-ui-engineering`, `owasp-security`, `react-best-practices`, `security-audit`, `teach`, `typesafe-ai`, `web-perf`, `workers-best-practices`, and `wrangler`.

Supporting resources and existing attribution are retained. Original references, licenses and differences are listed in [SOURCES.md](docs/SOURCES.md). These are snapshots of installed skills, not automatic upgrades to upstream.

## Retired material

`differential-review` and `fin-sesion` remain for recovery and historical reference; do not install them as active workflows. Legacy source-command variants exist only in older history.

## Installation and scope

Read the selected skill first and install only what is needed. Shared installations can use `~/.agents/skills`; Claude Code can access the same folders through its supported skills directory/link. Preserve `agents/` metadata and supporting resources. Client-specific tools and dependencies must be available before use; matching file layouts alone do not prove runtime compatibility.

Most scripts require PowerShell; `agent-handoff` also includes Bash. `actualiza-todo` is Windows-specific. No script should be run merely to install a skill or inspect its instructions.

Keep private memories, user rules, customer procedures, contacts, credentials, application code, machine-specific configuration, generated outputs and local backups outside this repository. Authorization always comes from the current user and applicable project instructions.
