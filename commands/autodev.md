---
description: "Desarrollo autónomo por fases: toma un plan existente, crea rama, implementa cada fase con commits, y deja PRs listos."
---

Ejecuta desarrollo autónomo basado en un plan de implementación existente. Trabaja de forma autónoma y no hagas preguntas a menos que encuentres un blocker crítico que impida continuar.

## Paso 0: Localizar el plan y detectar proyecto

1. Si el usuario pasó un argumento (nombre de archivo o path), usar ese archivo como plan.
2. Si no, buscar en `docs/md/` (y subcarpetas) el archivo más reciente que contenga "PLAN" o "plan" en el nombre.
3. Leer el plan completo e identificar:
   - Las **fases** de implementación (ordenadas)
   - Los **subproyectos** afectados (detectar automáticamente buscando subdirectorios con `.git` o `package.json`/`go.mod`/`Cargo.toml`/etc.)
   - La **rama base** (leer de cada subproyecto: normalmente `develop` o `main`)
   - Las **dependencias entre subproyectos** (ej: si el plan dice que el backend expone un endpoint que el frontend consume, el backend se implementa primero)
4. Detectar el stack de cada subproyecto automáticamente:
   - Si tiene `package.json` con scripts `build` → usar ese script para compilar
   - Si tiene `yarn.lock` → usar `yarn`, si tiene `package-lock.json` → usar `npm`
   - Si tiene `go.mod` → usar `go build`
   - Adaptar comandos al stack detectado
5. Mostrar resumen: "Plan encontrado: {nombre}. {N} fases, subproyectos: {lista con stack detectado}. Dependencias: {grafo}."

## Paso 1: Preparar ramas (PARALELO)

Lanzar **un subagente por subproyecto** para preparar las ramas en paralelo. Cada subagente:
1. Navega al directorio del subproyecto
2. Se asegura de estar en la rama base y hace `git pull`
3. Crea una nueva rama con formato: `feat/<ticket-id>-<descripcion-corta>` (extraer ticket del plan si existe)
4. Si la rama ya existe (de una sesión anterior), continuar sobre ella (no preguntar, el usuario no está)

Esperar a que todos los subagentes terminen antes de continuar.

## Paso 2: Ejecutar fases secuencialmente

Las fases se ejecutan en orden (fase 2 puede depender de fase 1). Dentro de cada fase, paralelizar donde sea posible.

Para cada fase del plan:

### 2a. Implementar
- Leer los requisitos de la fase en el plan
- **Si los subproyectos son independientes en esta fase** (no hay dependencia de datos entre ellos): lanzar un subagente por subproyecto para implementar en paralelo
- **Si hay dependencias** (ej: backend primero, frontend después): implementar en el orden correcto, secuencialmente
- Preferir modificar código existente sobre crear abstracciones nuevas
- Seguir las convenciones del proyecto (leer los archivos de instrucciones locales si existen)

### 2b. Build (PARALELO)
- Lanzar **builds en paralelo** para cada subproyecto modificado en esta fase, usando el comando detectado en Paso 0
- Recopilar resultados de todos los builds antes de continuar

### 2c. Commit, push y PR (PARALELO)
- Lanzar **un subagente por subproyecto** para hacer commit, push y PR en paralelo
- Cada subagente:
  - Hace commit con mensaje: `feat(<subproyecto>): <descripcion> (fase N/M)`
  - Push a la rama remota
  - **Si es la fase 1 (primer push):** crear el PR con `gh pr create` como draft o normal, hacia la rama base. Título: `feat: <descripcion del plan> (<ticket>)`. Body inicial con nota "En progreso — desarrollo autónomo con /autodev".
  - **Si el PR ya existe:** no hacer nada extra, el push actualiza el PR automáticamente
- Esperar a que todos terminen

### 2d. Actualizar plan y reportar progreso
- **Actualizar el archivo del plan:** marcar la fase como completada (agregar checkmark, ej: `- [x] Fase N: ...`) e incluir una nota breve con los commits. Si el plan no usa checkmarks, adaptar al formato existente agregando un indicador claro de completado.
- Imprimir un resumen al chat:
  ```
  --- Fase N/M completada ---
  Cambios: {archivos modificados por subproyecto}
  Commits: {hashes}
  ```
- Si una fase falla o queda incompleta, marcarla con indicador de error y documentar el motivo en el plan.

## Paso 3: Actualizar PRs (PARALELO)

Los PRs ya fueron creados en la fase 1. Ahora actualizar el body con el resumen final.
Lanzar **un subagente por subproyecto** en paralelo:
1. Actualizar el body del PR con `gh pr edit` para incluir:
   - Resumen de lo implementado
   - Lista de fases completadas
   - Nota: "Desarrollo autónomo con /autodev"
2. NO hacer merge.

Recopilar URLs de todos los PRs.

## Paso 4: Resumen final y limpieza

Imprimir resumen completo:
```
=== /autodev completado ===
Plan: {nombre del plan}
Fases: {N} completadas
PRs creados:
  - {subproyecto}: {url del PR}
Pendiente: merge manual por el usuario
```

Después del resumen, ejecutar `/compact` para liberar contexto y permitir que el usuario siga trabajando en la misma sesión.

## Reglas importantes

- **NO hacer merge.** Solo crear PRs.
- **NO preguntar al usuario** excepto por blockers críticos (ej: el plan es ambiguo, hay conflictos de merge irresolubles, un build falla repetidamente).
- **Reportar progreso** al completar cada fase para que el usuario pueda ver el avance si revisa.
- **Si un build falla:** intentar resolver hasta 3 veces. Si no se resuelve, dejar un commit con el estado actual, documentar el error en el PR, y continuar con la siguiente fase si es posible.
- **Si hay conflictos de merge:** intentar resolver automáticamente. Si no es posible, pausar y reportar.
- **Commits atómicos:** cada fase es un commit (o grupo de commits). No mezclar fases en un solo commit.
- **Tests:** si el plan incluye tests, crearlos. Si no los menciona, crear tests básicos para la funcionalidad nueva.
- **Detección de stack:** nunca asumir herramientas hardcodeadas. Siempre detectar el package manager, build tool y estructura del subproyecto antes de ejecutar comandos.
- **Instrucciones del proyecto:** si el subproyecto o el repo padre tiene archivos de instrucciones locales, leerlos y seguir sus convenciones (idioma de commits, branch naming, etc.).
- **Paralelismo:** usar subagentes (Agent tool) para ejecutar tareas independientes en paralelo. Nunca paralelizar tareas que tengan dependencias de datos entre sí.
- **Coordinación de subagentes:** siempre esperar a que TODOS los subagentes de un paso terminen antes de avanzar al siguiente paso. Recopilar y consolidar resultados.
