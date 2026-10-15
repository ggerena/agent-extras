---
name: agent-handoff
description: >-
  Usar cuando un agente (Codex, Claude Code u OpenCode) necesite traspasar un trabajo en curso a
  otro porque perdió el rumbo, encontró un bloqueo, empezó a perder tiempo o el usuario quiere
  cambiar al responsable. Prepara un Markdown autocontenido con el estado objetivo del repositorio
  (git status, git log, git diff, BITACORA y reglas), el objetivo, motivo y siguiente paso que aporte
  el agente, y un mensaje listo para el destinatario. Primera dirección admitida: Codex a OpenCode.
  No usar para segundas opiniones que mantengan al mismo responsable; corresponde code-review.
---

# Traspaso entre agentes

Traspasa la responsabilidad de un trabajo a otro agente con un paquete listo para retomarlo.
La primera dirección validada es Codex -> OpenCode. Otras direcciones (Claude -> Codex,
OpenCode -> Claude, etc.) se pueden configurar, pero aún no se han validado de principio a fin.

El agente de origen deja de estar a cargo y el agente de destino continúa el trabajo. Una revisión
consultiva conserva al responsable y tiene un procedimiento distinto.

## Cuándo usarla

- El agente actual perdió el rumbo, repite pasos o avanza poco y el usuario quiere que otro agente lo reemplace.
- El usuario pide expresamente «pasa la pelota», «traspasa el trabajo», «continúa desde OpenCode»,
  «seguir en Codex» o «traspasa a Claude».
- Hace falta cambiar de contexto y resumir manualmente el estado perdería datos.
- Estás en Codex y quieres que OpenCode u otro agente continúe desde el estado exacto del repositorio.

## Cuándo no usarla

- Solo quieres una segunda opinión y conservar la responsabilidad. Usa `code-review` con otro agente
  cuando esa consulta esté autorizada.
- La tarea es pequeña y un agente nuevo puede reconstruir el estado en pocos segundos.
- El destinatario no puede leer el repositorio porque no comparte el sistema de archivos.
  Traspasa solo cuando pueda acceder a la misma ruta del repositorio.

## Funcionamiento portable

1. El script incluido captura el estado objetivo del repositorio, sin depender de la memoria del agente:
   - `git rev-parse --abbrev-ref HEAD` (rama actual);
   - `git rev-parse HEAD` (commit actual);
   - `git status --porcelain` (archivos modificados o sin seguimiento);
   - `git log --oneline -20` (historial reciente);
   - `git diff --stat` (cambios no preparados) y `git diff --cached --stat` (cambios preparados).
2. Detecta qué archivos de reglas existen: `AGENTS.md`, `CLAUDE.md`, `LOCAL_CHANGES.md` y
   `BITACORA.md`. Si existe `BITACORA.md`, incorpora las últimas 40 líneas para mostrar las
   decisiones recientes al destinatario sin obligarlo a releer todo.
3. Lee el contexto aportado por el agente desde parámetros o un archivo de notas:
   - objetivo original
   - motivo del traspaso
   - siguiente paso recomendado
   - dudas abiertas
4. Escribe `docs/YYYYMMDD_HANDOFF-<from>-to-<to>.md` con datos concretos, separando hechos
   comprobados, inferencias y dudas.
5. Escribe o actualiza `docs/HANDOFF-index.md` con el traspaso más reciente primero para poder
   recorrer una cadena de traspasos.
6. Muestra un mensaje listo para el agente de destino y el comando sugerido para iniciarlo.

El agente de origen no hace push ni merge ni inicia servidores. Solo escribe el Markdown de
traspaso y el índice.

## Dirección Codex -> OpenCode

Desde una sesión de Codex, ejecuta el script instalado:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\agent-handoff\scripts\agent-handoff.ps1" -From codex -To opencode -Objective "objetivo original en una linea" -Reason "por que se traspasa" -NextStep "siguiente paso recomendado"
```

En macOS/Linux, desde una sesión de Codex:

```bash
bash ~/.agents/skills/agent-handoff/scripts/agent-handoff.sh -From codex -To opencode -Objective "objetivo original" -Reason "motivo" -NextStep "siguiente paso"
```

Entrega:

- `docs/YYYYMMDD_HANDOFF-codex-to-opencode.md`
- Un mensaje que puedes pegar en una sesión de OpenCode.
- Un comando sugerido `opencode run` para una ejecución única. En la configuración local observada,
  ese comando registra una sesión visible en OpenCode Desktop para continuar allí sin abrir otra terminal.

El script no inicia OpenCode automáticamente por defecto. Pasa `-Launch` para solicitar una
primera ejecución no interactiva con `opencode run`. Por defecto solo muestra el comando; al
ejecutarlo, OpenCode Desktop puede mostrar la sesión registrada para continuarla.

## Dirección Codex -> Claude Code

Usa el mismo script con `-To claude`. El generador del comando admite opciones de modelo y esfuerzo
de Claude; por ejemplo, desde Codex con esfuerzo `high` a Claude Code Opus 4.8 con esfuerzo `medium`:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\agent-handoff\scripts\agent-handoff.ps1" -From codex -To claude -ClaudeModel claude-opus-4-8 -ClaudeEffort medium -Objective "objetivo original en una linea" -Reason "por que se traspasa" -NextStep "siguiente paso recomendado"
```

Esto escribe el Markdown de traspaso y un archivo de mensaje; después muestra un comando de
Claude Code sin `-p` para iniciar una sesión interactiva. El comando incluye `--name` para
encontrar el traspaso fácilmente desde `/resume`.

## Ejecución

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\agent-handoff.ps1 -From codex -To opencode -Objective "..." -Reason "..." -NextStep "..."
```

Leer objetivo, motivo y siguiente paso de un archivo de notas que deje el agente:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\agent-handoff.ps1 -From codex -To opencode -NotesFile docs\handoff-notes.md
```

Simulación: mostrar el Markdown y el mensaje sin escribir archivos:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\agent-handoff.ps1 -From codex -To opencode -DryRun
```

Valores predeterminados:

- `<skill-root>` es la carpeta de la skill `agent-handoff` instalada. La ubicación compartida
  es `~\.agents\skills\agent-handoff`; también puedes ejecutar los scripts desde una copia del repositorio.
- `-From` usa `codex` y `-To` usa `opencode` por defecto.
- `-OutDir` usa `docs` dentro del repositorio.
- `-RepoPath` usa el directorio de trabajo actual.
- `-OpenCodeModel` usa `opencode-go/glm-5.2`. El script normaliza `glm-5.2` a `opencode-go/glm-5.2`.
- `-OpenCodeVariant` usa `max`.
- `-ClaudeModel` usa `claude-opus-4-8`.
- `-ClaudeEffort` usa `medium`.
- `-ClaudePermissionMode` usa `plan`.
- `-BitacoraTail` usa `40` líneas.

Opciones configurables:

- `-From codex|claude|opencode` y `-To codex|claude|opencode` eligen la dirección.
- `-Objective`, `-Reason`, `-NextStep` y `-OpenQuestions` aportan el contexto del agente en los parámetros.
- `-NotesFile` lee esos mismos campos de un Markdown con las secciones `## Objetivo`, `## Motivo`,
  `## Siguiente paso` y `## Dudas`.
- `-ClaudeModel`, `-ClaudeEffort` y `-ClaudePermissionMode` personalizan el comando generado de Claude Code.
- `-Launch` solicita una primera ejecución no interactiva de `opencode run` con `-To opencode`.
- `-DryRun` muestra el resultado sin escribirlo.

## Después del traspaso

Después de escribir el Markdown de traspaso:

1. El agente de origen deja de hacer cambios. No sigue editando el repositorio en paralelo.
2. El agente de origen informa al usuario la ruta del archivo y el comando sugerido.
3. El agente de destino confirma primero que leyó el objetivo, vio los archivos afectados y
   respetará las reglas del repositorio enumeradas en el traspaso. Solo después procede al siguiente
   paso recomendado.
4. Si el agente de destino también se bloquea, escribe otro traspaso con `-From <itself> -To <next>`.
   El índice permite recorrerlos.

## Reglas de seguridad

- No hagas merge, push ni push forzado. El script nunca modifica remotos de Git.
- No inicies servidores de desarrollo. El script nunca inicia servicios de larga duración.
- No borres archivos ni estado. El script solo escribe el Markdown de traspaso y el índice.
- No ocultes errores. Si el traspaso se debe a que el agente perdió el rumbo, `-Reason` debe indicarlo.
- Mantén el traspaso basado en datos: hechos comprobados, inferencias y dudas van en secciones separadas.
- No incluyas secretos en objetivo, motivo ni siguiente paso. El script no los elimina.

## Relación con la revisión de código

- `code-review`: «revisa esto e informa». El responsable conserva el trabajo.
- `agent-handoff`: «toma el contexto y continúa». La responsabilidad se traspasa.

Son skills separadas con procedimientos propios; una consulta de revisión no activa el traspaso.

## Instalación

La fuente única está en `skills/agent-handoff` en este repositorio. Ejecuta el instalador para
actualizar la instalación compartida de la skill en `.agents`:

```powershell
powershell -ExecutionPolicy Bypass -File skills\agent-handoff\scripts\install.ps1
```

Por defecto, el instalador omite un destino si `agent-handoff` ya está instalado allí para no
reemplazar silenciosamente ediciones locales. Para reemplazar una instalación existente desde
la fuente del repositorio, ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File skills\agent-handoff\scripts\install.ps1 -Force
```

Con `-Force`, el instalador reemplaza la instalación existente de `.agents` por la versión del
repositorio. Recupera versiones anteriores desde el historial de Git, no desde carpetas de
respaldo instaladas.

El instalador copia la skill en:

- `%USERPROFILE%\.agents\skills\agent-handoff`

Vuelve a ejecutarlo con `-Force` después de un cambio para actualizar la copia instalada.

## Modos pendientes

- Modo integrado de Codex App: crear o continuar directamente un chat de Codex cuando estén
  disponibles las herramientas internas `create_thread`, `fork_thread` y `send_message_to_thread`.
  Aún no está validado.
- Inicio en OpenCode Desktop: `opencode run` crea una sesión registrada visible en OpenCode Desktop
  en la configuración local observada. El script no debe abrir una ventana PowerShell separada;
  continúa desde la sesión de Desktop.
- Traspaso a una sesión de Claude Code ya abierta: el script crea una sesión interactiva nueva
  con nombre; introducir el encargo en una sesión existente sigue siendo manual.
- Traspaso a una sesión existente en vez de una nueva: aún no se admite.
