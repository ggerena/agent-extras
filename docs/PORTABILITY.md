# Portability and validation

## What is backed up

The repository contains maintained workflows, thirteen third-party snapshots with auxiliary files, and six neutral exports of workflows that require local configuration. A neutral export deliberately does not preserve private recipient maps, customer rules, environments or absolute machine paths. Application-managed and system skills are referenced, not redistributed.

For each copied third-party skill, the installed content was compared with the published source reference. A matching SKILL.md does not prove the revision of every auxiliary file. Preserve upstream attribution, licenses and any local adaptation notices when copying.

## Compatibility

- Shared Markdown instructions can be used by Codex and Claude Code, subject to the actual tools available. They are instructions, not enforcement.
- `teach` preserves Claude's `disable-model-invocation` and `argument-hint` fields; its `agents/openai.yaml` also disables implicit invocation for Codex. Do not remove these fields just to satisfy a validator with a narrower schema.
- The OWASP snapshot moves its extra `when_to_use` key into standard `metadata`; its trigger text and workflow are preserved in the active shared installation.
- `mandalo-por-buzz` is an explicit-only template and requires a locally configured helper. There is no transport implementation in this export.
- Product documentation and examples can become outdated. The relevant skills require checking current primary documentation before operational use.
- The React snapshot includes an upstream contributor README referencing build tooling that is not distributed in the installed skill. Those build instructions are not an installation procedure for this snapshot.
- `actualiza-todo -CheckOnly` is not an offline or side-effect-free simulation. Validate its scope and prerequisites before running it. No updater, server, messaging or deployment command is executed as part of this repository review.

## Validation scope

Entry metadata and referenced resources are checked structurally; PowerShell scripts are parsed and Python/JavaScript files are syntax-checked without running their operational actions. Existing deterministic tests may be run separately where safe. This does not prove every workflow, account, integration or platform combination works: those operational paths remain **NOT TESTED** unless a specific execution result is recorded.

Secret scanning is combined with manual classification. The third-party Cloudflare examples contain six scanner matches for explicit placeholders such as `YOUR_API_TOKEN` and deliberately fake API keys in anti-pattern examples; these are not credentials from an installation. Do not suppress new findings merely because the examples were classified.

Privacy verification concerns tracked source and the published main history. Repository hosting identity and public upstream authorship are not anonymized by cleaning source. Previous GitHub caches, clones, forks and pull-request references can retain older content; rewriting main is not a guarantee of erasure from those copies.
