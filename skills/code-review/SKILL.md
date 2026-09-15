---
name: code-review
description: Use when the user asks for code review, /revisa, /code-review, revisar un PR, revisar una rama, revisar cambios contra una base, or wants a senior adversarial review of a pull request or branch diff without editing files. Prioritize real bugs, regressions, project-instruction violations, and high-confidence findings; comment on the PR only with explicit authorization.
---

# Code Review

Act as a senior code reviewer. Review a Pull Request or branch against its resolved base.
This is a read-only skill: do not edit files, create reports in the repo, commit, push, or merge.
Do not fix findings here. Return them to the user or to the enclosing workflow, such as `cerrar-pr`,
which owns any authorized corrections and verification.

**Qué flujo de revisión corresponde:** esta skill revisa directamente una rama o PR. Si el usuario
pide la opinión de OTRO agente, usa un subagente disponible en el entorno actual y respeta el
revisor indicado y las reglas del cliente. Debe ser una sesión o agente distinto del implementador;
si no está disponible, informa la limitación sin sustituirlo por una autorrevisión. Un envío fuera
del entorno actual requiere autorización explícita. Si hay que traspasar la implementación,
usa el flujo de handoff correspondiente. Para un release de Goflow próximo a Prod, usa
`crear-release` en modo revisión.

## Workflow

1. Identify whether the target is a PR or the current branch.
2. If it is a PR, check that it is open and identify its current head SHA and actual base. For a
   branch, use the base named by the user; otherwise resolve and verify the repository's default
   trunk. Never use the tracking upstream of the current feature branch as its base, and never
   assume `develop`. Draft PRs are
   valid review targets: early backups are intentionally draft. A prior review does not exclude
   a new iteration; review the current complete diff and recheck previous findings against the
   new head. Do not reuse a verdict for a different SHA or unreviewed local changes.
3. Read relevant project instructions such as `AGENTS.md`, `CLAUDE.md`, `.opencode`, or equivalent files for the modified paths.
4. Read the full committed diff with `gh pr diff <n>` for a PR, or `git diff <base>...HEAD` for a
   branch. Also inspect staged changes with `git diff --cached`, unstaged changes with `git diff`,
   and the contents of relevant files returned by `git ls-files --others --exclude-standard`.
   Record the reviewed base, head or merge-base, and whether local changes were included.
5. Perform an **adversarial review**: do not only check whether the happy path looks reasonable. Try to falsify the change's guarantees with concrete abuse cases, malformed inputs, boundary conditions, concurrent operations, partial failures, stale state, permission crossings, and invariant violations that are relevant to the diff. Treat descriptions, tests, comments, and author claims as hypotheses to verify against the implementation. Keep this proportional to the change and do not invent speculative findings without reproducible reasoning or evidence.
6. Review for:
   - functional bugs and regressions,
   - API/props/data-contract mismatches,
   - security, permissions, secrets, or data-loss risks,
   - violations of project instructions,
   - comments or historical intent contradicted by the change.
7. Use focused tests or disposable scripts outside the checkout when they can safely prove or disprove a concrete suspicion. Do not modify the reviewed worktree or weaken existing checks.
8. Use `git blame`, local history, or earlier PRs only when they help verify a concrete suspicion.
9. Assign both severity and confidence to each finding. Keep only findings with confidence 80 or higher:
   - **Alta:** security exposure, data loss, production outage, major regression, or a correctness blocker.
   - **Media:** user-visible bug, broken or incomplete contract, missing validation, or missing test coverage that makes a regression likely.
   - **Baja:** non-blocking maintainability or minor correctness risk supported by concrete evidence.
10. Ignore nitpicks, style-only comments, preexisting problems outside changed lines, and issues already covered by lint/typecheck/CI unless the evidence shows CI will miss them.
11. If reviewing a PR, use `gh pr comment` only when the user explicitly authorized the external write in the current session. Otherwise report findings locally.

## Output

Lead with findings ordered by severity. Include `archivo:linea` or a GitHub link, severity,
confidence, impact, and a concrete explanation.

Use this shape:

```markdown
### Code review

Se encontraron N problemas:

1. [Alta|Media|Baja] <hallazgo> (confianza: <80-100>)
<archivo:linea o enlace>
<explicacion concreta>
```

If there are no findings:

```markdown
### Code review

Sin problemas. Se realizó una revisión adversarial en busca de bugs, casos límite y cumplimiento de instrucciones del proyecto.
```

## Notes

- In repos with subprojects, run the diff inside the subproject being reviewed.
- For GitHub links, use the full commit SHA.
- State the reviewed head and whether uncommitted changes were included. Distinguish findings
  from required tests or other reviews that are pending; no code findings does not prove that
  those checks passed or authorize marking ready or merging.
- Keep the final answer short and focused on risks, evidence, and verdict.
