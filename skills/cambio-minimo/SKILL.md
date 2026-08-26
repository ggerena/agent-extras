---
name: cambio-minimo
description: Implementa o revisa cambios de codigo con el menor alcance permanente razonable, priorizando reutilizacion, capacidades nativas y la causa raiz. Usar al agregar funciones, corregir errores, refactorizar o detectar sobreingenieria; no usar para tareas sin codigo.
---

# Cambio minimo

Resuelve la necesidad real con la menor complejidad que deba mantenerse. Primero entiende el flujo afectado; un diff pequeno en el lugar equivocado no es una solucion simple.

## Orden de decision

Detente en la primera opcion suficiente:

1. Confirma que la necesidad es actual y no hipotetica. Si es especulativa, indicalo antes de agregar codigo.
2. Busca una funcion, patron o componente equivalente en el repositorio y reutilizalo.
3. Prefiere una capacidad de la plataforma, la base de datos o la biblioteca estandar.
4. Usa una dependencia ya instalada cuando reduzca la complejidad total y sea coherente con el proyecto.
5. Agrega una dependencia, abstraccion o sistema nuevo solo si las opciones anteriores no cubren el caso.
6. Implementa el cambio correcto mas pequeno en la capa que corresponda.

## Criterios

- Antes de decidir, revisa el codigo afectado y, cuando aplique, configuracion, variables de entorno, esquema de datos y llamadas relacionadas.
- En errores, busca la causa compartida y sus consumidores. Corrige una vez en el punto comun cuando eso preserve el comportamiento esperado.
- Evita interfaces con una sola implementacion, fabricas para un solo caso, configuracion para valores fijos y estructura preparada para necesidades futuras no confirmadas.
- Prefiere codigo claro y convencional a codigo comprimido o ingenioso. Menos lineas no justifican menor legibilidad.
- No simplifiques validacion en limites de confianza, seguridad, accesibilidad ni manejo de errores que evite perdida de datos.
- Respeta todos los requisitos explicitos del usuario y las instrucciones del proyecto.
- Reutiliza o amplia las pruebas existentes. Agrega la verificacion mas pequena que demuestre el comportamiento y la regresion corregida.

Al entregar, menciona brevemente cualquier componente importante que se haya reutilizado o descartado por innecesario, solo si ayuda a entender la decision.
