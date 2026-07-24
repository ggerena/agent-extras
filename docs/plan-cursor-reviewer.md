# Plan: agregar Cursor (GPT-5.5) como revisor en differential-review

Estado: propuesta, pendiente de aprobación. No implementar hasta OK explícito.

## Objetivo

Sumar un cuarto revisor, `cursor`, a la skill `differential-review`, para que quien
trabaje con Cursor + GPT (como Felipe en Mac) pueda pedir la revisión diferencial sin
instalar Codex. Mantener el mismo contrato que los revisores actuales: solo lectura,
salida apendizada al archivo de análisis, sin tocar el repo.

## Limitación conocida (importante, va documentada)

El CLI de Cursor (`cursor-agent`, alias `agent`) **no permite fijar el nivel de
razonamiento**. GPT-5.5 ahí corre en "medium" fijo; no hay equivalente a `xhigh`.
Confirmado por staff de Cursor en su foro. Por eso este revisor es la excepción a la
política de "todos al máximo": se documenta que `cursor` corre en medium y que para
GPT-5.5 en `xhigh` el camino sigue siendo Codex (que también corre en Mac).

Datos del CLI usados en el diseño (docs oficiales de Cursor):
- Binario `cursor-agent` / `agent`, instala en `~/.local/bin`.
- Headless: `agent -p` con `--output-format text|json`.
- Modelo: `--model gpt-5.5` (verificar disponibilidad con `agent --list-models`).
- Solo lectura: `--mode ask` (explora sin editar). Ojo: en `-p` por defecto trae TODAS
  las herramientas, incluida escritura y shell, así que hay que forzar el modo lectura.
- Auth: `CURSOR_API_KEY` o `agent login` previo. Sirve sin sesión gráfica.

## Cambios en `skills/differential-review/scripts/differential-review.ps1`

1. **Parámetros**
   - Agregar `cursor` al `ValidateSet` de `-Reviewer` y de `-Invoker`.
   - Nuevos parámetros con override por entorno:
     - `-CursorPath`  → `DIFF_REVIEW_CURSOR_PATH`
     - `-CursorModel` (default `gpt-5.5`) → `DIFF_REVIEW_CURSOR_MODEL`
     - `-CursorMode`  (default `ask`, ValidateSet `ask`,`plan`) → `DIFF_REVIEW_CURSOR_MODE`

2. **Detección de auto-revisión** (`Resolve-InvokerAgent`)
   - Agregar rama `cursor`. Como no tengo confirmada la variable de entorno que expone
     el CLI de Cursor, la detección automática queda best-effort; lo confiable es pasar
     `-Invoker cursor`. Documentarlo igual que ya se hace con los otros.

3. **Construcción de la invocación** (nueva rama `elseif ($Reviewer -eq 'cursor')`)
   - Resolver binario con `Resolve-ExecutablePath` (candidatos `~/.local/bin/cursor-agent`,
     `~/.local/bin/agent`, y PATH).
   - Args base: `-p --model <CursorModel> --output-format text --mode <CursorMode>`.
   - Prompt: reutilizar el patrón de stdin de la rama no-codex (claude/opencode escriben
     el prompt a StandardInput). **A verificar en implementación**: que `cursor-agent -p`
     lea el prompt por stdin; si no, caer a pasarlo como argumento o por `--file`.
   - Working directory: el repo (como codex), para que pueda leer archivos en modo ask.
   - `reviewerDetails`: herramienta `cursor-agent`, modelo, modo, binario, repo de solo
     lectura, y nota "reasoning: medium (no configurable en el CLI)".
   - `-ExtraArgs`: rechazar flags que rompan el modo lectura o cambien el modelo/salida:
     `--mode`, `-m`/`--model`, `--output-format`, `-p`/`--print`, y cualquier flag que
     habilite escritura/shell. Mismo estilo de validación que las otras ramas.

4. **Salida**
   - Con `--output-format text`, tratar `cursor` como `opencode`: leer stdout, limpiar
     secuencias ANSI y escribir a `$outFile`. (Alternativa `json` si el texto trae ruido
     de progreso; se decide al verificar.)
   - `toolLabel = 'cursor-agent'` y mensaje `Write-Host "Invoking cursor-agent ..."`.

5. **Auth**
   - No bloquear si falta `CURSOR_API_KEY` (puede haber `agent login` previo). Si la
     autenticación falla, el binario devuelve no-cero y el script ya surfacea stderr.

## Cambios en `skills/differential-review/SKILL.md`

- Sumar `cursor` a la descripción y al bloque "How it works".
- Documentar: limitación de nivel (medium fijo), auth (`CURSOR_API_KEY` / `agent login`),
  ejemplo de uso, env vars nuevas y flags bloqueados en `-ExtraArgs`.

## Cambios en `skills/differential-review/agents/openai.yaml`

- Actualizar `short_description` / `default_prompt` para mencionar Cursor como opción.

## Verificación (este repo no tiene suite de tests; se valida por dry-run)

1. Parse OK del `.ps1`.
2. `-Reviewer cursor -PrintPromptOnly -Prompt "x"` imprime el prompt sin invocar binario
   (confirma que el `ValidateSet` acepta `cursor`).
3. Corrida real de solo lectura en Mac con `cursor-agent` instalado y autenticado:
   verificar que devuelve la revisión y que `git status` queda limpio (no editó nada).
   Yo estoy en Windows; si no tengo el binario, esta corrida la hace Felipe/el usuario en
   Mac y reporto el resultado.

## Decisiones abiertas (a cerrar durante la implementación)

- Nombre exacto del modelo (`gpt-5.5` confirmado con `agent --list-models`).
- Prompt por stdin vs argumento vs `--file`.
- Salida `text` vs `json`.
- Refuerzo del solo-lectura: `--mode ask` solo, o además permisos `deny` de escritura.

## Fuera de alcance

- Archivo de configuración central de proveedores/modelos/niveles. Ya es configurable por
  variables `DIFF_REVIEW_*` y los defaults están al máximo, así que no se agrega ahora.
- Soporte de nivel de razonamiento en Cursor: no existe en su CLI.

## Decisiones cerradas (tras validar con Codex + `cursor-agent --help` real)

- **Prompt por argumento posicional.** `cursor-agent -p "<texto>"`. No hay `--file` (`-f` es `--force`) ni stdin soportado. Se pasa con `ProcessStartInfo.ArgumentList` (escapado correcto por plataforma). Limitación documentada: prompts enormes (> límite de línea de comando del SO) podrían fallar; los análisis normales caben.
- **Solo-lectura.** `--mode ask` es read-only por diseño según el `--help` del binario. Es la garantía principal en v1. El refuerzo con `.cursor/cli.json` (`deny: ["Write(**)","Shell(**)"]`) se omite por ahora para no escribir archivos en el repo del usuario; queda como mejora futura documentada.
- **Salida.** `--output-format json`; se lee el campo `result` (mismo formato que Claude), reutilizando el parseo existente.
- **Auth.** Se **exige** `CURSOR_API_KEY`: sin sesión ni key el CLI puede quedarse colgado en headless. Fallo rápido con mensaje claro en vez de arriesgar el cuelgue.
- **Modelo.** Default `gpt-5.5`; se documenta verificar con `cursor-agent models`.
- **Auto-revisión.** No agrego heurística de detección para `cursor` (no hay variable de entorno confirmada); se confía en `-Invoker cursor`. Se documenta que desde Cursor conviene pasar `-Invoker cursor` o usar otro revisor.
- **"Sin tocar el repo".** Corrección de redacción: el único archivo que se modifica es el de análisis (al apendar la respuesta); no se toca código fuente.
- **ExtraArgs bloqueados.** `-f`/`--force`, `--yolo`, `--sandbox`, `--approve-mcps`, `--trust`, `--mode`, `-m`/`--model`, `--output-format`, `-p`/`--print`, `--api-key`.
- **Test sin Cursor real.** Verificación en Windows con un binario falso que captura los argumentos, para confirmar que la rama arma bien la invocación sin depender de una cuenta de Cursor.

## Comentarios IA externa (analisis diferencial)

- Fecha UTC: 2026-06-24T19:16:10Z
- Herramienta: codex-exec
- Model: gpt-5.5
- Reasoning effort: xhigh
- Profile: default
- Binary: [ruta local redactada]
- Version: codex-cli 0.142.0
- Sandbox: read-only

```text
**1. Supuestos débiles**
- El plan trata `cursor` como revisor diferencial, pero si el invocador también es Cursor, sería auto-revisión. El contrato actual bloquea eso con `-Invoker` cuando coincide con `-Reviewer`.
- “Solo lectura” depende casi por completo de `--mode ask`; no hay evidencia de que eso bloquee escrituras/shell en headless.
- “Salida apendizada al archivo de análisis, sin tocar el repo” es inconsistente: si el análisis está en `docs/`, apendarlo sí modifica el repo.
- La afirmación “GPT-5.5 corre en medium fijo” depende de foro/docs externas no citadas ni verificadas en el plan.
- El plan dice reutilizar stdin “como claude/opencode”, pero OpenCode actualmente usa `--file` además de stdin.

**2. Escenarios que rompen la conclusión**
- Cursor ejecutado desde Cursor: o falla por self-review si se pasa `-Invoker cursor`, o hace auto-revisión silenciosa si no se pasa.
- `--mode ask` permite pedir aprobación para editar, o no deshabilita shell: el wrapper ya no cumple el contrato de solo lectura.
- `cursor-agent -p` no lee stdin: la rama puede colgarse, devolver vacío o ignorar el prompt.
- `agent login` en headless abre flujo interactivo: el job puede quedar corriendo indefinidamente.
- `git status` limpio no prueba ausencia de cambios: puede haber archivos ignorados, cambios fuera del repo, caches o config global.

**3. Evidencia faltante**
- Confirmar con `agent --help`, `agent -p --help` y docs actuales las flags exactas: `--mode`, `--output-format`, stdin/archivo, permisos y nombres de modelo.
- Probar con fake binary que la rama arma args, cwd, stdin/stdout y metadata correctamente, sin requerir Cursor real.
- Probar flags bloqueadas en `-ExtraArgs`, incluyendo formas `--flag=value` y alias cortos.
- El script actual solo acepta `codex|claude|opencode` en `-Reviewer`/`-Invoker` [differential-review.ps1](../skills/differential-review/scripts/differential-review.ps1); verifiqué que `-Reviewer cursor -PrintPromptOnly` falla por `ValidateSet`.
- Revisar cómo desplegar la skill: el repo tiene fuente bajo `skills/`, pero la skill activa también existe fuera del repo.

**4. Recomendación revisada**
Agregar `cursor` solo si queda documentado como revisor de menor garantía: no default, no equivalente a Codex xhigh, y válido principalmente cuando el invocador no es Cursor. Mantener `CursorMode` fijo en `ask` hasta probar que `plan` también es no mutante. Antes de implementar, cerrar stdin/archivo, salida text/json, modelo exacto y permisos read-only con evidencia del CLI real.

**5. Condiciones para parar**
No implementar si no hay prueba de solo lectura fuerte, si `cursor-agent -p` no acepta prompt de forma no interactiva, si el modelo `gpt-5.5` no aparece en `agent --list-models`, o si no se resuelve la contradicción Cursor-como-invocador vs Cursor-como-revisor.
```
