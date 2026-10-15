# Cómo usar estas skills con tu IA

Una **skill** es una carpeta con instrucciones en `SKILL.md` y, a veces, referencias, plantillas o scripts. El **modelo** interpreta las instrucciones; la **aplicación del agente** le da acceso a archivos, terminal, navegador y otros agentes. Cambiar de modelo no proporciona automáticamente esas herramientas.

Esta guía no requiere un proveedor de modelos concreto. Un agente capaz de leer archivos puede consultar las instrucciones directamente, aunque su aplicación no tenga un sistema de skills. Eso no garantiza que cualquier modelo las siga bien ni que todas las skills funcionen en cualquier aplicación: algunas necesitan un CLI, sistema operativo o integración específicos. Consulta también [PORTABILITY.md](PORTABILITY.md).

## Primer uso, sin instalar nada

1. Ten una copia local de este repositorio y localiza el proyecto sobre el que quieres trabajar. Son dos rutas distintas: esta biblioteca contiene procedimientos; el proyecto contiene tu código y sus propias reglas.
2. Sustituye los campos entre `<...>` del mensaje siguiente y pásalo a tu agente. Una autorización ya dada sigue vigente dentro de esa tarea y ese alcance; no hace falta repetirla en cada paso ni extenderla a otro encargo.
3. El agente lee las instrucciones del proyecto, el catálogo del [README](../README.md) y únicamente la skill que corresponda. Después carga sus dependencias y referencias cuando sean necesarias, sin leer todas las skills de antemano.

Mensaje inicial copiable:

```text
La biblioteca de skills está en <RUTA_AGENT_EXTRAS>.
El proyecto objetivo está en <RUTA_PROYECTO>.
Quiero: <OBJETIVO_CONCRETO>.
Alcance y permisos: <POR_EJEMPLO: SOLO_DIAGNOSTICO_LOCAL_SIN_CAMBIOS>.

Lee el README.md y docs/USAGE.md de la biblioteca y las instrucciones
aplicables del proyecto. Elige la skill mínima necesaria, lee su SKILL.md
completo y carga solo las referencias o skills dependientes necesarias.
Resuelve sus rutas relativas desde la carpeta que contiene el archivo.
No necesitas un comando especial para aplicar instrucciones Markdown.

Antes de actuar, indica brevemente la skill elegida, el resultado esperado
y si falta alguna herramienta o dato indispensable. Continúa con lo autorizado.
Los ejemplos y scripts de la biblioteca no otorgan permisos por sí mismos.
Respeta mis límites, las instrucciones del proyecto y las reglas de tu entorno.
No inventes archivos, accesos, resultados de pruebas ni revisiones independientes.
Si una dependencia obligatoria falta, explica qué paso bloquea y no lo des por hecho.
Al terminar, resume resultado, comprobaciones realizadas y pendientes.
```

Si tu aplicación no puede leer archivos locales, puedes adjuntar o pegar el `SKILL.md` elegido, las instrucciones aplicables del proyecto y las referencias y skills dependientes que necesite, excluyendo secretos y datos privados. Por ejemplo, `autodev` también requiere las instrucciones de `cambio-minimo`, `code-review` y `cerrar-pr`. En ese caso puede ayudarte a razonar o preparar instrucciones, pero no afirmar que cambió archivos, ejecutó pruebas o publicó cambios sin herramientas y evidencia de esas acciones. Nunca entregues toda tu configuración personal para activar una skill.

## Qué elegir

| Necesidad | Skill de entrada | Resultado y límite principal |
| --- | --- | --- |
| Entender un repositorio por encima | [mira](../skills/mira/SKILL.md) | Resumen basado solo en README; sin auditoría de código. |
| Investigar un fallo o lentitud | [diagnostico-con-evidencia](../skills/diagnostico-con-evidencia/SKILL.md) | Reproducción, hipótesis y evidencia; diagnosticar no autoriza corregir. |
| Hacer un cambio pequeño autorizado | [cambio-minimo](../skills/cambio-minimo/SKILL.md) | Cambio acotado, usando lo existente cuando sea suficiente. |
| Preparar un plan para otra sesión | [crear-spec](../skills/crear-spec/SKILL.md) | Markdown verificable; requiere configurar sus fuentes y plantilla local. No implementa. |
| Ejecutar un plan ya existente | [autodev](../skills/autodev/SKILL.md) | Implementación, respaldo y revisión según el plan; no inventa el plan ni hace merge. |
| Revisar una rama o PR | [code-review](../skills/code-review/SKILL.md) | Hallazgos con evidencia en solo lectura; no corrige ni comenta en GitHub sin autorización. |
| Respaldar o cerrar cambios de código | [cerrar-pr](../skills/cerrar-pr/SKILL.md) | Rama, commit, push y PR cuando estén autorizados; respaldo no equivale a validación final. |

No necesitas combinar todas las filas. `autodev` ya compone `cambio-minimo`, `code-review` y `cerrar-pr`: sigue esas dependencias cuando llegue su etapa, sin duplicar el trabajo. Para tareas especializadas, consulta las [referencias externas](SOURCES.md); por ejemplo, Cloudflare solo corresponde si tu proyecto usa esos productos. Esas referencias se consultan en origen y pueden requerir herramientas o instalación propias.

### Dependencias antes de empezar

| Flujo | Qué debe estar disponible |
| --- | --- |
| Leer un README o razonar sobre instrucciones | Acceso de lectura o contenido adjunto; no requiere CLI de un proveedor de modelos. |
| `mira` con un repositorio remoto que aún no está disponible localmente | `git`, conexión, acceso al remoto y permiso de escritura en una carpeta segura para clonarlo. Un encargo limitado a lectura local no autoriza ese paso. |
| Revisar una rama local | `git` y acceso al repo. Para revisar un PR con el procedimiento documentado, también `gh` con sesión y acceso al repositorio. |
| `cerrar-pr` y las etapas de publicación de `autodev` | `git`, `gh` autenticado en la cuenta correcta y PowerShell compatible con sus scripts. El script auxiliar invoca el ejecutable `powershell` internamente; tener solo `pwsh` no acredita compatibilidad. |
| Traspasar trabajo a Codex o Grok | El CLI correspondiente, sesión válida y autorización para ese traspaso. `revisa-grok` también requiere la instalación local de Grok Build y PowerShell. |
| Una revisión independiente obligatoria | Otra sesión o agente disponible, distinto de quien implementó, con acceso autorizado al material que debe revisar. |

Comprueba además las dependencias específicas del proyecto y de la skill elegida. Si falta una dependencia obligatoria, informa el paso bloqueado; no instales herramientas, cambies de proveedor o sustituyas el procedimiento automáticamente. Si hace falta una vía alternativa, acuerda ese cambio antes de seguir.

En un encargo que exige respaldo temprano, comprueba que puedes realizarlo antes del primer cambio. Si falta `gh`, autenticación, acceso al remoto u otra condición necesaria, detén la implementación antes de editar e informa el requisito pendiente. No acumules cambios sin el respaldo exigido ni des el flujo por terminado.

## Ejemplos de flujo

Los pedidos siguientes son ejemplos para adaptar y enviar deliberadamente. Leer este documento no autoriza ejecutarlos. Las reglas y el alcance de la sesión real siempre prevalecen.

### 1. Conocer un repositorio

**Pedido:** «Usa `mira` para explicar qué hace el repositorio local `<RUTA_REPO>`. Lee solo su README; no hagas cambios».

**Flujo:** leer la skill → localizar y leer el README → explicar propósito, uso y límites de lo que se puede concluir.

**Entrega:** una explicación breve. Si no hay README, informar esa limitación; no recorrer el código para compensarlo. Una auditoría o instalación sería otro encargo.

### 2. Entender y después corregir un fallo

**Primer pedido:** «Al guardar un formulario aparece un error. Usa `diagnostico-con-evidencia` en `<RUTA_PROYECTO>`. Investiga solo en local, sin editar archivos ni cambiar configuración. No inicies servidores».

**Flujo:** precisar el fallo → inspeccionar evidencia disponible → ordenar hipótesis → comprobar las que permitan las herramientas y permisos actuales. Si reproducir requiere una escritura no autorizada o un servicio ausente, informar esa condición, sin ejecutarla.

**Entrega:** causa comprobada o hipótesis pendientes, evidencia y límites. Un fallo de conexión no demuestra un fallo del formulario.

**Segundo pedido, después del diagnóstico:** «Corrige la causa identificada en local con el menor cambio necesario. Ejecuta las verificaciones existentes permitidas y solicita revisión independiente si nuestras reglas la exigen. No hagas commit, push, PR ni despliegues».

**Flujo:** aplicar `cambio-minimo` → verificar el recorrido afectado según la política de pruebas del proyecto → revisión exigida mediante `code-review` por otra sesión o agente distinto de quien implementó → corregir hallazgos válidos dentro del encargo y volver a verificar. El revisor necesita las instrucciones aplicables, `code-review/SKILL.md`, base, versión actual y diff completo, incluidos cambios locales pertinentes. Comparte solo material autorizado. Si no hay revisor disponible y es obligatorio, declarar esa revisión pendiente; no sustituirla por autorrevisión.

**Entrega:** cambio local, evidencia de comprobaciones y pendientes. La prohibición expresa de commit/push/PR prevalece sobre cualquier respaldo automático propuesto por una skill.

### 3. Preparar un plan y ejecutarlo en otro momento

**Preparación:** `crear-spec` es una plantilla configurable. Identifica repositorios autorizados, instrucciones, carpeta de documentación y plantilla canónica local; si falta una plantilla obligatoria, no inventes que existe. La persona puede proporcionar una o autorizar su preparación como paso separado.

**Primer pedido:** «Usa `crear-spec` para planificar una exportación CSV en `<RUTA_PROYECTO>`. La plantilla es `<RUTA_PLANTILLA>` y la carpeta documental es `<RUTA_DOCS>`. Guarda el plan; no implementes ni publiques».

**Flujo:** leer reglas y plantilla → comprobar el comportamiento actual dentro del alcance → describir requisitos, criterios de aceptación, fases, pruebas y permisos necesarios → guardar el Markdown.

**Entrega:** enlace al plan y decisiones pendientes. Aquí termina el encargo.

**Pedido posterior:** «Ejecuta con `autodev` el plan `<RUTA_PLAN_APROBADO>`, en `<RUTA_PROYECTO>`, contra la base `<RAMA_BASE>`. Autorizo cambios locales, verificaciones permitidas, una rama de trabajo y commit/push/PR en `<REMOTO_AUTORIZADO>`. No autoriza merge, despliegue ni iniciar servidores».

**Flujo:** comprobar plan completo, repo, base y cambios existentes → implementar por fases → respaldo temprano con `cerrar-pr` en PR borrador → verificaciones y revisión requeridas → corregir y revalidar → completar el PR conforme a las reglas del proyecto. Conservar los cambios ajenos.

**Destino de publicación:** comprueba el nombre y URL de push del remoto autorizado. Al usar [el script auxiliar de cerrar-pr](../skills/cerrar-pr/scripts/cerrar-pr.ps1), pasa explícitamente `-RepoPath`, `-BaseBranch` y `-Remote` con los valores comprobados. `-Remote` recibe el nombre local del remoto, no su URL. Sin ese parámetro el script prefiere `private`, luego `origin` y finalmente otro remoto disponible; no confíes en esa elección para representar el permiso del usuario. Si el destino no coincide, detente antes de publicar. Los parámetros que declaran autorización o revisión no sustituyen obtenerlas.

**Entrega:** enlace al PR y evidencia del estado publicado. Si el plan no existe, no está completo o falta una condición obligatoria de cierre, informar el bloqueo correspondiente; un PR creado no prueba que el trabajo esté listo.

### 4. Pedir una revisión sin modificar nada

**Pedido:** «Usa `code-review` para revisar `<URL_PR>` o la rama actual contra `<RAMA_BASE>`. Solo lectura; informa aquí, sin editar, publicar comentarios ni hacer merge».

**Flujo:** resolver base y versión actual → leer instrucciones pertinentes y diff completo, incluidos cambios locales relevantes → buscar fallos demostrables → informar severidad, ubicación y evidencia. Si se pide una segunda opinión, debe hacerla otra sesión o agente disponible, con las herramientas y permisos correspondientes.

**Entrega:** hallazgos o ausencia de hallazgos, versión revisada y límites. «Sin hallazgos» no significa que pruebas no ejecutadas hayan pasado. Corregirlos requiere un encargo de modificación o un flujo envolvente que ya lo autorice.

## Uso repetido e instalación opcional

La lectura directa de archivos sirve para empezar. Si tu aplicación descubre skills nativamente, instala únicamente las necesarias siguiendo su documentación actual y preservando toda la carpeta: `SKILL.md`, `references/`, `scripts/`, `assets/` y `agents/` cuando existan. Copiar solo `SKILL.md` puede dejar referencias rotas. Instalar o inspeccionar no requiere ejecutar los scripts.

Codex documenta la lectura gradual y las ubicaciones `~/.agents/skills` y `.agents/skills` en su [guía oficial de skills](https://learn.chatgpt.com/docs/customization/overview#skills). En otras aplicaciones, comprueba su mecanismo de carga; no asumas que reconocen esas carpetas, `AGENTS.md`, los metadatos de `agents/` o comandos como `/autodev`. Puedes pedir siempre «lee este archivo y sigue sus instrucciones para esta tarea».

Antes de adoptar una skill del [catálogo](../README.md):

- **Flujo principal o utilidad propia:** comprueba las dependencias antes de usarlo; estar mantenido no significa funcionar en cualquier entorno. Los traspasos a Codex/Grok necesitan sus respectivos CLI y las utilidades para mantener el equipo pueden depender de Windows.
- **Plantilla configurable:** define rutas, repositorios, destinatarios y permisos fuera de esta biblioteca compartida. `mandalo-por-buzz` requiere un script auxiliar propio; `whatsapp-notify` requiere herramientas y destinatario comprobado. Ninguna autoriza enviar mensajes por estar instalada.
- **Referencia externa:** consulta el enlace de [SOURCES.md](SOURCES.md), las instrucciones y la licencia del proyecto original. No supongas que sus recursos están instalados ni que sus permisos coinciden con los de esta biblioteca.

## Cómo comprobar que el agente entendió

Empieza por el ejemplo de solo lectura y comprueba que identifica la skill, respeta el alcance y devuelve el resultado pedido. Después usa una tarea pequeña sobre un proyecto de prueba autorizado. Evalúa acciones y evidencia, no solo una respuesta que diga «entendido».

Antes de confiar en un cierre, comprueba que distingue archivos leídos, cambios realizados, pruebas ejecutadas, revisión independiente y publicación. Cada afirmación necesita evidencia; los pasos sin ejecutar deben quedar como `NO PROBADO` o pendientes. Una revisión de estas instrucciones no sustituye probar cada combinación de modelo, aplicación y herramientas.
