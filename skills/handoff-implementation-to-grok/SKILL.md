---
name: handoff-implementation-to-grok
description: Usar cuando Codex o Claude Code deban reducir el consumo de cuota del coordinador mientras Grok Build implementa, valida, revisa, corrige y completa el cierre operativo de una fase grande y coherente de código. Preferir paquetes sustanciales y autocontenidos, con un repositorio y rama por fase. Incluye selección de esfuerzo medium/high, sesiones de dos archivos, hash del plan fuente, controles de revisión en solo lectura, controles automáticos de Git y rutas, seguimiento en segundo plano, cierre autorizado con commit/push/PR sin merge, informes Markdown, limpieza y lanzadores Python/PowerShell portables. No usar para traspaso total de responsabilidad, merge, despliegue ni una segunda opinión aislada.
---

# Delegación supervisada a Grok Build

Mantener al invocador como coordinador y aprobador. Delegar a Grok la mayor
fase coherente y verificable que quepa dentro de un repositorio y una rama, con rutas
explícitas.

## Tamaño de la delegación

- Preferir paquetes grandes y autocontenidos: implementación, pruebas,
  correcciones relacionadas, validaciones y preparación del cierre del mismo
  objetivo deben viajar juntos.
- No crear microfases por archivo, hallazgo, prueba o ajuste cuando Grok pueda
  resolverlos razonablemente en una sola ejecución.
- Agrupar todos los hallazgos conocidos del mismo repositorio y objetivo antes de
  lanzar `implement`.
- Dividir solo por una frontera real: repositorios o ramas distintos, bloqueo externo,
  autorización diferente, riesgo operacional independiente o un conjunto de
  `AllowedPaths` que deje de ser auditable.
- Mantener una fase auditable por repositorio, pero lanzar en paralelo todas las fases
  grandes que puedan avanzar con un contrato esperado explícito. No serializar
  repositorios por defecto: una dependencia parcial no obliga a esperar si Grok puede
  implementar, probar y reportar el punto de integración pendiente sin inventar
  el contrato.
- No interrumpir a Grok para asignarle trabajo adicional que ya podía incluirse
  en el paquete inicial. Acumular observaciones no urgentes para la siguiente
  ejecución correctiva de la misma fase.

## Flujo obligatorio

1. Leer `AGENTS.md`, estado Git y plan fuente.
2. Consolidar todos los cambios claros y relacionados del repositorio; luego definir
   objetivo, `AllowedPaths` (incluyendo los archivos de prueba), validaciones
   —siempre con la ejecución de pruebas— y esfuerzo:
   - `high` es el valor por defecto y sirve para casi todo: una fase cuesta
     centavos, así que bajar el esfuerzo solo compra velocidad a cambio de peor
     resultado.
   - `medium` solo si el cambio es trivial y quieres que termine antes.
   - `max` para lo realmente delicado: seguridad, concurrencia o migraciones.
3. Exigir un control previo `pass`; no usar `SkipReviewGate` salvo autorización
   explícita mediante `ForceHandoff` y `ForceReason`.
4. Iniciar `implement` y conservar su `phaseDirectory`.
5. Monitorear con `wait-grok-handoff.ps1` en ventanas de hasta 55 segundos. El
   estado efectivo debe tener controles de alcance sin violaciones.
6. Reutilizar la misma fase para una ejecución separada `review` en `high`.
7. Si hay hallazgos, reutilizarla para `implement` correctivo y luego otro
   `review`. El coordinador (Codex o Claude Code, quien haya invocado la skill)
   revisa el diff después de la revisión de Grok.
8. Tras aprobación, reutilizarla para `closeout`.
9. Generar el reporte Markdown y limpiar la fase cuando su información ya esté
   absorbida.

Lanzar en paralelo las fases de repositorios distintos siempre que el mensaje de instrucciones declare
el contrato esperado, los puntos todavía pendientes y la prohibición de
inventarlos. Esperar el resultado de otra fase solo cuando sea materialmente
imposible implementar o validar sin su diff definitivo.

## Contrato de dos archivos

Usar una carpeta estable por fase:

```text
<workspace>/.agent-handoffs/grok/<repo>/<phase-id>/
├── handoff.json
└── result.json
```

- Reutilizarla con `PhaseDirectory`; no crear una carpeta por implementación,
  revisión, corrección y cierre.
- `handoff.json` conserva hasta 20 resultados compactos en `history`.
- `result.json` contiene el intento actual, diagnóstico del proceso y
  controles de alcance.
- Grok devuelve JSON estructurado; el supervisor escribe `result.json` de forma
  atómica. Grok no debe editarlo directamente.
- No escribir intercambio dentro del repositorio objetivo.

Resolver la raíz mediante `HandoffRoot`, `AGENT_HANDOFF_ROOT`,
`WorkspaceRoot`/`AGENT_WORKSPACE_ROOT`, `.agent-handoffs` o el `AGENTS.md`
ancestral más cercano.

## Ahorro de cuota

- Usar `PlanReadPolicy auto`.
- El primer intento con un plan usa `full`.
- Los intentos posteriores de la misma fase usan `verify`: comprueban ruta y
  SHA-256 y consumen el historial compacto sin releer el plan completo.
- Si cambia el hash, bloquear `verify` y exigir otra lectura `full`.
- No duplicar el mensaje de instrucciones ni copiar contenido del plan al traspaso.
- No repetir mecánicamente todas las validaciones de Grok; el coordinador
  profundiza solo ante fallos, riesgo o evidencia incompleta.

## Controles de alcance automáticos

`get-grok-handoff-status.ps1` y `grok_handoff.py status` deben verificar:

- rama y HEAD sin cambios en `implement` y `review`;
- cero cambios de archivos durante `review`;
- cambios de `implement` solo dentro de `AllowedPaths`;
- commits de `closeout` solo sobre `AllowedPaths`;
- coherencia entre commit reportado y HEAD;
- proceso `pending` sin PID vivo como fallo;
- resultado JSON válido y perteneciente a la fase/intento;
- integridad: `result.json` guarda un SHA-256 de modo, `AllowedPaths`, repositorio, captura
  original y cabezas remotas; si `handoff.json` no coincide, es violación
  `handoff_integrity_mismatch`;
- en `closeout`, las ramas `main`, `master`, `develop` y `BaseBranch` del remoto
  (`git ls-remote`) no deben cambiar entre el inicio y el final. Se consulta al
  iniciar (si falla el comando, el `closeout` se niega; una rama inexistente se
  guarda como `absent` y sigue protegida) y una sola vez al terminar, en el
  supervisor; `status` reutiliza lo guardado y no vuelve a consultar el remoto.
  Si se declara push, el commit publicado debe coincidir con HEAD (rama remota,
  rama remota de seguimiento o `ls-remote`; las reglas piden `git push -u`).

Tratar cualquier violación como `failed`, aunque Grok haya declarado `pass`.

Límite conocido: los controles de alcance solo ven lo que `git` reporta dentro del repositorio. No
detectan escrituras en archivos ignorados por git (`.gitignore`) ni fuera del
repositorio. Revisar a mano si importa.

Mientras corre la cadena automática, el supervisor mantiene su PID vivo y
`execution.chain_running=true`; `status` y `wait` no la dan por terminada ni por
desactualizada y no escriben `result.json`, y no se puede lanzar otra ejecución sobre la
fase. Si el supervisor muere a media cadena, `status` marca
`chain_interrupted_without_process`. `remove -ForceRunning` mata supervisor y
Grok con todo su árbol. Cada etapa se audita contra el estado del repositorio en que la
recibe, así los cambios del `implement` previo no cuentan como escrituras del
revisión. `status` solo escribe cuando cambia el estado y relee antes de hacerlo.

## Revisión y corrección automáticas

Un `implement` que termina en `pass` encadena solo: **pruebas → revisión →
corrección → revisión final**, sin que el coordinador lance cada paso. Antes eran
ejecuciones manuales y en la práctica la revisión se saltaba.

El paso de pruebas solo se ejecuta si el diff del `implement` no tocó ningún
archivo de prueba: el supervisor lo detecta por la ruta (`__tests__/`, `tests/`,
`*.test.*`, `*.spec.*`, `test_*.py`) y le reclama a Grok las pruebas que exija la
política de pruebas del proyecto antes de revisar; si esa política no permite
ninguna nueva, Grok lo explica y ejecuta las existentes. Delegar esto importa porque Grok omite las pruebas de forma
sistemática y detectarlo a mano le cuesta al coordinador una lectura completa
del diff. Se desactiva con `--no-test-gate` en fases de documentación o
configuración, donde no aplica.

Política de corrección, aplicada por Grok en el paso intermedio:

- Hallazgos de severidad **alta y media**: se corrigen siempre.
- De **baja**: solo los directos — renombres, comentarios que quedaron
  incorrectos, validaciones simples, duplicación evidente, manejo de error que
  falta.
- De baja que impliquen rediseño o decisiones de producto: **no se tocan**, se
  listan en `next_step` para el coordinador.

Si la etapa de pruebas no termina en `pass`, la cadena se corta con ese estado y no
sigue a la revisión. Si la revisión final aún trae hallazgos, el estado queda
`blocked`.

Cada etapa queda resumida en `result.json` bajo `chain`. Se desactiva con
`--no-auto-review` cuando la fase se quiere revisar a mano.

El coordinador revisa igual el diff final: la revisión automática no lo
reemplaza, le ahorra la primera pasada.

## Cómo se invoca a Grok

El lanzador ya resuelve esto; se documenta porque cada punto costó una fase
fallida y conviene no revertirlo sin entender por qué está.

- **`--max-turns 300`.** El límite por defecto de modo no interactivo corta a Grok a las
  pocas vueltas, normalmente después de leer el plan y antes de escribir nada.
  Es la causa más frecuente de una fase que "no hizo nada".
- **La ruta del `handoff.json` va dentro del texto del mensaje de instrucciones.**
  `--prompt-file` entrega al modelo solo el campo `content` y descarta el resto
  del archivo; sin la ruta, Grok responde `needs-user` pidiendo la tarea.
- **Sin `--json-schema`.** Forzar salida estructurada choca con las varias
  vueltas de Grok y el entorno de ejecución aborta con `stopReason: Cancelled`. El esquema
  viaja en el mensaje de instrucciones y el supervisor se queda con el último JSON válido de la
  salida.
- **Consola propia, minimizada.** Sin consola Grok cancela la sesión y sus
  confirmaciones le aparecen al usuario como ventanas sueltas y sin contexto.
- **Permisos explícitos por modo** (`--allow` / `--deny`): lectura siempre;
  escritura solo en `implement` y `closeout`; `ValidationCommands` declarados;
  `git commit`/`push`/`gh pr` solo en `closeout`; `rm`, `sudo`, `reset`,
  `rebase`, `merge` y `tag` siempre denegados. Una confirmación que nadie puede
  responder equivale a una fase perdida.

## Modos

### `implement`

- Exigir `AllowedPaths`. **Sin comodines**: el validador compara prefijos de
  directorio, así que `backend/src/api/x` sirve y `backend/src/api/x/**` no.
  Con comodines Grok toca los archivos correctos pero los controles de alcance los marcan
  fuera de alcance y la fase queda inservible.
- **Exigir pruebas según la política del proyecto.** Toda funcionalidad nueva y toda corrección
  de errores del paquete debe incluir las pruebas que esa política exija o permita, nuevas o
  actualizadas: los archivos de prueba van dentro de `AllowedPaths` y su ejecución dentro de
  `ValidationCommands`. Si la política no permite ninguna prueba nueva para el paquete, basta
  con ejecutar las existentes pertinentes en `ValidationCommands`. Un `implement` sin pruebas
  ni validación ejecutable se trata como paquete mal definido y se corrige antes de lanzar;
  este flujo no autoriza crear pruebas prohibidas.
  Grok entrega implementaciones completas y válidas omitiendo las pruebas aunque
  estén pedidas de forma explícita; por eso el supervisor las reclama solo antes
  de revisar. Al coordinador le queda comprobar que las pruebas que llegaron
  prueben algo real, no que existan.
- Editar solo esas rutas y ejecutar solo `ValidationCommands`.
- Eliminar artefactos de validación que queden fuera de alcance.
- No hacer commit, push, PR, merge ni despliegue.

### `review`

- Exigir esfuerzo `high`.
- Ejecutar `/revisa` de forma estrictamente no invasiva.
- Las `ValidationCommands` se muestran solo como contexto: no se ejecutan en
  revisión.
- Incluir archivos con seguimiento, preparados y sin seguimiento.
- No crear archivos ni ejecutar compilación, pruebas o comandos que escriban
  artefactos.
- Pasar `ReviewSkillPath` cuando el usuario exija una skill concreta.

### `closeout`

- Exigir `AllowGitCloseout`, `AllowedPaths`, control previo `pass` y autorización vigente
  del usuario.
- Usar `checkpoint` para commit+push de fase.
- Usar `pull-request` para commit+push y crear o reutilizar un PR.
- Pasar `UpdateExistingPr` y `PrBody` para actualizar un PR existente con
  alcance, commits, pruebas, pendientes y PR relacionados.
- Mantener una rama de trabajo por repositorio.
- No preparar todos los archivos sin selección, reescribir historia, hacer merge, crear etiquetas ni desplegar.
- Nunca operar sobre `main`, `master`, `develop`, `BaseBranch` o HEAD separado.

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

Reutilizar la fase para revisión:

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

En Linux/macOS o desde cualquier entorno de herramientas con Python 3, usar la misma semántica:

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

## Entorno de ejecución y seguridad

- Pasar `RuntimeSetupCommand` cuando el repositorio requiera una versión concreta. En
  Windows usar `fnm` o una ruta de Node comprobada; no improvisar `nvm use`.
- No usar `--always-approve`, `bypassPermissions`, worktrees ni memoria
  persistente de Grok.
- No incluir secretos, datos de solicitudes sensibles ni contenido de archivos en
  capturas. Las capturas guardan nombres y hashes.
- Capturar salida y errores solo como diagnóstico acotado y redactado.
- No modificar configuración o memoria de otros agentes.
- No lanzar servidores de desarrollo.
