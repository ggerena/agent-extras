---
name: autodev
description: Ejecuta un plan de implementación existente con respaldo temprano en PR borrador para repositorios de código, cambios mínimos, pruebas y revisión obligatorias antes de darlo por listo. Usar con /autodev o para llevar un plan hasta PR revisados; no crear el plan, desplegar, operar en Producción ni hacer merge.
---

# Autodev

Lleva un plan de implementación existente desde su respaldo temprano en borrador hasta completar
los PR con revisión. Reutiliza `cambio-minimo` para las decisiones de implementación, `code-review`
para la revisión en solo lectura y `cerrar-pr` para commit, push y creación del PR, sin duplicar
esos procedimientos.

## Autorización

Un pedido explícito de `/autodev` o de ejecutar un plan de principio a fin autoriza la implementación
local dentro del alcance, la verificación no destructiva, las ramas de trabajo seguras, los commits,
los push y los PR que requiera ese plan. Nunca autoriza merge, despliegue, cambios en Producción,
acciones destructivas ni ampliaciones del plan. Prevalece cualquier instrucción más restrictiva
del usuario. En repositorios de código, una instrucción permanente aplicable de respaldo también
autoriza publicar temprano los cambios solicitados sin otra confirmación rutinaria. Respeta las
excepciones documentales de push directo de las instrucciones aplicables del cliente o proyecto;
no dupliques aquí su lista de repositorios. Esos procedimientos específicos quedan fuera de este
flujo de PR.

No inventes un plan que falta. Si no existe un plan utilizable, detente tras identificar ese requisito.

## Flujo

1. Localiza y lee el plan completo, el `AGENTS.md` aplicable y las instrucciones del proyecto.
   Identifica repositorios afectados, ramas base, dependencias, criterios de éxito y fases. Antes
   de cambiar código, revisa configuración, entorno y estado de los datos pertinentes cuando
   puedan explicar o alterar el comportamiento solicitado.
2. Crea o reutiliza una rama de trabajo segura por repositorio; nunca hagas push directo a `main`,
   `master` o `develop`, salvo que las instrucciones aplicables definan un procedimiento documental
   de push directo. Usa un worktree solo cuando lo permitan las instrucciones del cliente y del
   proyecto y el aislamiento ayude de forma material a preservar cambios locales o trabajo paralelo;
   en otro caso, prefiere la copia de trabajo existente y una rama normal.
3. Ejecuta las fases en orden de dependencia. Aplica `cambio-minimo` y verifica cada función o
   corrección según la política de pruebas aplicable; esta skill no autoriza casos nuevos que esa
   política prohíba. Respeta las reglas vigentes del proyecto para cualquier delegación permitida.
   Elige al agente actual o a un subagente adecuado disponible en el entorno para cada fase de
   implementación, según la política de delegación del cliente. Mantén un solo escritor por
   repositorio y rama. Si no hay subagente disponible, implementa directamente cuando tengas
   capacidad y autorización; no sustituyas una revisión independiente expresamente requerida por
   una autorrevisión. Delegar no amplía el alcance, los accesos ni los permisos de publicación.
4. En repositorios de código, invoca `cerrar-pr` en modo `-Backup` tras el primer cambio dentro
   del alcance y en puntos significativos de implementación o corrección. Antes de publicar,
   revisa secretos, archivos preparados ajenos, commits salientes y remoto de destino. No esperes
   a completar el plan, las pruebas ni las revisiones para crear el PR borrador. Reutiliza la misma
   rama y PR; devuelve un PR listo a borrador antes de otro push. No repitas aquí el procedimiento
   de Git/GitHub.
5. Ejecuta pruebas, lint, comprobación de tipos, compilación o verificación equivalente pertinentes
   en cada repositorio afectado. Reutiliza guías y herramientas de pruebas existentes. Si están
   autorizadas las ediciones del repositorio y falta una guía de la función afectada, complétala
   con condiciones previas, datos de prueba sin secretos, rol, acciones, estado final esperado y
   evidencia observable; distingue comprobaciones ejecutadas y pendientes. En un trabajo de solo
   lectura, informa que falta la guía sin crearla. No crees otro sistema de pruebas.
   Nunca inicies servidores de desarrollo. Las pruebas básicas en navegador requieren un pedido explícito.
6. Ejecuta `code-review` (`/revisa`) sobre el diff completo de cada rama y sus cambios locales.
   Valida cada hallazgo, corrige de inmediato los hallazgos altos y medios válidos, mantén las
   pruebas dentro de la política aplicable, vuelve a verificar y repite la revisión hasta que no
   queden hallazgos altos o medios válidos. Corrige hallazgos bajos solo cuando el cambio sea
   directo, seguro y esté dentro del plan.
   Si la misma verificación y revisión ya fueron satisfactorias en un flujo que contiene este
   procedimiento para el contenido, base y entorno exactos, reutiliza esa evidencia. Repite solo
   tras un cambio, fallo, incertidumbre o instrucción que exija expresamente una nueva ejecución.
7. En repositorios que usen el flujo de PR, invoca `cerrar-pr` en modo revisado tras aprobar las
   comprobaciones locales. Mantén el trabajo incompleto hasta que pasen las pruebas y revisiones
   requeridas para el último commit publicado. Mantén el PR en borrador, salvo que las reglas del
   repositorio requieran `ready` para activar CI; en ese caso, marcarlo listo inicia la validación,
   pero no demuestra que haya terminado. Nunca hagas merge automáticamente.
8. Actualiza el plan solo con estados demostrados durante esta ejecución y después informa fases
   completadas, evidencia de verificación, ramas, enlaces a los PR y bloqueos restantes.

## Condiciones de parada

Una implementación incompleta o pruebas y revisiones fallidas o pendientes bloquean el cierre;
marcar el PR listo sigue la excepción de activación de CI del paso 7. Esas condiciones no bloquean
un respaldo seguro en borrador en un repositorio de código. Conserva el progreso verificado en el
borrador y continúa las correcciones autorizadas. Detén la publicación si hay secretos, cambios
ajenos que no puedas excluir con seguridad, destino incierto o falta de autorización para publicar.
Detén el trabajo afectado ante una decisión material de producto, acción destructiva, acceso nuevo,
operación en Producción o ampliación de alcance que el plan original no autorice. Informa los
bloqueos sin afirmar que el trabajo está completo.

Nunca hagas merge. No agregues atribuciones al flujo de trabajo ni a una IA en mensajes de commit,
títulos o descripciones de PR.
