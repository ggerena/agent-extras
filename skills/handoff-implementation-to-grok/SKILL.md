---
name: handoff-implementation-to-grok
description: Use when Codex or Claude Code should minimize coordinator quota while Grok Build implements, validates, reviews, corrects, and operationally closes one scoped coding phase. Provides medium/high effort selection, two-file phase sessions, source-plan hashing, read-only review gates, automatic Git/path guardrails, detached monitoring, approved commit/push/PR closeout without merge, Markdown reporting, cleanup, and portable Python/PowerShell launchers. Do not use for full ownership transfer, merge, deploy, or a pure second opinion.
---

# Delegación supervisada a Grok Build

Mantener al invocador como coordinador y aprobador. Delegar a Grok una fase
pequeña, verificable y con paths explícitos.

## Flujo obligatorio

1. Leer `AGENTS.md`, estado Git y plan fuente.
2. Definir objetivo, `AllowedPaths`, validaciones y esfuerzo:
   - `medium`: alcance claro, corrección conocida o tests acotados.
   - `high`: seguridad, concurrencia, migración, arquitectura ambigua o review.
3. Exigir un gate previo `pass`; no usar `SkipReviewGate` salvo autorización
   explícita mediante `ForceHandoff` y `ForceReason`.
4. Iniciar `implement` y conservar su `phaseDirectory`.
5. Monitorear con `wait-grok-handoff.ps1` en ventanas de hasta 55 segundos. El
   estado efectivo debe tener guardrails sin violaciones.
6. Reutilizar la misma fase para un run separado `review` en `high`.
7. Si hay hallazgos, reutilizarla para `implement` correctivo y luego otro
   `review`. Codex revisa el diff después del review de Grok.
8. Tras aprobación, reutilizarla para `closeout`.
9. Generar el reporte Markdown y limpiar la fase cuando su información ya esté
   absorbida.

No iniciar la fase siguiente antes de revisar el resultado, las validaciones y
el diff de la actual.

## Contrato de dos archivos

Usar una carpeta estable por fase:

```text
<workspace>/.agent-handoffs/grok/<repo>/<phase-id>/
├── handoff.json
└── result.json
```

- Reutilizarla con `PhaseDirectory`; no crear una carpeta por implementación,
  review, corrección y cierre.
- `handoff.json` conserva hasta 20 resultados compactos en `history`.
- `result.json` contiene el intento actual, diagnóstico del proceso y
  guardrails.
- Grok devuelve JSON estructurado; el supervisor escribe `result.json` de forma
  atómica. Grok no debe editarlo directamente.
- No escribir intercambio dentro del repo objetivo.

Resolver la raíz mediante `HandoffRoot`, `AGENT_HANDOFF_ROOT`,
`WorkspaceRoot`/`AGENT_WORKSPACE_ROOT`, `.agent-handoffs` o el `AGENTS.md`
ancestral más cercano.

## Ahorro de cuota

- Usar `PlanReadPolicy auto`.
- El primer intento con un plan usa `full`.
- Los intentos posteriores de la misma fase usan `verify`: comprueban ruta y
  SHA-256 y consumen el historial compacto sin releer el plan completo.
- Si cambia el hash, bloquear `verify` y exigir otra lectura `full`.
- No duplicar el prompt ni copiar contenido del plan al handoff.
- No repetir mecánicamente todas las validaciones de Grok; Codex profundiza solo
  ante fallos, riesgo o evidencia incompleta.

## Guardrails automáticos

`get-grok-handoff-status.ps1` y `grok_handoff.py status` deben verificar:

- rama y HEAD sin cambios en `implement` y `review`;
- cero cambios de archivos durante `review`;
- cambios de `implement` solo dentro de `AllowedPaths`;
- commits de `closeout` solo sobre `AllowedPaths`;
- coherencia entre commit reportado y HEAD;
- proceso `pending` sin PID vivo como fallo;
- resultado JSON válido y perteneciente a la fase/intento.

Tratar cualquier violación como `failed`, aunque Grok haya declarado `pass`.

## Modos

### `implement`

- Exigir `AllowedPaths`.
- Editar solo esos paths y ejecutar solo `ValidationCommands`.
- Eliminar artefactos de validación que queden fuera de alcance.
- No hacer commit, push, PR, merge ni deploy.

### `review`

- Exigir esfuerzo `high`.
- Ejecutar `/revisa` de forma estrictamente no invasiva.
- Incluir tracked, staged y untracked.
- No crear archivos ni ejecutar build, tests o comandos que escriban
  artefactos.
- Pasar `ReviewSkillPath` cuando el usuario exija una skill concreta.

### `closeout`

- Exigir `AllowGitCloseout`, `AllowedPaths`, gate `pass` y autorización vigente
  del usuario.
- Usar `checkpoint` para commit+push de fase.
- Usar `pull-request` para commit+push y crear o reutilizar un PR.
- Pasar `UpdateExistingPr` y `PrBody` para actualizar un PR existente con
  alcance, commits, pruebas, pendientes y PR relacionados.
- Mantener una rama feature por repo.
- No stagear globalmente, reescribir historia, mergear, taggear ni desplegar.
- Nunca operar sobre `main`, `master`, `develop`, `BaseBranch` o detached HEAD.

## Ejecución

Usar PowerShell en Windows:

```powershell
$skill = "$env:USERPROFILE\.agents\skills\handoff-implementation-to-grok\scripts"
$start = & "$skill\handoff-implementation-to-grok.ps1" `
  -Mode implement `
  -Objective "Implementar solo el adaptador X" `
  -AllowedPaths "backend/src/x.ts","backend/src/__tests__/x.test.ts" `
  -ValidationCommands "npm test -- x.test.ts","npm run build" `
  -PlanPath "C:\ruta\PLAN.md" `
  -PlanReadPolicy auto `
  -GrokReasoningEffort medium `
  -ReasoningRationale "Cambio acotado con contrato definido." `
  -ReviewSummary "Plan revisado sin bloqueantes." `
  -Launch | ConvertFrom-Json
```

Reutilizar la fase para review:

```powershell
& "$skill\handoff-implementation-to-grok.ps1" `
  -PhaseDirectory $start.phaseDirectory `
  -Mode review `
  -Objective "Ejecutar /revisa high sobre la fase" `
  -PlanPath "C:\ruta\PLAN.md" `
  -PlanReadPolicy auto `
  -ReviewSkillPath "C:\ruta\revisa\SKILL.md" `
  -GrokReasoningEffort high `
  -ReasoningRationale "Gate independiente obligatorio." `
  -ReviewSummary "Implementación terminada y validada." `
  -Launch
```

Monitorear, reportar y limpiar:

```powershell
& "$skill\get-grok-handoff-status.ps1" -PhaseDirectory $start.phaseDirectory
& "$skill\wait-grok-handoff.ps1" -PhaseDirectory $start.phaseDirectory
& "$skill\export-grok-handoff-report.ps1" `
  -PhaseDirectory $start.phaseDirectory `
  -Output "C:\ruta\REPORTE.md"
& "$skill\remove-grok-handoff.ps1" -PhaseDirectory $start.phaseDirectory
```

En Linux/macOS o desde cualquier harness con Python 3, usar la misma semántica:

```bash
python3 scripts/grok_handoff.py start --mode implement \
  --objective "Implementar solo X" \
  --allowed-path backend/src/x.ts \
  --reasoning-effort medium \
  --reasoning-rationale "Cambio acotado" \
  --review-summary "Plan aprobado" \
  --launch
python3 scripts/grok_handoff.py status --phase-dir /ruta/fase
python3 scripts/grok_handoff.py wait --phase-dir /ruta/fase
```

## Runtime y seguridad

- Pasar `RuntimeSetupCommand` cuando el repo requiera una versión concreta. En
  Windows usar `fnm` o una ruta de Node comprobada; no improvisar `nvm use`.
- No usar `--always-approve`, `bypassPermissions`, worktrees ni memoria
  persistente de Grok.
- No incluir secretos, payloads sensibles ni contenido de archivos en
  snapshots. Los snapshots guardan nombres y hashes.
- Capturar salida y errores solo como diagnóstico acotado y redactado.
- No modificar configuración o memoria de otros agentes.
- No lanzar servidores de desarrollo.
