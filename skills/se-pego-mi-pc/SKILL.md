---
name: se-pego-mi-pc
description: Captura evidencia local breve y de bajo impacto cuando Windows, el PC o una aplicacion se congela, se pega o consume CPU anormalmente. Usar tambien ante frases como "se pego mi PC", "el PC esta al 100%" o "esta app quedo colgada"; no usar para monitoreo continuo ni para matar procesos sin pedido explicito.
---

# Se pego mi PC

Toma primero una muestra de solo lectura mientras el sintoma sigue presente. La prioridad es conservar evidencia sin agravar la saturacion.

## Captura inmediata

1. En Windows, ejecuta `scripts/capture-pc-snapshot.ps1` con PowerShell. Usa la muestra predeterminada de 3 segundos; no la alargues mientras el equipo responde mal.
2. Informa de inmediato la ruta del JSON creado y los procesos con mayor CPU y memoria.
3. Correlaciona la hora con eventos recientes de Windows y, solo para el proceso dominante, con sus logs existentes. No recorras discos completos, no descargues herramientas y no abras interfaces pesadas durante el incidente.
4. Distingue hechos, inferencias y `NO PROBADO`. Una muestra posterior a que el sintoma termino no demuestra que proceso causo el episodio.

## Recuperacion

- La invocacion autoriza la captura local y su archivo diagnostico, no cerrar procesos, reiniciar, resetear datos ni cambiar configuracion.
- Si el equipo sigue utilizable, presenta primero la evidencia y pide confirmacion antes de una accion destructiva o que pueda perder trabajo.
- Si el equipo esta inutilizable, prioriza que el usuario lo recupere y explica que la captura puede quedar incompleta.
- No impongas umbrales universales de CPU. Compara la muestra con el numero de procesadores logicos y el estado observable.

## Entrega

Resume la hora, duracion de la muestra, proceso o procesos dominantes, memoria disponible, eventos correlacionados, limites de la evidencia y siguiente accion segura. No copies lineas de comando ni datos potencialmente sensibles al chat.
