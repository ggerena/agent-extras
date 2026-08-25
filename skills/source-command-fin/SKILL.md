---
name: "source-command-fin"
description: "Cierre de sesión: guardar aprendizajes y respaldar cambios con verificación, commit, push y PR en una rama segura, sin merge automático. Usar con /fin, 'seguimos en otra sesión', 'terminamos por hoy' o variantes."
---

# source-command-fin

Use this skill when the user asks to run the migrated source command `fin`.

## Command Template

Ejecuta el cierre de sesión siguiendo estos pasos en orden. Cada paso es importante para que la próxima sesión pueda retomar sin perder contexto.

## Paso 1: Guardar aprendizajes en memoria

Revisa la conversación actual buscando:
- **Feedback:** Correcciones del usuario sobre cómo trabajar, patrones a evitar o repetir
- **Proyecto:** Decisiones técnicas, contexto de negocio, estados de features. **Incluye ideas discutidas aunque se hayan descartado** — anotar la opción analizada + la decisión (ej: "propuesto X, descartado por Y"). El análisis es reutilizable.
- **Usuario:** Preferencias, rol, conocimientos nuevos descubiertos
- **Referencia:** Recursos externos mencionados (URLs, herramientas, dashboards)

Para cada item relevante, guárdalo en el sistema de memoria (`~/.Codex/projects/<project>/memory/`). Si ya existe una memoria relacionada, actualízala en vez de crear una nueva. Si no hay nada nuevo que guardar, indicarlo brevemente y seguir.

## Paso 2: Verificar cambios sin commitear

Ejecuta `git status` en el directorio de trabajo.

- Si no hay cambios, indicarlo y continuar al Paso 4.
- Si hay cambios, lista los archivos modificados/nuevos de forma clara y continúa al Paso 3.

## Paso 3: Verificar, crear rama segura, commit, push y PR

1. Si la rama actual es `master`, `main` o `develop`, crear una rama de trabajo apropiada antes de commitear.
2. Ejecutar tests, lint y build razonables. Si fallan y el respaldo sigue siendo necesario, dejar el PR como draft y documentar el fallo; no presentar el trabajo como listo.
3. Seleccionar solo archivos relevantes; no usar `git add -A` ciegamente ni incluir cambios ajenos, secretos o artefactos.
4. Hacer commit y push en la rama de trabajo.
5. Crear un PR si no existe o actualizar el existente. Nunca mergearlo como parte de esta skill.

### Fallo de push
Si un push falla por branch protection, informar: "El push falló por protección de branch en `<branch>`. Los cambios están commiteados localmente; creá un PR manualmente o desde GitHub." y continuar con el siguiente paso.

## Paso 4: Guardar progreso de la sesión

Crea o actualiza un archivo markdown de sesión:
- **Proyecto goflow:** guardar en `docs/md/<YYYY>_Q<N>/` (subcarpeta por trimestre, ej: `2026_Q1/`, `2026_Q2/`). Si la subcarpeta no existe, crearla.
- **Cualquier otro proyecto:** guardar directo en `docs/md/`.

En ambos casos:
- Nombre: `yyyymmdd_session_<tema-breve>.md` (usar fecha actual)
- Contenido:
  - Qué se hizo en esta sesión
  - Qué queda pendiente
  - Blockers o notas para la próxima sesión

Si ya existe un archivo de sesión del mismo día, actualizarlo en vez de crear uno nuevo.

## Paso 5: Reportar branch y PR

Verificar con `git branch --show-current` e incluir la rama segura y la URL del PR en el resumen del Paso 6.

## Paso 6: Confirmar cierre

Imprime un resumen breve:
- Memorias guardadas (si hubo)
- Commit realizado (si hubo)
- Archivo de sesión creado/actualizado
- Branch actual y PR

Cerrar con algo como: "Sesión cerrada. La próxima sesión puede retomar desde `docs/md/<archivo>`."
