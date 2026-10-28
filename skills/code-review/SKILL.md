---
name: code-review
description: Usar cuando el usuario pida una revisión de código, /revisa, /code-review, revisar un PR, una rama o cambios contra una base, o una revisión adversarial experta de un diff sin editar archivos. Priorizar errores reales, regresiones, incumplimientos de las instrucciones del proyecto y hallazgos de alta confianza; comentar en el PR solo con autorización explícita o según las instrucciones vigentes.
---

# Revisión de código

Actúa como revisor experto de código. Revisa un PR o una rama contra su base comprobada.
Esta skill es de solo lectura: no edites archivos, crees informes en el repositorio ni hagas
commit, push o merge. No corrijas hallazgos aquí. Devuélvelos al usuario o al flujo que contiene
esta revisión, como `cerrar-pr`, responsable de las correcciones y verificaciones autorizadas.

**Qué flujo de revisión corresponde:** esta skill revisa directamente una rama o PR. Si el usuario
pide la opinión de OTRO agente, usa un subagente disponible en el entorno actual y respeta el
revisor indicado y las reglas del cliente. Debe ser una sesión o agente distinto del implementador;
si no está disponible, informa la limitación sin sustituirlo por una autorrevisión. Un envío fuera
del entorno actual requiere autorización explícita. Si hay que traspasar la implementación,
usa el procedimiento de traspaso correspondiente. Para una versión próxima a Producción, aplica el
procedimiento de revisión de versiones del proyecto, si existe.

## Flujo

1. Identifica si se revisará un PR o la rama actual.
2. Si es un PR, comprueba que esté abierto e identifica el SHA de su último commit y su base real.
   Para una rama, usa la base indicada por el usuario; si no la indicó, identifica y comprueba la
   rama principal predeterminada del repositorio. Nunca uses como base la rama remota de seguimiento
   de la rama de trabajo actual ni supongas que es `develop`. Se pueden revisar PR borradores:
   los respaldos tempranos se crean en borrador de forma deliberada. Una revisión anterior no
   excluye otra iteración; revisa el diff completo actual y vuelve a comprobar los hallazgos
   anteriores contra el último commit. No reutilices un veredicto para otro SHA ni para cambios
   locales sin revisar.
3. Lee las instrucciones pertinentes del proyecto, como `AGENTS.md`, `CLAUDE.md`, `.opencode`
   o archivos equivalentes aplicables a las rutas modificadas.
4. Lee el diff completo de los commits con `gh pr diff <n>` para un PR o `git diff <base>...HEAD`
   para una rama. Inspecciona también los cambios preparados con `git diff --cached`, los no
   preparados con `git diff` y el contenido de los archivos pertinentes que devuelva
   `git ls-files --others --exclude-standard`. Registra la base, el último commit o ancestro
   común revisados y si se incluyeron cambios locales.
5. Realiza una **revisión adversarial**: no te limites a comprobar si el caso normal parece
   razonable. Intenta refutar las garantías del cambio mediante casos de abuso concretos,
   entradas malformadas, condiciones límite, operaciones concurrentes, fallos parciales, estados
   desactualizados, cruces de permisos e incumplimientos de invariantes pertinentes al diff.
   Trata descripciones, pruebas, comentarios y afirmaciones del autor como hipótesis que debes
   comprobar contra la implementación. Identifica el supuesto crítico del que dependa la corrección
   o seguridad y compruébalo en código productivo real y en sus consumidores directos e indirectos
   (llamadores, contratos, procesos y servicios que dependan del supuesto); las funciones auxiliares
   aisladas y las simulaciones no demuestran el recorrido completo. Mantén un alcance proporcional
   al cambio y no inventes hallazgos especulativos sin razonamiento reproducible o evidencia.
6. Revisa si hay:
   - errores funcionales y regresiones;
   - incompatibilidades de API, propiedades de componentes o contratos de datos;
   - riesgos de seguridad, permisos, secretos o pérdida de datos;
   - incumplimientos de las instrucciones del proyecto;
   - comentarios o intención histórica que el cambio contradiga;
   - cambios difíciles de revertir después de publicarse, como migraciones, borrado o
     transformación de datos, contratos públicos o envíos externos, sin una vía de reversión o
     compatibilidad comprobada;
   - errores silenciados: excepciones capturadas sin registro ni aviso, o valores por defecto,
     reintentos y comportamientos de respaldo que ocultan una falla real;
   - si el diff cambia pantallas, componentes visibles o textos para el usuario, los problemas de
     textos y complejidad de interfaz descritos en [Cambios de interfaz](#cambios-de-interfaz);
   - si `km` está disponible, las señales descritas en [Señales de km](#señales-de-km).
7. Usa pruebas acotadas o scripts temporales fuera de la copia de trabajo cuando permitan
   confirmar o descartar una sospecha concreta con seguridad, respetando la política de pruebas
   aplicable. Si se presenta una prueba de regresión, comprueba la evidencia de que fallaba antes
   de la corrección por el motivo previsto y no por un fallo ajeno de preparación. No modifiques
   la copia de trabajo revisada ni debilites comprobaciones existentes.
8. Usa `git blame`, el historial local o PR anteriores solo cuando ayuden a comprobar una sospecha concreta.
9. Asigna severidad y confianza a cada hallazgo. Conserva solo hallazgos con confianza de 80 o más:
   - **Alta:** exposición de seguridad, pérdida de datos, caída de Producción, regresión importante
     o impedimento para el funcionamiento correcto.
   - **Media:** error visible para el usuario, contrato roto o incompleto, validación ausente
     o falta de cobertura de pruebas que haga probable una regresión.
   - **Baja:** riesgo de mantenibilidad que no impida el cierre o riesgo menor de funcionamiento
     correcto, respaldado por evidencia concreta.
10. Omite detalles irrelevantes, observaciones solo de estilo, problemas previos fuera de las líneas
    cambiadas (un texto confuso o un paso innecesario que afecte a quien usa la pantalla no es
    solo de estilo) y problemas que ya detecten lint, comprobación de tipos o CI, salvo evidencia de que
    CI no los detectará. La ausencia de pruebas unitarias o de integración nuevas no es por sí
    sola un hallazgo cuando la política aplicable las prohíbe; evalúa la verificación requerida
    dentro de esa política.
11. Si revisas un PR, usa `gh pr comment` solo cuando el usuario haya autorizado expresamente
    esa escritura externa en la sesión actual o sus instrucciones vigentes lo autoricen con las
    condiciones que fijen. En otro caso, informa los hallazgos localmente.

## Señales de km

Ejecuta los comandos desde la raíz del repositorio: `km impact` mide siempre todo el repositorio y
`km docs refs` solo el directorio indicado. Son solo de lectura y tardan pocos segundos. Ninguna
señal de km es por sí sola un hallazgo ni bloquea el cierre: confírmala en el código y repórtala
solo con la confianza mínima de 80. Si `km` no está disponible o falla, indícalo y sigue.

- **Cambios conjuntos:** si el último commit revisado está disponible localmente, ejecuta
  `km impact . --since-ref <base> --until-ref <SHA revisado>`. `km impact . --pr <n>` sin esos
  commits mide el parche contra la copia local sin aplicarlo; para una rama, `--since-ref <base>`
  sin `--until-ref` incluye cambios sin commit y archivos no versionados. Indica qué variante
  usaste. Usa la sección de archivos que suelen cambiar con el diff y no están en él
  («Logical radius»). Por cada uno, comprueba si el cambio también debía llegar ahí, por ejemplo
  otra vista que muestra los mismos datos. Ignora los avisos de archivos sin pruebas y de
  documentos que solo nombran archivos cambiados.
- **Referencias rotas:** si el diff cambia documentos Markdown o mueve, renombra o elimina
  archivos, ejecuta `km docs refs . --since-ref <base>`. Reporta las referencias rotas que el
  cambio introduce o que apuntan a archivos que el cambio movió o eliminó. Este comando examina
  los archivos de la copia local: úsalo solo si esa copia corresponde al último commit revisado;
  si no, indica esta comprobación como pendiente.

## Cambios de interfaz

Aplica esta sección solo a pantallas, componentes o textos visibles que el diff agrega o cambia.
Revisa desde el código y los textos reales; no levantes servidores ni abras navegador sin pedido.
Compara con pantallas existentes del mismo proyecto antes de proponer otra forma. Redacta los
textos propuestos en el idioma del producto.

**Textos:**

- Los mensajes de error dicen qué pasó y qué puede hacer la persona; no se quedan en «Error» o
  «Algo salió mal» ni muestran códigos internos, trazas o nombres de campos de la base de datos.
- Los botones y enlaces nombran la acción concreta («Guardar ticket», no «OK» o «Aceptar» cuando
  hay varias acciones). Una acción destructiva o irreversible dice qué se pierde.
- Se usa el mismo término para el mismo concepto en la pantalla y en las pantallas existentes.
- Idioma, trato (tú o usted) y vocabulario del producto, sin mezclar idiomas ni usar jerga técnica
  con personas usuarias finales. Revisa ortografía y tildes.
- Los estados vacíos, de carga y de éxito explican qué pasa y, si corresponde, el siguiente paso.
- No quedan textos de relleno, `TODO`, ejemplos usados como etiqueta ni frases genéricas de
  marketing que no digan nada concreto del producto.

**Complejidad:**

- La tarea principal de la pantalla se reconoce de inmediato y tiene una sola acción principal
  destacada, no varias con el mismo peso.
- Cada campo, opción o paso nuevo es necesario para la tarea. Los obligatorios son los mínimos y
  los valores por defecto evitan decisiones que la persona no sabría tomar.
- Cuenta los pasos o clics de la tarea principal antes y después del cambio. Señala modales,
  confirmaciones o pantallas intermedias que se agregan sin necesidad.
- No se muestran a personas usuarias finales identificadores internos, opciones técnicas o
  configuración que no necesitan entender.
- Se reutilizan los componentes y patrones del proyecto. Señala elementos visuales que el resto
  del proyecto no usa (por ejemplo degradados, tarjetas grandes, emojis decorativos o todo
  centrado) solo como inconsistencia con el diseño existente; es **Baja** salvo que afecte la
  lectura o la tarea.
- Antes de proponer quitar un campo, opción, paso o confirmación, comprueba su propósito en los
  requisitos, el backend o el recorrido existente. No propongas quitar confirmaciones de acciones
  destructivas, validaciones ni controles de permisos o seguridad. Menos clics no basta por sí
  solo como mejora.

Severidad: usa la escala general y la confianza mínima de 80. Como guía: **Alta** si un texto
engañoso puede llevar a pérdida de datos, una acción irreversible no deseada o exposición de datos;
**Media** si un texto engaña, si la persona puede no entender cómo completar la tarea o si el
cambio agrega pasos evitables a una tarea frecuente; **Baja** en los demás casos con evidencia
concreta. Propón el texto o la simplificación concreta. Esta revisión no reemplaza una prueba con
personas reales: indica `NO PROBADO` visualmente cuando no se vio la pantalla. Para datos extremos
(nombres largos, listas vacías, cifras enormes), usa `break-ui` si está disponible.

## Entrega

Empieza por los hallazgos ordenados por severidad. Incluye `archivo:linea` o un enlace de GitHub,
severidad, confianza, impacto y una explicación concreta.

Usa esta estructura:

```markdown
### Code review

Se encontraron N problemas:

1. [Alta|Media|Baja] <hallazgo> (confianza: <80-100>)
<archivo:linea o enlace>
<explicacion concreta>
```

Si no hay hallazgos:

```markdown
### Code review

Sin problemas. Se realizó una revisión adversarial en busca de bugs, casos límite y cumplimiento de instrucciones del proyecto.
```

## Notas

- En repositorios con subproyectos, ejecuta el diff dentro del subproyecto que se revisa.
- Para enlaces de GitHub, usa el SHA completo del commit.
- Indica el último commit revisado y si se incluyeron cambios sin commit. Distingue los hallazgos
  de las pruebas u otras revisiones requeridas que estén pendientes; no encontrar problemas de
  código no demuestra que esas comprobaciones pasaron ni autoriza marcar el PR listo o hacer merge.
- Mantén la respuesta final breve y centrada en riesgos, evidencia y veredicto.
