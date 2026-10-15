# agent-extras

Skills reutilizables para conocer un repositorio, investigar un fallo, planificar, implementar y revisar cambios con un agente de IA, con utilidades adicionales para tareas autorizadas.

**Empieza aquí:** [cómo usar las skills, primer mensaje copiable y ejemplos de flujo](docs/USAGE.md). Puedes leerlas sin instalarlas; algunas etapas requieren herramientas concretas y permisos explícitos.

## Siete flujos principales

| Necesidad | Skill | Límite principal |
| --- | --- | --- |
| Conocer un repositorio | [mira](skills/mira/SKILL.md) | Lee solo el README y explica qué hace. |
| Encontrar la causa de un fallo | [diagnostico-con-evidencia](skills/diagnostico-con-evidencia/SKILL.md) | Reúne evidencia; diagnosticar no autoriza corregir. |
| Implementar un cambio acotado | [cambio-minimo](skills/cambio-minimo/SKILL.md) | Reutiliza lo existente y corrige en la capa responsable. |
| Preparar un plan | [crear-spec](skills/crear-spec/SKILL.md) | Guarda una especificación verificable; no la implementa. |
| Ejecutar un plan existente | [autodev](skills/autodev/SKILL.md) | Implementa, respalda y revisa; no hace merge ni despliega. |
| Revisar código | [code-review](skills/code-review/SKILL.md) | Revisa una rama o PR en solo lectura. |
| Respaldar y cerrar una implementación | [cerrar-pr](skills/cerrar-pr/SKILL.md) | Publica cuando esté autorizado y exige pruebas y revisión para cerrar. |

`autodev` utiliza `cambio-minimo`, `code-review` y `cerrar-pr` durante sus etapas. Las demás skills se pueden aplicar por separado. No necesitas leerlas todas para empezar.

## Utilidades adicionales

| Necesidad | Skill |
| --- | --- |
| Traspasar la responsabilidad de un trabajo a otro agente | [agent-handoff](skills/agent-handoff/SKILL.md) |
| Delegar una fase y conservar la coordinación | [handoff-implementation-to-codex](skills/handoff-implementation-to-codex/SKILL.md), [handoff-implementation-to-grok](skills/handoff-implementation-to-grok/SKILL.md) |
| Medir complejidad y salud del código | [km-analyze](skills/km-analyze/SKILL.md) |
| Preparar o revisar una versión | [crear-release](skills/crear-release/SKILL.md) |
| Resumir actividad comprobada | [daily](skills/daily/SKILL.md) |
| Analizar dificultades en sesiones con agentes | [retrospectiva-agentes](skills/retrospectiva-agentes/SKILL.md) |
| Actualizar agentes en Windows | [actualiza-todo](skills/actualiza-todo/SKILL.md) |
| Auditar o restaurar controles locales de Grok | [revisa-grok](skills/revisa-grok/SKILL.md) |
| Capturar evidencia de un bloqueo de Windows | [se-pego-mi-pc](skills/se-pego-mi-pc/SKILL.md) |
| Enviar un mensaje autorizado por WhatsApp | [whatsapp-notify](skills/whatsapp-notify/SKILL.md) |
| Encargar trabajo por Buzz con autorización específica | [mandalo-por-buzz](skills/mandalo-por-buzz/SKILL.md) |

## Uso y requisitos

Lee la [guía de uso](docs/USAGE.md) y las instrucciones del proyecto objetivo. Si tu aplicación puede leer archivos, puede consultar un `SKILL.md` directamente; no necesita reconocer un comando especial. Comprueba las [dependencias y límites de portabilidad](docs/PORTABILITY.md) antes de instalar o ejecutar recursos.

Las fuentes editables están en `skills/`. Conserva toda la carpeta de la skill, incluidos sus metadatos y scripts cuando existan. `crear-spec` y las plantillas operativas requieren definir rutas, repositorios, permisos u otros datos locales. `cerrar-pr` incluye scripts PowerShell y requiere `git` y `gh` para publicar. Las delegaciones necesitan el CLI del agente de destino; las utilidades de Windows tienen dependencias propias.

Instala únicamente lo necesario y en los destinos autorizados. La presencia de una skill aquí no significa que esté instalada ni autoriza ejecutar sus scripts. Las reglas del usuario y del proyecto determinan el alcance, las pruebas, la publicación y cualquier revisión independiente.

## Referencias externas

El [catálogo de fuentes e influencias](docs/SOURCES.md) enlaza bibliotecas públicas para trabajos especializados. Consulta sus instrucciones, herramientas y licencias en origen; son referencias externas al catálogo mantenido aquí.

Mantén memorias privadas, reglas personales, datos de clientes, contactos, credenciales, código de aplicaciones, configuración de máquina, archivos generados y respaldos locales fuera de esta biblioteca.
