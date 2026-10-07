---
name: handoff-implementation-to-codex
description: Use when the user asks to delegate a large cohesive coding phase to Codex CLI (GPT-6.1 Sol) so the coordinator spends minimal quota while Codex implements, validates, reviews, corrects, and operationally closes it. Prefer substantial self-contained work packages over small sequential tasks, with one repo and branch per phase. Provides medium/high/xhigh effort selection, two-file phase sessions, source-plan hashing, per-mode sandboxes (read-only review, workspace-write implement), automatic Git/path guardrails, detached monitoring, approved commit/push/PR closeout without merge, Markdown reporting, cleanup, and portable Python/PowerShell launchers. Do not use for a one-off question or second opinion (run `codex exec` directly), full ownership transfer, merge, or deploy.
---

# Delegación supervisada a Codex

Mantener al invocador como coordinador y aprobador. Delegar a Codex (GPT-6.1
Sol) la mayor fase coherente y verificable que quepa dentro de un repo y una
rama, con paths explícitos.

## Tamaño de la delegación

- Preferir paquetes grandes y autocontenidos: implementación, pruebas,
  correcciones relacionadas, validaciones y preparación del cierre del mismo
  objetivo deben viajar juntos.
- No crear microfases por archivo, hallazgo, test o ajuste cuando Codex pueda
  resolverlos razonablemente en una sola ejecución.
- Agrupar todos los hallazgos conocidos del mismo repo y objetivo antes de
  lanzar `implement`.
- Dividir solo por una frontera real: repos o ramas distintos, bloqueo externo,
  autorización diferente, riesgo operacional independiente o un conjunto de
  `AllowedPaths` que deje de ser auditable.
- Mantener una fase auditable por repo, pero lanzar en paralelo todas las fases
  grandes que puedan avanzar con un contrato esperado explícito. No serializar
  repos por defecto: una dependencia parcial no obliga a esperar si Codex puede
  implementar, probar y reportar el punto de integración pendiente sin inventar
  el contrato.
- No interrumpir a Codex para asignarle trabajo adicional que ya podía incluirse
  en el paquete inicial. Acumular observaciones no urgentes para la siguiente
  ejecución correctiva de la misma fase.

## Flujo obligatorio

1. Leer `AGENTS.md`, estado Git y plan fuente.
2. Consolidar todos los cambios claros y relacionados del repo; luego definir
   objetivo, `AllowedPaths` (incluyendo los archivos de test), validaciones
   —siempre con la ejecución de tests— y esfuerzo:
   - `high` es el valor por defecto y sirve para casi todo.
   - `medium` solo si el cambio es trivial y quieres que termine antes.
   - `xhigh` para lo realmente delicado: seguridad, concurrencia o migraciones.
3. Exigir un gate previo `pass`; no usar `SkipReviewGate` salvo autorización
   explícita mediante `ForceHandoff` y `ForceReason`.
4. Iniciar `implement` y conservar su `phaseDirectory`.
5. Monitorear con `wait-codex-handoff.ps1` en ventanas de hasta 55 segundos. El
   estado efectivo debe tener guardrails sin violaciones.
6. Reutilizar la misma fase para un run separado `review` en `high` o `xhigh`.
7. Si hay hallazgos, reutilizarla para `implement` correctivo y luego otro
   `review`. El coordinador revisa el diff después del review de Codex.
8. Tras aprobación, reutilizarla para `closeout`.
9. Generar el reporte Markdown y limpiar la fase cuando su información ya esté
   absorbida.

Lanzar en paralelo las fases de repos distintos siempre que el prompt declare
el contrato esperado, los puntos todavía pendientes y la prohibición de
inventarlos. Esperar el resultado de otra fase solo cuando sea materialmente
imposible implementar o validar sin su diff definitivo.

## Contrato de dos archivos

Usar una carpeta estable por fase:

```text
<workspace>/.agent-handoffs/codex/<repo>/<phase-id>/
├── handoff.json
└── result.json
```

- Reutilizarla con `PhaseDirectory`; no crear una carpeta por implementación,
  review, corrección y cierre.
- `handoff.json` conserva hasta 20 resultados compactos en `history`.
- `result.json` contiene el intento actual, diagnóstico del proceso, consumo de
  tokens y guardrails.
- Codex devuelve JSON estructurado; el supervisor escribe `result.json` de forma
  atómica. Codex no debe editarlo directamente.
- Junto a esos dos archivos el supervisor deja material de trabajo propio
  (`prompt.md`, `schema.json`, `last-message.json`); se borra con la fase.
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
- No repetir mecánicamente todas las validaciones de Codex; el coordinador
  profundiza solo ante fallos, riesgo o evidencia incompleta.
- `result.json` registra `usage` por intento (tokens de entrada, en caché, de
  salida y de razonamiento) y `usage_total` cuando corre la cadena automática.

## Guardrails automáticos

`get-codex-handoff-status.ps1` y `codex_handoff.py status` deben verificar:

- rama y HEAD sin cambios en `implement` y `review`;
- cero cambios de archivos durante `review`;
- cambios de `implement` solo dentro de `AllowedPaths`;
- commits de `closeout` solo sobre `AllowedPaths`;
- coherencia entre commit reportado y HEAD;
- proceso `pending` sin PID vivo como fallo;
- resultado JSON válido y perteneciente a la fase/intento;
- integridad: `result.json` guarda un SHA-256 de modo, `AllowedPaths` y foto
  original; si `handoff.json` (que Codex podría escribir) no coincide, es
  violación;
- en `closeout`, las ramas `main`, `master`, `develop` y `BaseBranch` del remoto
  (`git ls-remote`) no deben cambiar entre el inicio y el final; y si se
  declara push, el commit publicado debe coincidir con HEAD (se acepta la rama
  remota o el upstream; las reglas piden `git push -u`).

Tratar cualquier violación como `failed`, aunque Codex haya declarado `pass`.
El sandbox es la primera barrera; los guardrails son la segunda y la única que
cubre las rutas permitidas.

Límite conocido: los guardrails solo ven lo que `git` reporta dentro del repo.
No detectan escrituras en archivos ignorados por git (`.gitignore`) ni fuera del
repo, y `workspace-write` sí puede escribir fuera. Revisar a mano si importa.

Mientras corre la cadena automática, el supervisor mantiene su PID vivo y
`execution.chain_running=true`; `status` y `wait` no la dan por terminada ni por
rancia, y no se puede lanzar otra ejecución sobre la fase. Si el supervisor muere
a media cadena, `status` marca `chain_interrupted_without_process`.

## Revisión y corrección automáticas

Un `implement` que termina en `pass` encadena solo: **tests → review →
corrección → review final**, sin que el coordinador lance cada paso.

El paso de tests solo se ejecuta si el diff del `implement` no tocó ningún
archivo de prueba: el supervisor lo detecta por la ruta (`__tests__/`, `tests/`,
`*.test.*`, `*.spec.*`, `test_*.py`) y le reclama a Codex los tests que faltan
antes de revisar. Se desactiva con `-NoTestGate` (`--no-test-gate`) en fases de
documentación o configuración, donde no aplica.

Política de corrección, aplicada por Codex en el paso intermedio:

- Hallazgos de severidad **alta y media**: se corrigen siempre.
- De **baja**: solo los directos — renombres, comentarios que quedaron
  mentirosos, validaciones simples, duplicación evidente, manejo de error que
  falta.
- De baja que impliquen rediseño o decisiones de producto: **no se tocan**, se
  listan en `next_step` para el coordinador.

Si la etapa de tests no termina en `pass`, la cadena se corta con ese estado y no
sigue al review. En `review` las `ValidationCommands` se muestran solo como
contexto y no se ejecutan. Si el review final aún trae hallazgos, el estado queda
`blocked`.

Cada etapa queda resumida en `result.json` bajo `chain`. Se desactiva con
`-NoAutoReview` (`--no-auto-review`) cuando la fase se quiere revisar a mano.
Cada etapa se audita contra el estado del repo en que la recibe, así los cambios
del `implement` previo no cuentan como escrituras del review.

El coordinador revisa igual el diff final: la revisión automática no lo
reemplaza, le ahorra la primera pasada.

## Cómo se invoca a Codex

El lanzador ya resuelve esto (verificado con codex-cli 0.160.1 en Windows). Se
documenta para no revertirlo sin entender por qué está.

```text
codex exec -C <repo> -m <model> -c model_reasoning_effort=<effort>
  -c approval_policy="never" -s <sandbox> --ephemeral --color never --json
  --output-schema <fase>/schema.json -o <fase>/last-message.json -
```

- **Prompt por stdin** (`-`), tomado de `prompt.md`. Los archivos auxiliares
  viven en la carpeta de fase, nunca en el repo objetivo.
- **Resultado por esquema.** `--output-schema` más `-o` entregan el último
  mensaje como JSON que cumple el esquema. Si `last-message.json` falta o no es
  válido, el supervisor toma el último mensaje del agente en el flujo `--json`
  y, como último recurso, el último JSON válido de la salida.
- **Modelo y esfuerzo.** Modelo por defecto `gpt-6.1-sol` (`CodexModel`).
  Esfuerzo `medium`, `high` (por defecto) o `xhigh`.
- **Sandbox por modo:**
  - `review` → `read-only`: Codex no puede escribir; es la garantía principal
    de revisión no invasiva.
  - `implement` → `workspace-write`: escribe en el repo, pero `.git` queda de
    solo lectura, así que no puede commitear ni cambiar de rama. También puede
    escribir fuera del repo (carpetas temporales, directorios hermanos); por eso
    `AllowedPaths` y los guardrails siguen siendo obligatorios. No tiene red.
  - `closeout` → `danger-full-access`: necesita escribir `.git` y red para
    `git push` y `gh pr`. Solo se permite con `AllowGitCloseout`; sin esa
    bandera el lanzador se niega. Se apoya en las reglas del prompt y en los
    guardrails posteriores.
- **`approval_policy="never"`** se pasa siempre, sin depender de la config del
  usuario.
- **No usar** `--dangerously-bypass-approvals-and-sandbox`, `--worktree`,
  `--approve-for-me` ni `--ignore-user-config` (este último quitaría el modelo y
  la autenticación de la config).
- **Ruido de MCP.** Codex carga los MCP de la config del usuario y algunos
  fallan (`rmcp::transport::worker ... 127.0.0.1:8000`). Se filtran del
  diagnóstico y no cuentan como fallo.
- **Proceso.** Corre en segundo plano sin ventana ni consola. Se guarda el PID
  (`codex_pid`); `remove-codex-handoff.ps1 -ForceRunning` mata el árbol completo
  (`codex.exe` y sus hijos).
- Resolución del binario: `CODEX_BIN`, luego `codex` en el `PATH`, luego
  `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin\codex.exe`.

## Modos

### `implement`

- Exigir `AllowedPaths`. **Sin comodines**: el validador compara prefijos de
  directorio, así que `backend/src/api/x` sirve y `backend/src/api/x/**` no.
- **Exigir tests siempre.** Toda funcionalidad nueva y todo bug fix del paquete
  debe incluir tests nuevos o actualizar los existentes: los archivos de test
  van dentro de `AllowedPaths` y su ejecución dentro de `ValidationCommands`.
  Un `implement` sin tests se trata como paquete mal definido y se corrige antes
  de lanzar, no después. Es regla del usuario, no criterio del agente. Al
  coordinador le queda comprobar que los tests que llegaron prueben algo real,
  no que existan.
- Editar solo esos paths; leer libremente y, para probar, ejecutar solo `ValidationCommands`.
- Eliminar artefactos de validación que queden fuera de alcance.
- No hacer commit, push, PR, merge ni deploy.

### `review`

- Exigir esfuerzo `high` o `xhigh`.
- Revisión adversarial estrictamente no invasiva: bugs reales, regresiones y
  violaciones del `AGENTS.md` del repo.
- Incluir tracked, staged y untracked.
- No crear archivos ni ejecutar build, tests o comandos que escriban
  artefactos.
- Pasar `ReviewSkillPath` cuando el usuario exija una skill concreta; Codex la
  lee completa y la aplica. Sin ella se usa la revisión propia descrita arriba.

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
$skill = "$env:USERPROFILE\.agents\skills\handoff-implementation-to-codex\scripts"
$start = & "$skill\handoff-implementation-to-codex.ps1" `
  -Mode implement `
  -Objective "Implementar solo el adaptador X" `
  -AllowedPaths "backend/src/x.ts","backend/src/__tests__/x.test.ts" `
  -ValidationCommands "npm test -- x.test.ts","npm run build" `
  -PlanPath "C:\ruta\PLAN.md" `
  -PlanReadPolicy auto `
  -CodexReasoningEffort high `
  -ReasoningRationale "Cambio acotado con contrato definido." `
  -ReviewSummary "Plan revisado sin bloqueantes." `
  -Launch | ConvertFrom-Json
```

Reutilizar la fase para review:

```powershell
& "$skill\handoff-implementation-to-codex.ps1" `
  -PhaseDirectory $start.phaseDirectory `
  -Mode review `
  -Objective "Revisar la fase de forma adversarial" `
  -PlanPath "C:\ruta\PLAN.md" `
  -PlanReadPolicy auto `
  -ReviewSkillPath "C:\ruta\revisa\SKILL.md" `
  -CodexReasoningEffort high `
  -ReasoningRationale "Gate independiente obligatorio." `
  -ReviewSummary "Implementación terminada y validada." `
  -Launch
```

Monitorear, reportar y limpiar:

```powershell
& "$skill\get-codex-handoff-status.ps1" -PhaseDirectory $start.phaseDirectory
& "$skill\wait-codex-handoff.ps1" -PhaseDirectory $start.phaseDirectory
& "$skill\export-codex-handoff-report.ps1" `
  -PhaseDirectory $start.phaseDirectory `
  -Output "C:\ruta\REPORTE.md"
& "$skill\remove-codex-handoff.ps1" -PhaseDirectory $start.phaseDirectory
```

En Linux/macOS o desde cualquier harness con Python 3, usar la misma semántica:

```bash
python3 scripts/codex_handoff.py start --mode implement \
  --objective "Implementar solo X" \
  --allowed-path backend/src/x.ts \
  --reasoning-effort high \
  --reasoning-rationale "Cambio acotado" \
  --review-summary "Plan aprobado" \
  --launch
python3 scripts/codex_handoff.py status --phase-dir /ruta/fase
python3 scripts/codex_handoff.py wait --phase-dir /ruta/fase
```

## Runtime y seguridad

- Pasar `RuntimeSetupCommand` cuando el repo requiera una versión concreta. En
  Windows usar `fnm` o una ruta de Node comprobada; no improvisar `nvm use`.
- No saltarse el sandbox ni las aprobaciones, y no usar worktrees del lanzador.
- No incluir secretos, payloads sensibles ni contenido de archivos en
  snapshots. Los snapshots guardan nombres y hashes.
- Capturar salida y errores solo como diagnóstico acotado y redactado.
- No modificar configuración o memoria de otros agentes.
- No lanzar servidores de desarrollo.
