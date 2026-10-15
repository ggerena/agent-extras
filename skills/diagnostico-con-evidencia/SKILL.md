---
name: diagnostico-con-evidencia
description: Diagnostica errores, fallos intermitentes o regresiones de rendimiento mediante una reproducción verificable, hipótesis ordenadas e instrumentación antes de corregir. Usar cuando se pida diagnosticar, depurar, encontrar la causa o explicar por qué algo falla o está lento; no usar para revisar un diff sin ejecutar, seguir una prueba básica predefinida, restaurar de urgencia un servicio ni medir la carga de una página web con métricas, que corresponde a web-perf como referencia externa.
---

# Diagnóstico con evidencia

**Cuál corresponde:** esta skill encuentra la causa cuando no se sabe por qué falla. Si la causa ya está identificada y solo hay que corregirla, corresponde `cambio-minimo`. Pueden encadenarse: diagnosticar aquí y corregir después con la skill de cambio.

Para medir la carga de una página web, consulta `web-perf` en el [catálogo de referencias externas](../../docs/SOURCES.md#skills-especializadas); sus herramientas deben estar disponibles y autorizadas antes de usarla.

Determina la causa con evidencia suficiente y evita convertir una hipótesis plausible en una conclusión. Diagnosticar no autoriza modificar: si el usuario pidió solo análisis, detente antes de corregir.

## Método

1. Define el síntoma observable, el comportamiento esperado, el entorno afectado y una condición clara de éxito.
2. Construye el ciclo de comprobación más pequeño que recorra el fallo real: un comando, prueba o interacción repetible que falle por el síntoma informado. Si es intermitente, registra ocurrencias y condiciones en vez de asumir una causa.
3. Reduce el caso y compara una ruta que funciona con otra que falla. Ordena pocas hipótesis por evidencia, probabilidad y costo de comprobarlas.
4. Revisa primero las fuentes que pueden explicar el comportamiento sin cambiarlo: configuración, variables de entorno, datos, dependencias, logs y límites externos cuando apliquen.
5. Instrumenta solo lo necesario para distinguir hipótesis. Prueba una variable por vez y conserva evidencia de lo observado. En un encargo de solo lectura, limítate a logs existentes, contadores del sistema, consultas de lectura y ejecuciones aisladas; agregar trazas al código es una modificación y requiere autorización explícita.
6. Declara una causa solo cuando la evidencia conecte el mecanismo con el síntoma y descarte alternativas razonables. Separa siempre hechos observados, inferencias y elementos `NO PROBADO`.
7. Si la corrección fue autorizada, aplica el cambio permanente más pequeño en la capa responsable y reutiliza la verificación pertinente. Crear o ampliar pruebas depende de la política aplicable: no ordenes casos nuevos fuera de ella. Si corresponde la única prueba de reproducción permitida, comprueba antes que falle por el motivo previsto, cita comando y fallo observado, y después que pase con la corrección.
8. Ejecuta una verificación fresca del mismo recorrido. Una prueba distinta, un lint aislado o la confianza del agente no demuestran que el síntoma desapareció.
   Para regresiones de rendimiento, compara con configuración, carga, datos y condiciones equivalentes. Comprueba resultados correctos, trabajo real completado y errores en ambas versiones; omitir trabajo o fallar antes no acredita mejora. Mide el recorrido completo afectado y registra métrica y variación. Repite lo necesario para distinguir mejora de ruido y declara los límites.

## Límites

- No parches varias hipótesis a la vez ni modifiques el entorno solo para que la reproducción deje de fallar.
- Si no puedes reproducir ni obtener evidencia equivalente, informa el alcance revisado, lo descartado y lo que queda `NO PROBADO`; no inventes una causa.
- Antes de acciones sobre Producción, datos reales, credenciales o servicios compartidos, respeta las autorizaciones y restricciones del proyecto.
- No inicies servidores, despliegues ni otras operaciones externas salvo que el usuario o las instrucciones del proyecto lo autoricen.

## Entrega

Resume síntoma, reproducción, causa demostrada o hipótesis restantes, evidencia, corrección si fue autorizada, verificación ejecutada y riesgos residuales.
