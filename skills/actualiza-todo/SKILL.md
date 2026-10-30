---
name: actualiza-todo
description: Actualiza y verifica en Windows Codex, Claude Code, OpenCode, Grok Build, sus adaptadores ACP y sus aplicaciones de escritorio. Usar ante un pedido de actualizar los agentes. Buzz queda excluido salvo pedido expreso para esa instalación.
---

# Actualizar agentes en Windows

Exportación portable adaptada: requiere configurar las rutas y el alcance locales; no es una copia idéntica de una instalación personal. Requiere `revisa-grok` con sus scripts de reparación y auditoría. No instala esa dependencia automáticamente.

## Configuración local

- Confirmar qué herramientas ya instaladas se van a actualizar y la autorización para hacerlo. El script espera Codex, Claude Code, OpenCode, Grok Build, npm y winget; no usarlo para un alcance más estrecho sin ajustar la selección.
- `-GrokRepairScript` y `-GrokAuditScript` apuntan por defecto a `revisa-grok` bajo `.agents/skills` del perfil de Windows; pasarlos explícitamente si la instalación difiere.
- Buzz requiere pedido específico, `-IncludeBuzz` y comprobar `-BuzzRepo` y `-BuzzComposeProject` contra la instalación real. Sus valores genéricos predeterminados no acreditan que exista ni que sea el destino autorizado. Con Buzz se requieren también gh, git y Docker.
- Consultar instrucciones de los productos cuando estén disponibles; para Grok, aplicar `revisa-grok`. No reinstalar herramientas ausentes o excluidas del encargo.

## Flujo

1. Leer instrucciones aplicables, comprobar destinos y mantener un plan visible.
2. Ejecutar `scripts/actualiza-todo.ps1` solo tras autorizar la actualización completa. Sin `-IncludeBuzz`, no consulta ni modifica Buzz, su repositorio o Docker. `-CheckOnly` corresponde a un pedido de comprobar: no es una simulación sin efectos ni sin red; consulta servicios y puede refrescar fuentes de paquetes.
3. Actualizar por canales estables, sin bajar versiones, borrar datos, cerrar aplicaciones ni iniciar sesiones de agentes. En modo actualización se restauran los controles locales de Grok después de actualizarlo y luego se auditan.
4. Ante un bloqueo, resolver solo lo autorizado: no descartar cambios, borrar volúmenes, hacer push ni iniciar Grok. Informar fallos de reemplazo por archivos en uso sin cerrar procesos.
5. Comprobar versiones finales, adaptadores ACP y auditoría de Grok. No comprobar catálogos de modelos ni proveedores. No revelar claves, sesiones ni solicitudes.
6. Si se incluyó Buzz, comprobar versión Desktop, revisión del relay y salud de sus dependencias. Distinguir resultados verificados y `NO PROBADO`.

## Límites

- Buzz siempre queda fuera de una actualización general. Para incluirlo, aplicar primero la comprobación siguiente; no crear monitores o tareas programadas.
- Grok estable por defecto; no pasar a alpha sin pedido. La versión nueva de una aplicación abierta se usa al reabrirla; no cerrar procesos para forzarla.
- No bajar una versión aunque `latest` sea anterior. Conservar la versión mayor de OpenCode; una migración mayor requiere autorización propia.
- Usar winget por producto, nunca `upgrade --all`. No sustituir el producto elegido por otra edición ni desinstalar copias anteriores sin pedido.
- El script no modifica `/privacy` ni prueba por completo la preferencia remota de datos de Grok. No usar la clave obsoleta `trace_uploads`; la vigente es `trace_upload`.
- Conservar volúmenes Docker y cambios locales; actualización Git solo por avance directo. Iniciar Docker oculto únicamente si el relay autorizado lo necesita. No ampliar la operación a otros conjuntos o ambientes.

## Comprobación previa de Buzz

Consultar la versión oficial de `block/buzz`, fecha, notas, issues abiertos/cerrados y correcciones aplicables a Windows: WebView2, carga de archivos, arranque, cierres, conexión y pérdida de datos. Leer evidencia y comentarios pertinentes, no solo títulos.

- Esperar al menos siete días completos desde la publicación del candidato; cada versión correctiva inicia su plazo. Es un margen conservador, no garantía de estabilidad. Acortarlo requiere petición explícita después de informar el resultado.
- Conservar la versión instalada si hay fallos graves aplicables pendientes o no se puede verificar fecha/reportes. Una corrección debe estar incluida en el instalador candidato; un PR integrado no basta.
- Antes de incluir Buzz, informar versión instalada/candidata, antigüedad, evidencia y decisión. Descargar solo el instalador oficial y comprobar SHA-256.
- Evaluar por separado la revisión candidata del relay: la antigüedad del Desktop no valida una imagen de rama. Si falta evidencia del relay, omitir `-IncludeBuzz`, porque ese modo también lo actualiza.

El script no interpreta reportes ni aplica el plazo: esos controles se completan antes de ejecutarlo. Sus identificadores de paquetes y servicios públicos describen productos, no una instalación privada.
