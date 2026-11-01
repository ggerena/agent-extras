---
name: actualiza-todo
description: Actualiza y verifica en Windows Codex, Claude Code, OpenCode, Grok Build, sus adaptadores ACP y sus aplicaciones de escritorio. Usar ante un pedido de actualizar los agentes.
---

# Actualizar agentes en Windows

Exportación portable adaptada: requiere configurar las rutas y el alcance locales; no es una copia idéntica de una instalación personal. Requiere `revisa-grok` con sus scripts de reparación y auditoría. No instala esa dependencia automáticamente.

## Configuración local

- Confirmar qué herramientas ya instaladas se van a actualizar y la autorización para hacerlo. El script espera Codex, Claude Code, OpenCode, Grok Build, npm y winget; no usarlo para un alcance más estrecho sin ajustar la selección.
- `-GrokRepairScript` y `-GrokAuditScript` apuntan por defecto a `revisa-grok` bajo `.agents/skills` del perfil de Windows; pasarlos explícitamente si la instalación difiere.
- Consultar instrucciones de los productos cuando estén disponibles (por ejemplo `openai-docs` para Codex); para Grok, aplicar `revisa-grok`. No reinstalar herramientas ausentes o excluidas del encargo.

## Flujo

1. Leer instrucciones aplicables, comprobar destinos y mantener un plan visible.
2. Ejecutar `scripts/actualiza-todo.ps1` solo tras autorizar la actualización completa. `-CheckOnly` corresponde a un pedido de comprobar: no es una simulación sin efectos ni sin red; consulta servicios y puede refrescar fuentes de paquetes.
3. Actualizar por canales estables, sin bajar versiones, borrar datos, cerrar aplicaciones ni iniciar sesiones de agentes. En modo actualización se restauran los controles locales de Grok después de actualizarlo y luego se auditan.
4. Ante un bloqueo, resolver solo lo autorizado: no descartar cambios, borrar volúmenes, hacer push ni iniciar Grok. Informar fallos de reemplazo por archivos en uso sin cerrar procesos.
5. Comprobar versiones finales, adaptadores ACP y auditoría de Grok en `OK`, con cola vacía y protecciones activas. No comprobar catálogos de modelos ni proveedores. No revelar claves, sesiones ni solicitudes.

## Límites

- No crear monitores ni tareas programadas.
- Grok estable por defecto; no pasar a alpha sin pedido. La versión nueva de una aplicación abierta se usa al reabrirla; no cerrar procesos para forzarla.
- No bajar una versión aunque `latest` sea anterior. Conservar la versión mayor de OpenCode; una migración mayor requiere autorización propia.
- Usar winget por producto, nunca `upgrade --all`. No sustituir el producto elegido por otra edición ni desinstalar copias anteriores sin pedido.
- El script no modifica `/privacy` ni prueba por completo la preferencia remota de datos de Grok. No usar la clave obsoleta `trace_uploads`; la vigente es `trace_upload`.
- No ampliar la operación a otros productos o ambientes.

Los identificadores de paquetes y servicios públicos describen productos, no una instalación privada.
