---
name: revisa-grok
description: Audita de forma local la privacidad y las subidas de Grok Build, y restaura sus bloqueos cuando el usuario lo autoriza. Usar cuando el usuario diga "revisa Grok", "audita Grok", "corrige Grok", pregunte si Grok volvió a habilitar la subida de código, quiera comprobar la cola o los registros de Grok, o necesite verificar o restaurar sus bloqueos después de una actualización.
---

# Revisa Grok

Comprobar el estado local de Grok Build sin iniciar una sesión ni interceptar tráfico.

## Procedimiento

1. Si el usuario pidió corregir o restaurar la protección, ejecutar primero `scripts/asegura-grok.ps1`. El script conserva el resto de `config.toml`, crea una copia de respaldo solo si cambia algo y no inicia Grok.
2. Ejecutar `scripts/revisa-grok.ps1` con PowerShell.
3. Confirmar que la capa efectiva mantiene `disable_codebase_upload=true`, `telemetry=false`, `trace_upload=false`, `mixpanel_enabled=false` y `otel_enabled=false`.
4. Tratar `ALERTA` como riesgo actual y `INCIERTO` como falta de evidencia suficiente.
5. Explicar el resultado en español simple, diferenciando:
   - protección local activa;
   - cola pendiente;
   - decisión de subida registrada;
   - antecedentes históricos que no prueban una entrega completa;
   - privacidad remota, que no puede verificarse por completo desde archivos locales.
6. Si aparece una alerta, recomendar pausar Grok en repositorios sensibles. No modificar configuración, borrar archivos, ejecutar `/privacy` ni cerrar procesos sin autorización explícita.

## Reglas de seguridad

- No iniciar Grok ni enviar prompts durante la auditoría.
- No instalar ni ejecutar proxies, certificados raíz o monitores de terceros.
- No mostrar contenido de sesiones, código, credenciales, rutas de archivos sensibles ni cuerpos de solicitudes.
- No interpretar `uploads_enabled=true` como prueba de recepción completa; describirlo como subida permitida o posible.
- No usar `trace_uploads`: la documentación actual solo reconoce `trace_upload`.
- `/privacy` controla por separado el uso, retención y entrenamiento con datos de programación. La reparación local no puede cambiar esa preferencia remota.
- Recordar que la ausencia de eventos solo cubre la ventana conservada en `unified.jsonl`.
- Para monitoreo continuo o programado, pedir autorización específica; esta skill realiza una revisión bajo demanda.

## Resultado esperado

Informar primero `OK`, `ALERTA` o `INCIERTO`, seguido por los hallazgos esenciales y la acción recomendada. Si el usuario pidió únicamente revisar, no hacer cambios.
