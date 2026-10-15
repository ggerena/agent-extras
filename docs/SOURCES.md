# Sources and adaptations

Verified on 2026-10-15. These are references for understanding and maintaining the skills, not instructions to install or update them automatically. A reference commit identifies the file compared in this review, not necessarily the original installation commit. Local snapshot files are retained with their supporting resources.

## Third-party skills

| Folder | Source reference | License | Relationship |
|---|---|---|---|
| `cloudflare` | [Original reference](https://github.com/cloudflare/skills/blob/9177f9a0bafc1ab61a0dae8dca57a8eb4d9f636d/skills/cloudflare/SKILL.md) | Apache-2.0 | Local adaptation or older snapshot; exact installed revision not established. |
| `cloudflare-email-service` | [Original reference](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/cloudflare-email-service/SKILL.md) | Apache-2.0 | Local adaptation or older snapshot; exact installed revision not established. |
| `cloudflare-one` | [Original reference](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/cloudflare-one/SKILL.md) | Apache-2.0 | Local adaptation or older snapshot; exact installed revision not established. |
| `durable-objects` | [Original reference](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/durable-objects/SKILL.md) | Apache-2.0 | Local adaptation or older snapshot; exact installed revision not established. |
| `web-perf` | [Original reference](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/web-perf/SKILL.md) | Apache-2.0 | Local adaptation or older snapshot; exact installed revision not established. |
| `workers-best-practices` | [Original reference](https://github.com/cloudflare/skills/blob/426c3b406b3d3ef2ad3ca9bc2d3f41dd5be32ba0/skills/workers-best-practices/SKILL.md) | Apache-2.0 | Same normalized entrypoint; auxiliary files preserved from installation. |
| `wrangler` | [Original reference](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/wrangler/SKILL.md) | Apache-2.0 | Substantially rewritten local guidance; this is the related upstream reference, not proof of byte-for-byte derivation. |
| `security-audit` | [Original reference](https://github.com/cloudflare/security-audit-skill/blob/c1c8a8c1471069fb0e188eeaff69b8e8db6564a8/skills/security-audit/SKILL.md) | MIT | Same normalized entrypoint; auxiliary files preserved from installation. |
| `frontend-ui-engineering` | [Original reference](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/frontend-ui-engineering/SKILL.md) | MIT | Local adaptation or older snapshot; exact installed revision not established. |
| `owasp-security` | [Original reference](https://github.com/agamm/claude-code-owasp/blob/8ac7965caa212b4a850aff8d3df0081ab3fa9eed/.claude/skills/owasp-security/SKILL.md) | MIT | Same normalized entrypoint; auxiliary files preserved from installation. |
| `react-best-practices` | [Original reference](https://github.com/vercel-labs/agent-skills/blob/063bee94c3f4df8453406c830b0a7df0f2860278/skills/react-best-practices/SKILL.md) | MIT (frontmatter) | Same normalized entrypoint; auxiliary files preserved from installation. |
| `teach` | [Original reference](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/productivity/teach/SKILL.md) | MIT | Same normalized entrypoint; auxiliary files preserved from installation. |
| `typesafe-ai` | [Original reference](https://github.com/typesafe-ai/skills/blob/65a39f393687675ce170e6094757de20370365b9/skills/typesafe-ai/SKILL.md) | MIT | Same normalized entrypoint; auxiliary files preserved from installation. |

License files are included where supplied by the source. The React skill declares MIT in its frontmatter; the referenced upstream does not supply a separate root LICENSE. Its existing author and attribution metadata are preserved. The entrypoint comparison does not establish the revision of every supporting file. Cloudflare Apache-2.0 copies preserve the license; local changes include narrower routing and authorization guidance. No upstream NOTICE file was supplied at the checked repository root.

After comparing the entrypoints, the OWASP snapshot's `when_to_use` field was moved under standard `metadata` for schema compatibility, without changing its text or workflow. Teach's supported client-specific fields and explicit-invocation policy were retained.

## Ideas incorporated into maintained skills

The following ideas were compared with existing workflows and incorporated selectively. This does not mean the maintained skills were originally written by these projects, and the complete plugin was not installed.

| Idea | Original reference | Destination |
|---|---|---|
| Comparable measurements, real work, errors and variation | [pstack benchmark-checklist](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/benchmark-checklist/SKILL.md) | `diagnostico-con-evidencia` |
| Verify a critical assumption and indirect consumers | [pstack blast-radius](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/blast-radius/SKILL.md) | `cambio-minimo`, `code-review` |
| A regression test must fail for the intended reason | [pstack tdd](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/tdd/SKILL.md) | `diagnostico-con-evidencia`, `code-review`; subject to the user's test policy |
| A reusable guide for verifying the affected behavior | [create-verification-skill](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/create-verification-skill/SKILL.md), [maintain-verification-skill](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/maintain-verification-skill/SKILL.md) | `autodev`, without implicit server starts or writes in a read-only task |
| Explicitly authorized merge tied to a verified head | [pstack merge safety](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/poteto-mode/references/merge-safety.md), [GitHub CLI merge manual](https://cli.github.com/manual/gh_pr_merge) | Personal/project merge policy, outside this repository; `cerrar-pr` still never merges |

The public discussion that prompted the verification-guide comparison is [Daniel Lockyer's post](https://x.com/DanielLockyer/status/2110035356737232942). Its percentage is personal experience, not a benchmark of these skills.

Other maintained workflows and the neutral templates were consolidated from local instructions. No original external skill has been established for them; do not infer authorship from similar names or behavior. Historical notes mention Ponytail and a review of mattpocock/skills as influences on simplification, but do not identify an exact source file for those changes, so no stronger attribution is made.

## Managed skills

Client-provided and synchronized application skills are restored through their original application or plugin, not copied into this repository. Their internal tool dependencies, distribution rights and versioning belong to that provider. This includes browser/computer control, document tools, research, memory import, morning briefs, and system skill-management tools. Do not substitute a similarly named public skill and claim it is the same package.
