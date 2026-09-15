---
name: diagnostico-con-evidencia
description: Diagnostica errores, fallos intermitentes o regresiones de rendimiento mediante una reproduccion verificable, hipotesis ordenadas e instrumentacion antes de corregir. Usar cuando se pida diagnosticar, depurar, encontrar la causa o explicar por que algo falla o esta lento; no usar para revisar un diff sin ejecutar, seguir un smoke test predefinido, restaurar de urgencia un servicio ni medir la carga de una pagina web con metricas, que corresponde a web-perf.
---

# Diagnostico con evidencia

**Cual corresponde:** esta skill encuentra la causa cuando no se sabe por que falla. Si la causa ya esta identificada y solo hay que corregirla, corresponde `cambio-minimo`. Pueden encadenarse: diagnosticar aqui y corregir despues con la skill de cambio.

Determina la causa con evidencia suficiente y evita convertir una hipotesis plausible en una conclusion. Diagnosticar no autoriza modificar: si el usuario pidio solo analisis, detente antes de corregir.

## Metodo

1. Define el sintoma observable, el comportamiento esperado, el entorno afectado y una condicion clara de exito.
2. Construye el ciclo de comprobacion mas pequeno que recorra el fallo real: un comando, prueba o interaccion repetible que falle por el sintoma informado. Si es intermitente, registra ocurrencias y condiciones en vez de asumir una causa.
3. Reduce el caso y compara una ruta que funciona con otra que falla. Ordena pocas hipotesis por evidencia, probabilidad y costo de comprobarlas.
4. Revisa primero las fuentes que pueden explicar el comportamiento sin cambiarlo: configuracion, variables de entorno, datos, dependencias, logs y limites externos cuando apliquen.
5. Instrumenta solo lo necesario para distinguir hipotesis. Prueba una variable por vez y conserva evidencia de lo observado. En un encargo de solo lectura, limitate a logs existentes, contadores del sistema, consultas de lectura y ejecuciones aisladas; agregar trazas al codigo es una modificacion y requiere autorizacion explicita.
6. Declara una causa solo cuando la evidencia conecte el mecanismo con el sintoma y descarte alternativas razonables. Separa siempre hechos observados, inferencias y elementos `NO PROBADO`.
7. Si la correccion fue autorizada, aplica el cambio permanente mas pequeno en la capa responsable y agrega o adapta una prueba de regresion que detecte el fallo.
8. Ejecuta una verificacion fresca del mismo recorrido. Una prueba distinta, un lint aislado o la confianza del agente no demuestran que el sintoma desaparecio.

## Limites

- No parches varias hipotesis a la vez ni modifiques el entorno solo para que la reproduccion deje de fallar.
- Si no puedes reproducir ni obtener evidencia equivalente, informa el alcance revisado, lo descartado y lo que queda `NO PROBADO`; no inventes una causa.
- Antes de acciones sobre Produccion, datos reales, credenciales o servicios compartidos, respeta las autorizaciones y restricciones del proyecto.
- No inicies servidores, despliegues ni otras operaciones externas salvo que el usuario o las instrucciones del proyecto lo autoricen.

## Entrega

Resume sintoma, reproduccion, causa demostrada o hipotesis restantes, evidencia, correccion si fue autorizada, verificacion ejecutada y riesgos residuales.
