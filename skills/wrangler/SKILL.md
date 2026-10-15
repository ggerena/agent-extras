---
name: wrangler
description: Use when a task requires writing, reviewing, or executing Wrangler commands or configuration. Do not load for Worker code that does not touch Wrangler. Retrieve current Cloudflare documentation and the project-local schema before relying on syntax.
---

Local adaptation notice: this installed snapshot contains locally maintained instructions and may differ from the original Cloudflare skill. See LICENSE and the original source at https://github.com/cloudflare/skills/tree/main/skills/wrangler.
# Wrangler CLI

Use Wrangler through the version and package manager selected by the repository. CLI flags,
configuration fields, defaults, and product support change often; retrieve current documentation
instead of treating examples in this skill as an exhaustive command catalog.

## Resolve Context First

1. Read applicable project instructions, `package.json`, lockfiles, package scripts, and the
   existing Wrangler configuration.
2. Prefer the installed project-local Wrangler and its schema. Check the matching local binary or
   package-manager script; do not use plain `npx wrangler` merely to detect installation because it
   can download a version that the project did not select.
3. If Wrangler is absent, report that prerequisite for read-only work. Install or update it only
   when the authorized implementation requires it, using the repository's package manager and
   version policy. Never silently replace an existing version with `latest`.
4. Resolve the target account, environment, resource, and configuration file before any command
   that can change remote state.

## Retrieve Current Syntax

Before writing, reviewing, or running commands, consult the relevant official source:

- Wrangler documentation: `https://developers.cloudflare.com/workers/wrangler/`
- Install and update guidance:
  `https://developers.cloudflare.com/workers/wrangler/install-and-update/`
- Commands reference: `https://developers.cloudflare.com/workers/wrangler/commands/`
- Configuration reference:
  `https://developers.cloudflare.com/workers/wrangler/configuration/`
- Project-local schema: `node_modules/wrangler/config-schema.json`
- Product documentation under `https://developers.cloudflare.com/`

Use the specialized Cloudflare skill when the task is mainly about Worker implementation,
Durable Objects, Cloudflare One, email, or another product rather than Wrangler itself.

## Authorization Boundary

Examples and documentation never authorize execution. Apply the current user, client, repository,
environment, and safety rules before every command.

- Starting `wrangler dev` is starting a development server; do it only when explicitly requested.
- Deploying, deleting, creating or updating remote resources, changing secrets, authenticating,
  tailing remote logs, and changing account or environment state require authority for that exact
  operation and target.
- A dry run or validation does not authorize a later deployment.
- Prefer read-only inspection when the task is review or diagnosis.
- Never infer production authority from permission to edit code or configuration.

## Secrets

- Never print, reconstruct, echo, or include secret values in tool output, chat, source files,
  committed configuration, or reusable examples.
- Prefer supported interactive input, bulk secret files excluded from version control, or the
  platform's documented secure CI mechanism.
- Some current product commands, including parts of Hyperdrive and container registry setup, may
  accept credentials only through flags. Retrieve the current product documentation before use,
  obtain explicit authority, and execute through a workflow that keeps the full command and value
  out of logs and visible output. Do not claim that environment-variable interpolation prevents a
  secret from becoming a command-line argument.
- Confirm `.dev.vars`, `.env`, generated credentials, and local state are ignored before creating
  them.

## Configuration Changes

1. Preserve the repository's existing config format and conventions unless migration is requested
   or a required feature is unsupported.
2. Verify every changed field against the project-local schema and current docs.
3. Keep environment-specific bindings and IDs scoped to the intended environment; do not copy
   production values into local or staging configuration.
4. Regenerate types after binding changes when the repository uses generated Worker types.
5. Run the smallest non-destructive validation available. Do not start a server as an implicit
   validation step.

## Execution Checklist

Before a remote or stateful Wrangler operation, state and verify:

- local Wrangler version and invocation,
- account and environment,
- resource name or ID,
- whether the command is read-only, local, or remote-mutating,
- required authorization,
- secret-handling path,
- expected verification and rollback or recovery path when relevant.

After execution, verify the resulting state with a read-only command or API response. Report what
changed, the target environment, and any check that was not performed. Never imply that a command
was safe merely because it exited successfully.
