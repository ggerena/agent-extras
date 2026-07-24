---
name: code-review
description: Use when the user asks for code review, /code-review, revisar un PR, revisar una rama, revisar cambios contra develop, or wants a senior review of a pull request or branch diff without editing files. The review should prioritize real bugs, regressions, project-instruction violations, and high-confidence findings, then optionally comment on the PR.
---

# Code Review

Act as a senior code reviewer. Review a Pull Request or the current branch diff against `develop`.
Do not edit files, commit, push, or merge.

## Workflow

1. Identify whether the target is a PR or the current branch.
2. If it is a PR, check that it is open, not draft, not trivial/automatic, and not already reviewed by the same agent.
3. Read relevant project instructions such as `AGENTS.md`, `CLAUDE.md`, `.opencode`, or equivalent files for the modified paths.
4. Read the full diff with `gh pr diff <n>` for a PR, or `git diff develop...HEAD` for the current branch.
5. Review for:
   - functional bugs and regressions,
   - API/props/data-contract mismatches,
   - security, permissions, secrets, or data-loss risks,
   - violations of project instructions,
   - comments or historical intent contradicted by the change.
6. Use `git blame`, local history, or earlier PRs only when they help verify a concrete suspicion.
7. Assign confidence 0-100 to each finding and keep only findings at 80 or higher.
8. Ignore nitpicks, style-only comments, preexisting problems outside changed lines, and issues already covered by lint/typecheck/CI unless the evidence shows CI will miss them.
9. If reviewing a PR and high-confidence findings remain, comment with `gh pr comment`. If there are no findings, comment only when the user or repo workflow expects a PR comment.

## Output

Lead with findings ordered by severity. Include `archivo:linea` or a GitHub link, confidence, and a concrete explanation.

Use this shape:

```markdown
### Code review

Se encontraron N problemas:

1. <hallazgo> (confianza: <80-100>)
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
