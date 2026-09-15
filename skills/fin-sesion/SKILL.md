---
name: fin-sesion
description: Cierra una sesión guardando aprendizajes y progreso, y delega a cerrar-pr la publicación de cambios terminados después de verificar y ejecutar /revisa. Usar con /fin, "seguimos en otra sesión", "terminamos por hoy" o equivalentes; no usar para merge ni para forzar la publicación de trabajo incompleto.
---

# Fin de sesión

Preserve the useful context of the current session and close completed changes without duplicating
the code review or Git publishing workflows.

## Authorization

An explicit `/fin` request or an explicit request to finish the session authorizes writing the
session's in-scope memory and progress note. It also counts as explicit authorization to use
`cerrar-pr` for completed changes from this session: safe branch, commit, push, and PR only.
It never authorizes merge, deployment, production changes, destructive actions, unrelated files,
or publishing incomplete work as ready.

## Workflow

1. Inspect every repository touched in the session with `git status`. Separate this session's work
   from preexisting or unrelated user changes; never include the latter in a close-out.
2. Save only durable learnings: user corrections, decisions, reusable project context, and verified
   pending state. Follow the current memory ownership rules and update existing documentation instead
   of duplicating it. Never store secrets, private values, or claims that were not verified.
3. Create or update a concise session progress note with completed work, verified pending work, and
   blockers. Follow the repository's documented location and format; when none exists, use
   `docs/md/yyyymmdd_session_<topic>.md` without creating a broader documentation structure.
4. For each repository whose changes are complete, create or reuse a safe feature branch when needed,
   then run the relevant tests, lint, typecheck, build, or equivalent verification. Run `code-review`
   (`/revisa`) in read-only mode, correct valid high and medium findings, update tests, rerun
   verification, and repeat until no valid high or medium findings remain.
5. Invoke `cerrar-pr` for each repository that passed the review gate. Let it own staging, commit,
   push, and PR creation or update. Do not reproduce those operations in this skill.
6. Report memories or notes updated, verification results, remaining local changes, branches, commits,
   and PR URLs.

## Incomplete Work

If work is incomplete, verification fails, or the review gate cannot pass, do not force
`cerrar-pr`. Record the exact verified state and blocker in the session note, leave unrelated and
unfinished files untouched, and report clearly that they were not published as ready.

Never merge, deploy, start development servers, or add workflow or AI attribution to GitHub content.
