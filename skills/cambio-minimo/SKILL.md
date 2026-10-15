---
name: cambio-minimo
description: Implementa o revisa cambios de código con el menor alcance permanente razonable, priorizando reutilización, capacidades nativas y la causa raíz. Usar al agregar funciones, corregir errores, refactorizar o detectar sobreingeniería; no usar para tareas sin código.
---

# Cambio mínimo

Resuelve la necesidad real con la menor complejidad que deba mantenerse. Primero entiende el flujo afectado; un diff pequeño en el lugar equivocado no es una solución simple.

## Orden de decisión

Detente en la primera opción suficiente:

1. Confirma que la necesidad es actual y no hipotética. Si es especulativa, indícalo antes de agregar código.
2. Busca una función, patrón o componente equivalente en el repositorio y reutilízalo.
3. Prefiere una capacidad de la plataforma, la base de datos o la biblioteca estándar.
4. Usa una dependencia ya instalada cuando reduzca la complejidad total y sea coherente con el proyecto.
5. Agrega una dependencia, abstracción o sistema nuevo solo si las opciones anteriores no cubren el caso.
6. Implementa el cambio correcto más pequeño en la capa que corresponda.

## Criterios

- Antes de decidir, revisa el código afectado y, cuando aplique, configuración, variables de entorno, esquema de datos y llamadas relacionadas. Identifica el supuesto crítico del que dependan corrección o seguridad y compruébalo en código productivo real, incluidos sus consumidores directos e indirectos (llamadores, contratos, procesos y servicios que dependan del supuesto); una función auxiliar aislada o una simulación no acreditan el recorrido.
- En errores, busca la causa compartida y sus consumidores. Corrige una vez en el punto común cuando eso preserve el comportamiento esperado.
- Si prevenir una reincidencia está dentro del encargo, clasifica primero el fallo. Para patrones mecánicos y verificables, revisa los scripts, configuración y CI existentes; conecta o amplía la comprobación existente más barata, ya sea lint, prueba o hook, antes de agregar otra regla para agentes. Si el repositorio no tiene ese control y crearlo no se justifica por una falla observada, informa la oportunidad sin agregar infraestructura.
- Evita interfaces con una sola implementación, fábricas para un solo caso, configuración para valores fijos y estructura preparada para necesidades futuras no confirmadas.
- Prefiere código claro y convencional a código comprimido o ingenioso. Menos líneas no justifican menor legibilidad.
- No simplifiques validación en límites de confianza, seguridad, accesibilidad ni manejo de errores que evite pérdida de datos.
- Si la solución mínima tiene un límite conocido y relevante, deja explícitos ese límite y la condición observable que justificaría ampliarla. Documéntalo por las vías permitidas por las instrucciones del proyecto; no agregues comentarios si esas reglas lo prohíben.
- Cuando el cambio afecte un comportamiento que deba comprobarse en operación, identifica una señal existente que permita verificar su resultado o detectar su fallo. Amplía la instrumentación solo si hay una brecha concreta dentro del encargo; no agregues infraestructura ni accedas a ambientes sin autorización.
- Respeta todos los requisitos explícitos del usuario y las instrucciones del proyecto.
- Reutiliza las pruebas existentes y la verificación más pequeña que demuestre el comportamiento. Crear o ampliar casos debe respetar la política aplicable; esta skill no autoriza pruebas nuevas fuera de ella.

## Revisión de sobreingeniería

Cuando se use la skill para revisar, reporta cada complejidad removible con su ubicación, qué se puede quitar y qué alternativa suficiente la reemplaza: nada, reutilización, capacidad nativa, biblioteca estándar o dependencia existente. Esta mirada complementa la revisión de corrección, seguridad y rendimiento; no la sustituye ni convierte la cantidad de líneas eliminadas en objetivo.

Aplica la prueba de borrado a cada abstracción sospechosa: si al quitarla la complejidad desaparece, era intermediación innecesaria; si reaparece distribuida entre varios consumidores, probablemente aporta valor.

Al entregar, menciona brevemente cualquier componente importante que se haya reutilizado o descartado por innecesario, solo si ayuda a entender la decisión.
