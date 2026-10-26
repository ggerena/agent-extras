---
name: cerrar-pr
description: Respalda temprano cambios de repositorios de código en una rama y PR borrador, y cierra la implementación con pruebas y revisión obligatorias. Usar durante cambios solicitados cuando las instrucciones vigentes autoricen ese respaldo, o con autorización puntual de commit, push y PR; no hacer merge ni sustituir excepciones documentales aplicables.
---

# Cerrar PR

Respalda temprano los cambios de código solicitados en una rama de trabajo y PR borrador; después
estabiliza esa misma rama y PR mediante verificación y revisión. Pide revisión a otro agente solo
cuando lo soliciten el usuario o las instrucciones aplicables. Esta skill no sustituye las reglas
del repositorio.

## Antes de ejecutar

Antes de usar cualquiera de los modos:

- Comprueba que la publicación esté autorizada: una instrucción permanente de respaldar cambios
  de código solicitados cubre sus commits, push y PR borrador dentro del alcance sin volver a
  preguntar. Prevalece una restricción más acotada. Respeta las excepciones documentales de push
  directo de las instrucciones aplicables del cliente o proyecto; no dupliques aquí su lista de
  repositorios. Esos procedimientos quedan fuera de este flujo y script de PR.
- Comprueba que la rama actual sea una rama de trabajo y no `develop`, `main` o `master`.
- Inspecciona el diff saliente completo, los archivos preparados y los commits sin publicar en
  busca de secretos, datos sensibles, cambios ajenos, archivos generados y atribuciones no deseadas.
  No los publiques. El script no sustituye esta inspección. Prepara solo los cambios del encargo
  y conserva los cambios locales ajenos.
- Identifica el repositorio remoto y la rama base de destino. No publiques si su identidad o el
  acceso son inciertos.

Elige un modo:

- **Respaldo temprano (`-Backup`):** publica el primer cambio de código dentro del alcance sin
  esperar pruebas o revisiones completas. Crea un PR borrador y repite el respaldo tras cambios
  o correcciones significativos, actualizando la misma rama y PR. Informa con precisión las
  comprobaciones fallidas, pendientes o sin ejecutar (`NO PROBADO` si no se verificaron); bloquean
  el cierre, pero no un respaldo seguro. No declares `-ReviewPassed` en este modo.
- **Cierre revisado (sin `-Backup`):** completa el ciclo obligatorio indicado abajo y pasa
  `-ReviewPassed` solo para el diff actual exacto. El script mantiene el PR en borrador; después
  de publicar, sigue el paso 7 para las comprobaciones remotas, las revisiones y cualquier cambio
  a listo necesario para activar CI.

Prepara `-PrBody` a partir de la plantilla de PR del repositorio (`.github/pull_request_template.md`
o equivalente) cuando exista y completa sus secciones obligatorias; CI puede rechazar un PR que
las omita.

Si un PR existente está listo, devuélvelo a borrador antes de otro push. Mantén el trabajo incompleto
hasta que pasen todas las pruebas y revisiones requeridas sin hallazgos ni revisiones pendientes.
Mantén también el PR en borrador, salvo que las reglas aplicables del repositorio requieran `ready`
para activar CI; en ese caso, marcarlo listo inicia la validación y no afirma que el trabajo esté
completo. Un commit nuevo invalida la evidencia previa de cierre para el último commit anterior.
La aprobación o el estado listo nunca autorizan merge: exige un pedido explícito de merge en la
sesión actual.

## Ciclo obligatorio de revisión local

Ejecuta este ciclo después de implementar y antes de declarar el cierre; no es un requisito previo
al respaldo temprano:

La evidencia del flujo que contiene este procedimiento satisface la misma condición cuando cubre
el contenido, base y entorno exactos. No repitas una comprobación o revisión sin cambios solo porque
ambas skills la mencionan; repite tras un cambio, fallo, incertidumbre o requisito explícito de
una ejecución nueva.

1. Ejecuta las pruebas, lint, compilación o verificación no destructiva equivalente pertinentes
   del repositorio.
2. Invoca `code-review` (`/revisa`) sobre el diff completo de la rama actual y sus cambios locales.
   La revisión se mantiene en solo lectura.
3. Valida cada hallazgo. Corrige de inmediato los hallazgos altos y medios válidos. Corrige los
   bajos solo cuando el cambio sea directo, seguro y siga dentro del alcance original.
4. Verifica cada corrección según la política de pruebas aplicable, reutilizando las pruebas
   pertinentes. Crear o ampliar casos debe respetar esa política; esta skill no otorga excepciones.
   Vuelve a ejecutar las comprobaciones afectadas.
5. Repite `/revisa` hasta que no queden hallazgos altos o medios válidos. Mantén visibles los demás
   hallazgos sin resolver; bloquean el cierre, mientras que el estado listo sigue la política de
   activación de CI del paso 7. Una ronda consiste en corregir y volver a ejecutar `/revisa`; la
   revisión inicial no cuenta y el conteo es por PR. Si después de tres rondas siguen
   apareciendo hallazgos altos o medios válidos, detén el ciclo sin declarar el cierre, mantén el
   PR en borrador e informa al usuario los hallazgos pendientes y por qué no converge.
6. Publica correcciones con `-Backup` cuando sea necesario. Invoca el modo revisado con
   `-ReviewPassed` solo después de que la verificación pertinente y la revisión local sean
   satisfactorias para el diff actual.
7. Registra el SHA del último commit verificado y confirma que el último commit publicado coincida
   con el código verificado y revisado localmente. Sigue la política de activación de CI del
   repositorio. Si CI requerida solo se ejecuta para PR listos, usa `gh pr ready` tras aprobar
   las comprobaciones locales para iniciarla, sin declarar el cierre. En otro caso, mantén el PR
   en borrador hasta que pasen las comprobaciones remotas y revisiones requeridas. Resuelve los
   fallos o hallazgos restantes y devuelve el PR a borrador antes de cualquier push correctivo.
   El cierre sigue requiriendo toda la evidencia aplicable al último commit actual.

El ciclo de corrección ya forma parte de completar la implementación autorizada; no te detengas
solo porque aparezca un hallazgo alto o medio válido. Detente y pregunta únicamente cuando una
corrección requiera una decisión material de producto, mayor alcance, una acción destructiva,
un acceso nuevo u otra autorización, o cuando se alcance el tope de rondas del paso 5.

## Revisión externa opcional

La revisión externa es independiente de este script y requiere autorización para ese PR.
Usa un subagente adecuado disponible en el entorno actual cuando el PR ya exista, respetando la
política de delegación del cliente, el revisor solicitado y el alcance de solo lectura o de
implementación. Otra revisión debe provenir de un agente o sesión distinto; si no está disponible,
informa la limitación sin sustituirla por una autorrevisión. Enviar trabajo fuera del entorno
actual requiere autorización explícita. No conviertas la revisión externa en requisito previo
para crear el PR.

## Ejecución

Respaldo temprano desde la raíz del repositorio, después de la inspección de seguridad de publicación:

```powershell
& <skill-root>\scripts\cerrar-pr.ps1 `
  -BaseBranch develop -CommitMessage "Start feature" -PrTitle "Implement feature" `
  -Pathspec @("src", "tests") -Backup -ConfirmedByUser
```

`-ConfirmedByUser` declara la autorización de publicación comprobada antes, incluida una
instrucción permanente aplicable; no exige una confirmación rutinaria nueva para cada respaldo
de código.

Cierre revisado, después del ciclo local obligatorio:

```powershell
$paths = @("src", "tests", "docs")
& <skill-root>\scripts\cerrar-pr.ps1 `
  -BaseBranch develop `
  -CommitMessage "Implement feature" `
  -PrTitle "Implement feature" `
  -Pathspec $paths `
  -ReviewPassed `
  -ConfirmedByUser
```

Usa `-VerificationCommand` solo para una comprobación pertinente que aún no se haya ejecutado
para este contenido exacto; no es un motivo para duplicar trabajo ya verificado.

Usa `-StageAll` solo cuando todos los archivos modificados pertenezcan a la implementación.
Prefiere `-Pathspec` para acotar los cambios.

Simulación:

```powershell
powershell -ExecutionPolicy Bypass -File <skill-root>\scripts\cerrar-pr.ps1 -DryRun -Backup -CommitMessage "..." -PrTitle "..."
```

## Comportamiento del script

`scripts/cerrar-pr.ps1`:

1. Lee el estado del repositorio y bloquea las ramas protegidas.
2. Exige autorización para publicar; el modo revisado también exige `-ReviewPassed` como
   declaración de quien lo invoca de que se aprobó el ciclo obligatorio de revisión local.
   `-Backup` nunca declara que el trabajo esté completo.
3. Muestra `git status --short`, `git diff --stat` y las estadísticas del diff preparado.
4. Ejecuta los comandos de verificación proporcionados después de rechazar comandos conocidos
   que inician servidores de desarrollo.
5. Prepara las rutas explícitas de `-Pathspec` o todos los archivos cuando se pasa `-StageAll`.
6. Crea un commit solo cuando hay cambios preparados y se proporciona `-CommitMessage`.
7. Comprueba si existe un PR y lo convierte a borrador antes del push; si no puede leer el estado
   del PR o falla la conversión, detiene el push. Hace push a `private` cuando está disponible
   y, en otro caso, a `origin`.
8. Crea un PR borrador hacia `-BaseBranch` o reutiliza el borrador existente. Nunca lo marca listo
   ni hace merge. Quien lo invoca sigue el paso 7 para comprobar el último commit remoto y el
   estado listo.

Comprobaciones de regresión sin conexión:
`powershell -NoProfile -File <skill-root>\scripts\test-cerrar-pr.ps1`.
Estas comprobaciones simulan Git y GitHub; no publican nada.

## Reglas de seguridad

- Exige `-ConfirmedByUser`, salvo que `-DryRun` se use únicamente para inspeccionar.
- Exige `-ReviewPassed` antes del cierre revisado; usa `-Backup` para respaldos de código incompleto.
- Nunca ejecutes `gh pr merge`, `git merge`, push forzado, rebase ni amend.
- Nunca hagas push directo a `develop`, `main` o `master`.
- Nunca inicies servidores de desarrollo. El script rechaza comandos habituales como `npm run dev`,
  `yarn dev`, `npm start` y `preview_start`.
- Ejecuta pruebas básicas en navegador solo con un pedido explícito; las pruebas automatizadas,
  lint y compilaciones pertinentes siguen siendo obligatorios. Informa las comprobaciones
  requeridas sin ejecutar en vez de afirmar que se hicieron.
- Mantén la revisión externa fuera de este script y exige autorización explícita antes de enviarla.
- El agente actual conserva la responsabilidad de revisión. La revisión externa aporta información;
  no autoriza merge.

## Instalación

La fuente única está en `skills/cerrar-pr` en este repositorio. Instala solo en las carpetas de
agentes autorizadas; el instalador también puede modificar otros agentes, así que no lo ejecutes
sin ese alcance explícito:

```powershell
powershell -ExecutionPolicy Bypass -File skills\cerrar-pr\scripts\install.ps1 -Force
```

Destinos:

- `%USERPROFILE%\.codex\skills\cerrar-pr`
- `%USERPROFILE%\.agents\skills\cerrar-pr`
- `%USERPROFILE%\.claude\skills\cerrar-pr`
