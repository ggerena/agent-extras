# Verificación compartida

Detalle bajo demanda de las reglas de trabajo (tu archivo de instrucciones globales; plantilla en [REGLAS-DE-TRABAJO.md](REGLAS-DE-TRABAJO.md)). Al copiar este archivo junto a tus instrucciones, ajusta este enlace a ese archivo. Leer solo la sección pertinente al diseñar/revisar pruebas, diagnosticar, medir rendimiento, verificar cambios o ejecutar un merge expresamente autorizado. No concede permisos de implementación, acceso, publicación, servidores ni pruebas visuales.

## Resultado y recorrido afectado

- Definir el cierre mediante un resultado observable. Si intervienen roles, precisar permisos y resultados por perfil. Seguir solo el recorrido afectado por interfaz, backend, persistencia, procesos y servicios externos; distinguir comprobado y `NO PROBADO`.
- Identificar el supuesto crítico del que dependa la corrección o seguridad del cambio y comprobarlo en código productivo real y sus consumidores directos e indirectos (llamadores, procesos, contratos y servicios que dependan del supuesto). Una descripción, un mock o el test aislado de un helper no acreditan que el consumidor cumpla ese supuesto. Usar evidencia del recorrido pertinente, sin ampliar el encargo a una auditoría.
- En pruebas locales de navegador ya solicitadas, resolver primero cuentas, roles, estaciones y datos por las vías autorizadas. Enumerar en el plan las pantallas reales afectadas y sus acciones aplicables: abrir, iniciar, finalizar y cancelar/devolver. Aprobar una vista no acredita las demás.
- Una regresión descubierta del desarrollo autorizado sigue dentro del mismo objetivo: corregirla y repetir el recorrido antes de declarar listo. Consultar solo ante bloqueo real, decisión material o ampliación de alcance; respetar las aprobaciones de las reglas de trabajo.

## Guías reutilizables de recorridos

Durante una implementación o verificación autorizada, buscar primero documentación y herramientas de prueba existentes. Donde falte una guía suficiente de la función afectada y el encargo autorice modificar el repo, agregar o completar en la documentación pertinente el recorrido utilizado: precondiciones y datos de prueba sin secretos, rol, acciones, estado final esperado y evidencia observable. En tareas de solo lectura, informar la guía faltante sin crearla. Reutilizar el ejecutor de pruebas y comandos existentes; no crear otro sistema, skill ni infraestructura.

Distinguir lo ejecutado de lo pendiente y dejar cómo repetirlo. Documentar no acredita ejecución ni autoriza iniciar servidores, pedir acceso, usar otros ambientes o hacer pruebas visuales. No generar guías ajenas al encargo.

## Tests proporcionales

La autorización de tests nuevos, pruebas protegidas, borrado y límites de ejecución están en las reglas de trabajo; esta sección no agrega excepciones.

- Buscar cobertura antes de agregar pruebas y preferir una pertinente existente. Ampliarla no autoriza casos unitarios/de integración nuevos fuera de la política. Organizar por comportamiento, no por archivo productivo ni por cantidades o porcentajes de cobertura.
- Cada caso nuevo autorizado debe cubrir un riesgo, regla o regresión no comprobado y usar el nivel permitido más sencillo. Conservar casos permitidos, rechazados y límites relevantes para permisos, aislamiento y conservación de datos.
- Parametrizar solo dimensiones que cambien el resultado o recorran una ruta ejecutable distinta. Evitar productos cartesianos inútiles, métodos HTTP no publicados y aserciones duplicadas. Comprobar a fondo la regla compartida y su conexión en consumidores distintos, sin repetir la matriz completa.
- Ejecutar lógica productiva real; no copiarla en `simulate*` ni replicar filtros, almacenamiento o framework para demostrar corrección. Usar mocks solo en fronteras externas necesarias, incluidos dobles de datos fijos, sin atribuirles garantías reales de persistencia, SQL, autenticación o HTTP. Para ellas, reutilizar integración local disponible; si falta, declarar `NO PROBADO` y resolver la validación requerida según las reglas de trabajo, sin instalar ni arrancar infraestructura sin permiso.
- Cuando corresponda el único test autorizado de reproducción de un bug, ejecutarlo antes de corregir y comprobar que falla por el motivo previsto, no por importación, configuración u otro fallo ajeno. Registrar revisión/estado del código, comando y mensaje o aserción que demuestra el fallo; después, comprobar que pasa con la corrección. Obtener esa evidencia sin sobrescribir trabajo ajeno. Sin fallo previo comprobado, no afirmar que reproduce el bug; marcarlo `NO PROBADO` y resolver la validación pendiente.
- Revisar el aporte de los tests del cambio y simplificar redundancias autorizadas. Esto no permite retirar suites preexistentes fuera del encargo ni omitir checks obligatorios. Ejecutar primero pruebas afectadas y luego las exigidas por el proyecto, con un solo ejecutor y los límites de workers de las reglas de trabajo.
- Reutilizar resultados vigentes del mismo código y entorno solo con revisión/estado, comando, entorno y resultado verificables. Repetir si cambió el código o entorno, falta evidencia, hay fallos/sospecha concreta o se exige una ejecución fresca. Dos skills que mencionan el mismo control no obligan a repetirlo sin causa.

## Mediciones de rendimiento

- Comparar antes/después con configuración, carga, datos y condiciones equivalentes. Registrar versiones/estado, comando o recorrido, métrica y variación; aclarar diferencias inevitables que limiten la comparación.
- Comprobar que ambas ejecuciones realizan el trabajo real esperado con resultados correctos y sin errores ocultos: fallar antes, omitir tareas o devolver menos datos no acredita una mejora.
- Medir el recorrido completo afectado; una mejora en una parte no demuestra mejora total. Repetir lo necesario para distinguir variación normal de una mejora y declarar ruido e incertidumbre, sin inventar precisión.

## Cierre de PR

- El respaldo temprano puede preceder pruebas/revisión; no equivale a estar listo. Mantener el mismo PR y volverlo a borrador antes de otro push no validado.
- Tras validación local y revisiones satisfactorias, comprobar que el head publicado corresponde al código verificado. Completar pronto los controles obligatorios y pasar a ready cuando se cumplan las condiciones del proyecto y los bloqueos se resuelvan o acepten expresamente.
- Si CI requiere ready para ejecutar, activarlo tras el control local, comprobar que arranque y revisar el resultado antes de recomendar merge. Estar ready inicia esa validación; no acredita que terminó ni permite omitir pruebas locales. En los demás casos, respetar los controles remotos exigidos antes de darlo por listo.
- La evidencia y revisión deben cubrir el diff final y head actual, sin hallazgos ni revisiones pendientes. Si falta cobertura material, mantener el PR en borrador e indicar el pendiente. Nunca deducir permiso de merge o despliegue de readiness, aprobación o CI.

## Merge autorizado

Solo después del pedido explícito exigido en las reglas de trabajo y con pruebas/revisiones aprobadas:

1. Comprobar repo, PR abierto, rama base/destino, head SHA y controles actuales. El SHA debe ser el publicado, probado y revisado; no usar un veredicto anterior para contenido distinto.
2. Al usar `gh pr merge`, pasar `--match-head-commit <SHA-verificado>` para impedir que se fusione un head cambiado. En otra herramienta, usar su control equivalente; si no puede garantizar la coincidencia requerida, informar el bloqueo y consultar antes de otra vía.
3. Ese control no inmoviliza la base ni garantiza su comprobación atómica. Revisar cambios de base y condiciones del proyecto y revalidar lo que afecten; no atribuir al parámetro garantías que no tiene.
4. Un pedido de merge no autoriza auto-merge ni cola. Antes de ejecutar, comprobar si la rama exige cola o si la herramienta puede activar auto-merge implícitamente; si puede ocurrir sin autorización específica, no ejecutar y consultar, sin sortear protecciones ni modificar configuración. Verificar el resultado y SHA finales tras la acción autorizada.
