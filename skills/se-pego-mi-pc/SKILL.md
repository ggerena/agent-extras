---
name: se-pego-mi-pc
description: Captura evidencia local breve y de bajo impacto cuando Windows, el PC o una aplicación se congela, se pega o consume CPU anormalmente. Usar también ante frases como "se pegó mi PC", "el PC está al 100%" o "esta aplicación quedó colgada"; no usar para seguimiento continuo ni para terminar procesos sin pedido explícito.
---

# Se pegó mi PC

Toma primero una muestra de solo lectura mientras el síntoma sigue presente. La prioridad es conservar evidencia sin agravar la saturación.

## Captura inmediata

1. En Windows, ejecuta `scripts/capture-pc-snapshot.ps1` con PowerShell. Usa la muestra predeterminada de 3 segundos; no la alargues mientras el equipo responde mal.
2. Informa de inmediato la ruta del JSON creado y los procesos con mayor CPU y memoria.
3. Correlaciona la hora con eventos recientes de Windows y, solo para el proceso dominante, con sus logs existentes. No recorras discos completos, no descargues herramientas y no abras interfaces pesadas durante el incidente.
4. Distingue hechos, inferencias y `NO PROBADO`. Una muestra posterior a que el síntoma terminó no demuestra qué proceso causó el episodio.

## Recuperación

- La invocación autoriza la captura local y su archivo diagnóstico, no cerrar procesos, reiniciar, resetear datos ni cambiar configuración.
- Si el equipo sigue utilizable, presenta primero la evidencia y pide confirmación antes de una acción destructiva o que pueda perder trabajo.
- Si el equipo está inutilizable, prioriza que el usuario lo recupere y explica que la captura puede quedar incompleta.
- No impongas umbrales universales de CPU. Compara la muestra con el número de procesadores lógicos y el estado observable.

## Entrega

Resume la hora, duración de la muestra, proceso o procesos dominantes, memoria disponible, eventos correlacionados, límites de la evidencia y siguiente acción segura. No copies líneas de comando ni datos potencialmente sensibles al chat.
