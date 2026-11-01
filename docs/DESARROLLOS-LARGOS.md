# Guía para desarrollos largos

Esta guía aplica a cualquier proyecto cuando una iniciativa abarca varias sesiones, repositorios, ambientes, agentes, decisiones funcionales o promociones de datos/configuración. Complementa las instrucciones globales y las reglas del proyecto; nunca amplía permisos ni sustituye restricciones de seguridad.

## Cuándo aplicarla

Usarla si ocurre una o más de estas condiciones:

- el trabajo afecta varios componentes o repositorios;
- requiere cambios coordinados de código, datos o configuración;
- atraviesa más de un ambiente;
- existe un roadmap mayor que el corte inmediato;
- hay PR, spec o comentarios funcionales que deben reconciliarse;
- el trabajo continuará en varias sesiones o pasará entre agentes;
- una dependencia externa condiciona el resultado.

Para cambios pequeños y autocontenidos, seguir únicamente el flujo normal del proyecto.

## Precedencia

1. Instrucciones del sistema, cliente y usuario para la tarea actual.
2. Instrucciones globales del agente que ejecuta la tarea.
3. `AGENTS.md`, reglas y procedimientos del proyecto o repositorio.
4. Fuente funcional designada y decisiones vigentes del usuario.
5. Contrato o plan de ejecución de la iniciativa.
6. Esta guía.

Una regla específica prevalece sobre una general. Esta guía no autoriza por sí sola merges, deploys, escrituras remotas, cambios en Prod, acciones destructivas ni ampliaciones de alcance.

## Principios

1. Cerrar una rebanada vertical demostrable antes de ampliar infraestructura horizontal.
2. Separar el corte actual —prototipo, MVP, QA o piloto— del producto final.
3. Mantener una sola fuente durable del estado; no reconstruirlo desde chats.
4. Tratar código, schema, datos, configuración, permisos y externos como una sola entrega de ambiente.
5. Ejecutar verificaciones deterministas durante el desarrollo y concentrar la revisión funcional al final.
6. Continuar autónomamente mientras el alcance vigente autorice el siguiente paso seguro.
7. Una duda del agente no es un bloqueo hasta agotar las fuentes y la evidencia disponible.
8. Cambiar de herramienta cuando otra vía autorizada produce evidencia mejor o más barata.

## 1. Contrato de ejecución

Al comenzar, crear o actualizar una sección breve en el plan, spec o documento rector existente. No crear otro archivo si una fuente vigente puede contenerla.

```text
Objetivo observable:
Etapa actual: prototipo | MVP local | Dev | QA | piloto Prod | producto final
Fuente(s) de verdad, en orden:
Repositorios y componentes:
Ambientes autorizados:
Dentro de alcance:
Fuera de alcance / diferido:
Acciones autónomas ya autorizadas:
Evidencia final requerida:
Condiciones válidas de pausa:
Siguiente paso seguro:
```

Actualizar el contrato cuando cambie una premisa. Marcar como obsoleta la evidencia que dependía de ella y repetir solo las verificaciones afectadas. No pedir al usuario que vuelva a expresar decisiones ya registradas.

## 2. Rebanadas y límite de trabajo en curso

Una rebanada vertical demuestra un comportamiento completo:

```text
entrada → validación → regla → persistencia → salida → evidencia
```

Convenciones:

- mantener una sola rebanada dependiente activa por flujo o cadena de entrega;
- mantener una cadena corta de PR por repositorio;
- no iniciar una capacidad dependiente hasta integrar o diferir explícitamente la anterior;
- agrupar cambios que solo tienen valor y prueba conjunta;
- separar cambios que puedan entregarse y verificarse de forma independiente;
- permitir trabajo paralelo solo si no comparte archivos, estado, decisiones ni orden de promoción.

El primer tercio del trabajo debería producir un recorrido demostrable. Si todavía solo existen capas internas, revisar el corte.

## 3. Autonomía: ejecutar, luego informar

Mientras el pedido y las instrucciones vigentes ya autoricen la acción, no pedir permiso adicional para pasos rutinarios y reversibles incluidos en el alcance, como:

- leer y buscar código, documentación, configuración, logs y datos pertinentes;
- inspeccionar Git y el estado de ambientes autorizados;
- ejecutar diagnósticos, tests, lint, tipos, build, revisión y métricas;
- implementar y corregir el cambio solicitado;
- crear y limpiar artefactos o datos temporales propios en local, o en otro ambiente que ya esté autorizado expresamente para escritura;
- preparar el respaldo normal en rama, commit, push y PR según las reglas del repositorio;
- cambiar a otra vía técnica cuando la herramienta elegida no permite avanzar;
- actualizar la matriz, evidencia, plan y documentación del trabajo.

Después de cada resultado, ejecutar el siguiente paso seguro sin preguntar “¿continúo?”. Informar el avance en hitos, no narrar cada comando.

Solicitar autorización nueva solo si:

- cambia el alcance o el ambiente;
- se requiere merge, deploy o escritura remota no autorizados;
- se toca Prod;
- se modifica información ajena o un sistema externo;
- la acción es destructiva, irreversible o difícil de recuperar;
- las reglas del proyecto o la herramienta exigen confirmación.

Una meta activa exige continuidad, pero no crea permisos nuevos.

Aunque una escritura remota sea reversible, requiere autorización vigente para ese ambiente. La autonomía rutinaria no convierte acceso técnico en permiso de modificación.

## 4. Fuentes de verdad y bloqueos

### Antes de declarar un bloqueo

1. Releer completa la fuente funcional designada y sus comentarios vigentes.
2. Verificar si una decisión más reciente sustituyó otra.
3. Contrastar con código, configuración, datos y comportamiento actual.
4. Buscar una vía alternativa segura de evidencia.
5. Citar el vacío o contradicción exactos y su impacto.

### Bloqueos válidos

- contradicción funcional que cambia el resultado;
- decisión nueva de Producto o del usuario;
- autoridad nueva para ambiente, permisos o acción destructiva;
- riesgo de seguridad, pérdida de datos o regresión transversal no aislable;
- cambios ajenos inseparables del diff propio;
- dependencia externa indispensable sin fallback aprobado.

### No son bloqueos

- una respuesta que está en la fuente designada;
- haber terminado solo un paso;
- necesitar revisar tests, logs, API o base de datos;
- falta de una revisión funcional intermedia;
- una herramienta visual no disponible si existe otra vía;
- una capacidad futura incompleta que está fuera del corte actual.

## 5. Matriz de estado y evidencia

Usar una tabla única por capacidad:

| ID | Capacidad | Definida | Desarrollada | Probada base | Integrada | Promovida | Validada | Evidencia/SHA | Pendiente |
|---|---|---|---|---|---|---|---|---|---|

Identificadores recomendados:

- `CAP-###`: capacidad o criterio;
- `DEC-###`: decisión cerrada;
- `EVID-###`: evidencia;
- `BLOCK-###`: bloqueo real;
- `DEFER-###`: diferido.

Estados permitidos:

- `VERIFICADO`: evidencia actual y reproducible;
- `NO PROBADO`: no existe evidencia suficiente;
- `BLOQUEADO`: condición válida de pausa documentada;
- `DIFERIDO`: fuera del corte con fase o responsable;
- `NO APLICA`: criterio ajeno al alcance.

No decir solamente “listo”, “funciona” o “falta poco”: indicar capacidad, ambiente y evidencia.

### Porcentajes

Separar:

- porcentaje del corte actual;
- porcentaje del roadmap completo;
- porcentaje efectivamente aceptado en el ambiente objetivo.

Fijar el denominador al iniciar el corte. Informar `criterios verificados / criterios totales`; no modificar pesos para mejorar la cifra.

## 6. Pruebas y revisión funcional

### Durante el desarrollo

- ejecutar y mantener los tests pertinentes según la política de pruebas de tus reglas de trabajo (plantilla en [REGLAS-DE-TRABAJO.md](REGLAS-DE-TRABAJO.md); al copiar esta guía, ajusta el enlace a tu archivo de instrucciones);
- ejecutar pruebas focales y controles razonables;
- revisar el diff y corregir hallazgos según las reglas del proyecto;
- actualizar la matriz y la evidencia;
- verificar que la versión publicada coincide con la probada.

### Al cerrar la rebanada

- ejecutar suites amplias razonables, tipos, lint y build aplicables;
- realizar la revisión final del diff completo;
- corregir y volver a probar;
- verificar configuración, datos, permisos y consumidores definidos en el contrato;
- limpiar o registrar temporales propios;
- ejecutar la medición estructural final si se tomó una línea base.

### Revisión funcional o visual

- No detener el desarrollo esperando revisiones funcionales parciales.
- Continuar con tests, API, logs, base de datos y demás evidencia determinista hasta cerrar la rebanada.
- Concentrar la revisión funcional/visual al final de la entrega integrada y estable.
- Puede ejecutarla el agente o el operador según herramientas, acceso y juicio requerido.
- Requerir intervención humana solo para aceptación, criterio subjetivo o una sesión/credencial que no pueda delegarse.
- Si el cierre encuentra un defecto, repetir solo el caso afectado después de corregir y reverificar.
- Un smoke intermedio se justifica únicamente cuando una premisa de alto riesgo decide el diseño restante.

La planificación de una revisión final no autoriza automáticamente ejecutar un smoke cuando las instrucciones globales o del proyecto requieren un pedido explícito.

La limpieza de temporales nunca incluye cerrar, cancelar, borrar ni cambiar el estado de tickets de prueba, salvo autorización expresa. Conservarlos en el estado alcanzado y reportar su identificación y ubicación cuando las reglas globales o del proyecto así lo exijan.

## 7. Estrategia de herramientas

Para evidencia funcional, preferir según el caso:

1. tests automatizados;
2. API;
3. base de datos o estado persistido;
4. logs y métricas;
5. navegador o control visual cuando realmente aporte evidencia necesaria.

No repetir más de dos intentos equivalentes sin nueva evidencia. Cambiar inmediatamente si el primer error demuestra incompatibilidad; repetir solo si cambió una precondición verificable. No convertir al usuario en operador de una automatización resoluble por otra vía.

## 8. Promoción por ambiente

No declarar un ambiente listo sin comprobar:

| Capa | Evidencia mínima |
|---|---|
| Código/artefacto | Rama y SHA o versión realmente desplegada |
| Schema/migración | Estructuras, índices y bootstrap aplicados |
| Datos operativos | Catálogos, relaciones y estados necesarios |
| Configuración/flags | Valores efectivos del ambiente |
| Permisos | Actores autorizados y aislamiento |
| Externos | Integración vigente, contrato y fallback |

Cada capa se marca `VERIFICADO`, `NO PROBADO` o `NO APLICA`. Una incertidumbre crítica bloquea la promoción, no toda metadata imposible de observar.

Para promociones no triviales, conservar un manifiesto pre/post con:

- origen, destino, versión y fecha;
- precondiciones;
- claves funcionales estables;
- conteos o hashes antes/después;
- cambios aplicados;
- verificación posterior;
- rollback y limpieza;
- elementos deliberadamente no promovidos.

Una copia histórica no demuestra paridad actual. La existencia de código o variables tampoco demuestra que una integración esté vigente.

## 9. Estándar por etapa

### MVP local o Dev

- vertical demostrable;
- reversible y observable;
- sin regresiones conocidas dentro del alcance;
- datos/configuración completos para el ambiente;
- tests y revisión aprobados;
- endurecimiento productivo separado como diferido.

No convertir carga final, rollout global, cumplimiento definitivo o infraestructura avanzada en bloqueos del MVP, salvo seguridad, pérdida de datos, irreversibilidad o regresión transversal.

### QA o piloto

- promoción reproducible;
- datos representativos;
- regresiones y aislamiento definidos;
- rollback ensayado;
- validación funcional final;
- monitoreo suficiente.

### Prod

Crear un contrato específico de salida y seguir el runbook y las reglas de release del proyecto. Exigir autorización explícita, inventario real, respaldo cuando corresponda, rollback probado, activación acotada y observación antes de expandir. Esta guía no reemplaza los controles particulares de infraestructura, seguridad, privacidad, datos o permisos.

## 10. Salud estructural

En iniciativas extensas, tomar una línea base al inicio y otra al cierre con la herramienta definida por el proyecto. Registrar ruta, SHA, versión/modelo, formato y estado Git. Agregar checkpoints solo ante cambios arquitectónicos o de hotspots, no cada cierta cantidad arbitraria de pasos.

Una métrica estructural no sustituye tests, revisión, rendimiento ni validación funcional.

## 11. Comunicación y handoff

Informar cuando comienza o termina una fase, cambia una premisa, aparece un riesgo real, se necesita autoridad nueva o se cierra un hito. Cada actualización debe expresar resultado, evidencia, riesgo y siguiente paso automático.

Handoff mínimo:

```text
Objetivo y corte actual:
Fuente de verdad:
Repositorios, ramas, PR y SHA:
Ambientes y versiones desplegadas:
Decisiones cerradas:
Matriz vigente:
Datos/configuración aplicados:
Pruebas y revisión:
Temporales y limpieza:
Pendientes y diferidos:
Bloqueo real, si existe:
Siguiente paso seguro:
```

No transferir conversaciones completas, secretos ni datos personales.

## 12. Señales de control

### Verde

- una rebanada dependiente activa;
- matriz vigente y ligada a evidencia;
- siguiente paso seguro en ejecución;
- ambiente descrito por un manifiesto;
- revisión funcional reservada para el cierre.

### Amarilla

- premisa sin revalidar;
- diferencia inesperada entre ambientes;
- cadena de PR creciendo;
- promoción manual no idempotente;
- primer fallo de herramienta;
- degradación de hotspot o métrica.

Acción: revalidar, actualizar contrato/matriz o cambiar de vía antes de ampliar el trabajo.

### Roja

- usuario obligado a repetir “continúa”;
- porcentaje reconstruido desde chats;
- ambiente declarado listo solo por deploy de código;
- revisiones funcionales repetidas entre cambios internos;
- integración asumida por existir código o variables;
- paridad inferida por el origen de una copia;
- nueva rebanada iniciada con la anterior parcial;
- afirmación negativa importante sin evidencia directa.

Acción: detener esa línea, reconciliar contrato, matriz y ambiente, y volver al vertical.

## 13. Métricas del proceso

- tiempo hasta la primera rebanada demostrable;
- rebanadas dependientes y cadenas de PR activas;
- intervenciones del usuario para pedir continuidad;
- revisiones funcionales repetidas por entrega;
- omisiones de datos/configuración descubiertas tras desplegar;
- bloqueos que ya estaban resueltos en la fuente de verdad;
- defectos encontrados antes y después de integrar;
- tiempo entre merge, deploy y evidencia del ambiente;
- variación estructural entre inicio y cierre.

## 14. Checklist de cierre

- [ ] Fuente de verdad y alcance vigentes.
- [ ] Rebanada vertical termina en el estado esperado.
- [ ] Tests, controles y revisión aprobados.
- [ ] Artefacto/SHA verificado o `NO PROBADO` justificado.
- [ ] Código, schema, datos, configuración, permisos y externos revisados.
- [ ] Consumidores y regresiones definidos conservan su comportamiento.
- [ ] Temporales propios limpios o documentados, sin alterar tickets de prueba salvo autorización expresa.
- [ ] Matriz y manifiesto actualizados.
- [ ] Revisión funcional final realizada o `NO PROBADO` explícito.
- [ ] Línea base y medición final comparables cuando aplican.
- [ ] Roadmap futuro separado del corte terminado.
- [ ] Estado y evidencia publicados en la fuente durable correspondiente.

## Mantenimiento

Actualizar esta guía solo con patrones aplicables a varios proyectos. Los detalles de clientes, repositorios, accesos, ambientes o herramientas específicas pertenecen a la memoria o documentación del proyecto correspondiente.
