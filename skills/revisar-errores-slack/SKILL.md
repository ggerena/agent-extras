---
name: revisar-errores-slack
description: Revisa en solo lectura un canal de alertas de Slack desde ayer a las 00:00 hasta el pedido, distingue ayer y hoy, agrupa errores y respalda conclusiones con mensajes. Usar con «revisa errores de Slack» o un pedido equivalente; no diagnostica el funcionamiento del propio Slack.
---

# Revisar errores de Slack

Usa SlackCLI y el perfil privado indicado por las instrucciones locales del usuario o proyecto. Lee allí el workspace/perfil, la identidad esperada, el canal y las opciones locales; nunca copies esa configuración a esta biblioteca. Si falta un destino inequívoco, pide solo ese dato. No abras almacenes de credenciales ni muestres tokens.

## Identidad y ventana

- Comprueba la versión y la ayuda local. Este procedimiento está contrastado con SlackCLI v0.15.0; si cambió, verifica la interfaz antes de consultar.
- Ejecuta `slackcli auth whoami --workspace WORKSPACE --json` y contrasta el estado, workspace e identidad con el perfil. Usa `--workspace WORKSPACE` en cada consulta; no dependas del predeterminado. Ante sesión incorrecta, falta de permisos o canal inaccesible, informa el impedimento sin cambiar autenticación ni membresía.
- Fija el corte una sola vez, con la hora de recepción del pedido. Si esa hora no está disponible, captura la hora antes de leer y declara esa aproximación. Usa `America/Santiago` y sus reglas de cambio de hora, sin fijar un desplazamiento UTC.
- Salvo otro período explícito, el inicio es ayer a las 00:00 locales; hoy a las 00:00 separa los dos días. Convierte esos instantes a epoch. Calcula por fechas locales, no restando 24 horas al corte. Muestra fechas y horas absolutas en el resultado.

## Lectura completa

Consulta el historial con este patrón, sustituyendo los argumentos por valores verificados:

```text
slackcli conversations read CHANNEL --workspace WORKSPACE --oldest INICIO_MENOS_1_MICROSEGUNDO --latest CORTE_MAS_1_MICROSEGUNDO --limit N --json
```

Conserva los timestamps exactos como cadenas o decimales; evita redondearlos con números de coma flotante. El margen de un microsegundo cubre límites exclusivos: conserva finalmente solo `inicio <= ts <= corte`.

El historial devuelve los últimos `N` mensajes del intervalo, aunque los presente en orden cronológico. Para reconstruir toda la ventana:

1. Mantén las páginas en memoria durante el procesamiento y revisa `has_more`. No conviertas el límite de página en límite total.
2. Mientras `has_more=true`, mantén `--oldest` y retrocede `--latest` al menor `ts` de la página recibida. Nunca avances `next_oldest` para completar historial: perderías los mensajes anteriores.
3. Acumula y elimina duplicados por `(channel, ts)`. Comprueba que el límite retrocede y termina al agotar el intervalo. Página vacía con más resultados, límite inmóvil, error o interrupción significan cobertura incompleta; informa el tramo pendiente.

Revisa `text`, `blocks` y `attachments`: una alerta puede tener el texto vacío. No reduzcas campos antes de conocer su estructura ni excluyas respuestas o mensajes propios por defecto. Procesa páginas localmente para mantener pequeño el contexto; no persistas datos crudos por defecto. Si necesitas un informe, guarda solo el Markdown depurado descrito en la entrega.

## Hilos y evidencia

Lee los hilos pertinentes cuando aporten contexto, confirmación o resolución:

```text
slackcli conversations read CHANNEL --workspace WORKSPACE --thread-ts THREAD_TS --oldest LIMITE_INFERIOR --latest CORTE_MAS_1_MICROSEGUNDO --limit N --json
```

Para contexto anterior, baja el límite solo lo necesario y separa ese material de los conteos de la ventana. Las respuestas se devuelven cronológicamente: si `has_more=true`, continúa el hilo con `--oldest` igual al mayor `ts` recibido, conservando el corte y verificando progreso. No apliques al hilo la paginación hacia atrás del historial. Elimina duplicados también entre historial e hilos.

Un historial del canal puede omitir hilos cuyo mensaje raíz es anterior al inicio aunque tengan respuestas recientes. No afirmes cobertura de todas esas respuestas si no la comprobaste; declara expresamente ese límite. Una lectura vacía o el silencio posterior no prueban resolución. Usa una confirmación explícita o evidencia equivalente, fechada antes del corte; distingue «resuelto según el hilo» de una corrección verificada en el sistema.

## Análisis y entrega

- Separa mensajes de alerta, respuestas de contexto y ocurrencias. Una alerta agregada puede representar varias ocurrencias; usa su cantidad solo si la evidencia la explica y evita sumar acumulados o reenvíos como hechos distintos. Si no puedes deduplicar eventos, informa mensajes y deja las ocurrencias como desconocidas.
- Agrupa por firma del error y servicio/operación; normaliza valores variables sin mezclar causas distintas. Informa por grupo conteos de ayer y hoy, primera/última hora, gravedad e impacto observado. Menciona servicios o clientes solo con evidencia y sin datos personales; no deduzcas alcance total desde un ejemplo.
- Adjunta pocos enlaces de ejemplo. Usa permalinks recibidos o constrúyelos con el dominio verificado, canal y `ts` exactos, quitando el punto del timestamp. No inventes destinos. Redacta secretos, datos sensibles y parámetros privados antes de mostrar o guardar extractos.
- Separa hechos de hipótesis y acciones sugeridas. «Nuevo» significa nuevo dentro de la ventana consultada, salvo comparación histórica comprobada; no atribuyas una causa raíz solo por similitud de mensajes.
- Entrega un veredicto breve con la ventana, conteos ayer/hoy, grupos principales y límites de cobertura. Si hace falta detalle, guarda un Markdown local depurado en el destino autorizado y enlázalo. Si hubo fallos, presenta lo observado como parcial, nunca como ausencia de errores.

La revisión es de solo lectura: no envíes mensajes, reacciones ni borradores, no marques leído, no unas canales, no cambies configuración, no ejecutes acciones en producción ni corrijas código. No crees seguimientos ni programaciones.

## Referencia de la interfaz

Consulta la documentación oficial de [conversaciones de SlackCLI v0.15.0](https://github.com/shaharia-lab/slackcli/blob/v0.15.0/docs/user-guide/conversations.md) y [uso desde scripts](https://github.com/shaharia-lab/slackcli/blob/v0.15.0/docs/user-guide/scripting.md) cuando debas verificar campos, límites o errores. Sus ejemplos de sondeo continuo no sustituyen la paginación de una ventana histórica completa.
