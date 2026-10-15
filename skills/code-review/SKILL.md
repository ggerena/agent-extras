---
name: code-review
description: Usar cuando el usuario pida una revisión de código, /revisa, /code-review, revisar un PR, una rama o cambios contra una base, o una revisión adversarial experta de un diff sin editar archivos. Priorizar errores reales, regresiones, incumplimientos de las instrucciones del proyecto y hallazgos de alta confianza; comentar en el PR solo con autorización explícita.
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
   - comentarios o intención histórica que el cambio contradiga.
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
    cambiadas y problemas que ya detecten lint, comprobación de tipos o CI, salvo evidencia de que
    CI no los detectará. La ausencia de pruebas unitarias o de integración nuevas no es por sí
    sola un hallazgo cuando la política aplicable las prohíbe; evalúa la verificación requerida
    dentro de esa política.
11. Si revisas un PR, usa `gh pr comment` solo cuando el usuario haya autorizado expresamente
    esa escritura externa en la sesión actual. En otro caso, informa los hallazgos localmente.

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
