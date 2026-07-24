---
description: "Cierre de sesión: guardar aprendizajes, revisar cambios pendientes y dejar contexto para retomar. No cambia de branch."
---

Ejecuta el cierre de sesión siguiendo estos pasos en orden. Cada paso es importante para que la próxima sesión pueda retomar sin perder contexto.

## Paso 1: Guardar aprendizajes en memoria

Revisa la conversación actual buscando:
- **Feedback:** Correcciones del usuario sobre cómo trabajar, patrones a evitar o repetir
- **Proyecto:** Decisiones técnicas, contexto de negocio, estados de features. **Incluye ideas discutidas aunque se hayan descartado** — anotar la opción analizada + la decisión (ej: "propuesto X, descartado por Y"). El análisis es reutilizable.
- **Usuario:** Preferencias, rol, conocimientos nuevos descubiertos
- **Referencia:** Recursos externos mencionados (URLs, herramientas, dashboards)

Para cada item relevante, guárdalo en el sistema de memoria o documentación del proyecto, si existe. Si ya existe una memoria relacionada, actualízala en vez de crear una nueva. Si no hay nada nuevo que guardar, indicarlo brevemente y seguir.

## Paso 2: Verificar cambios sin commitear

Ejecuta `git status` en el directorio de trabajo.

- Si no hay cambios, indicarlo y continuar al Paso 4.
- Si hay cambios, lista los archivos modificados/nuevos de forma clara y continúa al Paso 3.

## Paso 3: Commit y push en la branch actual

El comportamiento depende de si el repo es **solo documentación** o **código ejecutable**:

### 3a. Repo solo documentación → automático, sin preguntar
Estos repos contienen solo `.md`, SQL idempotentes, planes o runbooks. Normalmente están en `master` o `main`, no tienen branch protection real y no afectan runtime.

1. `git add` de los archivos relevantes (no usar `git add -A` ciegamente — ignorar untracked que no tocaste).
2. Commit con mensaje descriptivo en español.
3. `git push` a la branch actual.

### 3b. Repos con código ejecutable → mostrar y preguntar
Estos repos tienen branch protection y requieren PR. **No auto-commitear.**

1. Listar los archivos modificados por sub-repo.
2. Informar al usuario y pedir indicación explícita antes de hacer commit/push.
3. Si el usuario confirma, proceder como 3a pero respetando la regla de PR (no push directo a branch protegida).

### Fallo de push
Si un push falla por branch protection, informar: "El push falló por protección de branch en `<branch>`. Los cambios están commiteados localmente; crea un PR manualmente o desde GitHub." y continuar con el siguiente paso.

## Paso 4: Guardar progreso de la sesión

Crea o actualiza un archivo markdown de sesión en `docs/md/`. Si el proyecto organiza la documentación por periodos, usar la subcarpeta correspondiente.

En ambos casos:
- Nombre: `yyyymmdd_session_<tema-breve>.md` (usar fecha actual)
- Contenido:
  - Qué se hizo en esta sesión
  - Qué queda pendiente
  - Blockers o notas para la próxima sesión

Si ya existe un archivo de sesión del mismo día, actualizarlo en vez de crear uno nuevo.

## Paso 5: Reportar branch actual

**No cambiar de branch.** Dejar cada repo (principal y sub-repos) en la branch en la que está trabajando el usuario.

Solo verificar con `git branch --show-current` e incluir la branch en el resumen del Paso 6.

## Paso 6: Confirmar cierre

Imprime un resumen breve:
- Memorias guardadas (si hubo)
- Commit realizado (si hubo)
- Archivo de sesión creado/actualizado
- Branch actual (sin cambios)

Cerrar con algo como: "Sesión cerrada. La próxima sesión puede retomar desde `docs/md/<archivo>`."
