---
name: code-review
description: Use when the user asks for code review, /revisa, /code-review, revisar un PR, revisar una rama, revisar cambios contra develop, or wants a senior review of a pull request or branch diff without editing files. Prioritize real bugs, regressions, project-instruction violations, and high-confidence findings; comment on the PR only with explicit authorization.
---

# Code Review

Act as a senior code reviewer. Review a Pull Request or the current branch diff against `develop`.
This is a read-only skill: do not edit files, create reports in the repo, commit, push, or merge.
Do not fix findings here. Return them to the user or to the enclosing workflow, such as `cerrar-pr`,
which owns any authorized corrections and verification.

**Qué flujo de revisión corresponde:** esta skill revisa directamente una rama o PR. Si el usuario
pide la opinión de OTRO agente, desde Codex usa `mandalo-por-buzz` con el alcance solicitado; desde
otros entornos usa el mecanismo de delegación disponible. Si hay que traspasar la implementación,
usa el flujo de handoff correspondiente. Para un release de Goflow próximo a Prod, usa
`crear-release` en modo revisión.

## Workflow

1. Identify whether the target is a PR or the current branch.
2. If it is a PR, check that it is open, not draft, not trivial/automatic, and not already reviewed by the same agent.
3. Read relevant project instructions such as `AGENTS.md`, `CLAUDE.md`, `.opencode`, or equivalent files for the modified paths.
4. Read the full diff with `gh pr diff <n>` for a PR, or `git diff develop...HEAD` for the current branch. Include tracked changes without commit and relevant untracked files with `git diff` and `git ls-files --others --exclude-standard`.
5. Review for:
   - functional bugs and regressions,
   - API/props/data-contract mismatches,
   - security, permissions, secrets, or data-loss risks,
   - violations of project instructions,
   - comments or historical intent contradicted by the change.
6. Use `git blame`, local history, or earlier PRs only when they help verify a concrete suspicion.
7. Assign both severity and confidence to each finding. Keep only findings with confidence 80 or higher:
   - **Alta:** security exposure, data loss, production outage, major regression, or a correctness blocker.
   - **Media:** user-visible bug, broken or incomplete contract, missing validation, or missing test coverage that makes a regression likely.
   - **Baja:** non-blocking maintainability or minor correctness risk supported by concrete evidence.
8. Ignore nitpicks, style-only comments, preexisting problems outside changed lines, and issues already covered by lint/typecheck/CI unless the evidence shows CI will miss them.
9. If reviewing a PR, use `gh pr comment` only when the user explicitly authorized the external write in the current session. Otherwise report findings locally.

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

Sin problemas. Se reviso en busca de bugs y cumplimiento de instrucciones del proyecto.
```

## Notes

- In repos with subprojects, run the diff inside the subproject being reviewed.
- For GitHub links, use the full commit SHA.
- Keep the final answer short and focused on risks, evidence, and verdict.
