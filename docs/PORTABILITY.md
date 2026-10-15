# Portabilidad y comprobación

## Alcance

La biblioteca mantiene veinte skills propias: siete flujos principales y trece utilidades adicionales enumeradas en el [README](../README.md). Las skills especializadas de terceros se consultan mediante el [catálogo de referencias](SOURCES.md), que conserva fuentes y atribución sin distribuir sus recursos.

Las instrucciones narrativas y los metadatos descriptivos están en español. Los nombres de skills, rutas, identificadores, opciones de comandos, interfaces y ejemplos de código conservan su forma original. Los scripts y sus mensajes internos pueden contener inglés; su contenido ejecutable no se traduce. Esta edición local no implica una traducción oficial de los proyectos citados.

## Uso en otras aplicaciones

- Un agente con lectura de archivos puede consultar las instrucciones Markdown directamente. La aplicación determina qué herramientas están disponibles y el modelo debe interpretar correctamente el alcance; las instrucciones no imponen controles por sí mismas.
- La detección nativa de skills, los metadatos de `agents/` y los comandos como `/autodev` dependen del cliente. Consulta su documentación vigente antes de instalar.
- Copia la carpeta completa de cada skill necesaria para conservar scripts, metadatos y referencias. Una estructura de archivos coincidente no acredita compatibilidad de ejecución.
- Las plantillas `crear-spec`, `crear-release`, `daily`, `actualiza-todo`, `whatsapp-notify` y `mandalo-por-buzz` requieren configuración local. Mantén rutas, destinatarios, accesos y permisos fuera de esta biblioteca.

## Dependencias concretas

| Procedimiento | Requisitos y límites |
| --- | --- |
| Leer, diagnosticar o planificar | Acceso autorizado a los archivos o contenido adjunto; las acciones de verificación adicionales dependen del proyecto. |
| Revisar diferencias locales | `git`; para el procedimiento de PR también `gh` con la cuenta correcta y acceso al repositorio. |
| Publicar con `cerrar-pr` | `git`, `gh` y PowerShell compatible. El script invoca `powershell` internamente; tener solo `pwsh` no acredita compatibilidad. Requiere autorización de publicación. |
| Traspasar responsabilidad con `agent-handoff` | Acceso del agente de destino a la misma ruta del repositorio. Incluye variantes PowerShell y Bash; el inicio del agente requiere su CLI. |
| Delegar fases a Codex o Grok | CLI correspondiente, sesión válida, Python 3 o los lanzadores PowerShell y autorización para la delegación y sus acciones. No confundir con un traspaso total. |
| Analizar métricas | `km`; las métricas de historial también requieren Git. |
| Revisar privacidad chilena | Acceso a fuentes oficiales vigentes y evidencia autorizada del tratamiento. `proteccion-datos-chile` no requiere un plugin OWASP ni certifica cumplimiento jurídico integral; sin fuente o evidencia suficiente, la conclusión afectada queda `NO PROBADO`. |
| Revisar o restaurar Grok | Instalación local de Grok Build y PowerShell; la auditoría no verifica por completo la preferencia remota de datos. |
| Capturar bloqueos del equipo | Windows y PowerShell. No autoriza cerrar procesos ni reiniciar. |
| Actualizar agentes | Windows, las herramientas seleccionadas y sus gestores de paquetes; requiere `revisa-grok`. `-CheckOnly` puede usar red y refrescar fuentes de paquetes, por lo que no es una simulación sin efectos. |
| Enviar por WhatsApp o Buzz | `wacli` con sesión vinculada o un script auxiliar de Buzz configurado por el usuario, respectivamente. Cada envío requiere autorización; el auxiliar de Buzz no está incluido. |
| Revisión independiente obligatoria | Otro agente o sesión autorizado y distinto del implementador. No se puede sustituir por una autorrevisión. |

No ejecutes actualizadores, instalaciones, servidores, mensajes ni despliegues solo para leer o instalar instrucciones. Si falta una dependencia obligatoria, informa el paso bloqueado y acuerda cualquier alternativa antes de cambiar el procedimiento.

## Qué demuestra una comprobación

La revisión estructural comprueba metadatos, rutas y enlaces locales. La comparación con una base permite comprobar que una traducción conservó los bloques de código, los identificadores y los archivos ejecutables. El análisis sintáctico de un script no demuestra que sus integraciones funcionen.

Las pruebas deterministas existentes pueden ejecutarse por separado cuando sea seguro y esté dentro del alcance. Cada resultado operativo necesita evidencia de su ejecución concreta: las cuentas, integraciones y combinaciones de modelo, cliente y plataforma no comprobadas quedan como **NO PROBADO**. No atribuyas a este catálogo una validación completa de todos sus procedimientos.

No publiques secretos, memorias privadas, datos de clientes ni configuración de una máquina. La limpieza de la fuente actual no borra por sí sola copias históricas, clones, cachés o referencias de PR conservados por otros servicios.
