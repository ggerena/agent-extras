---
name: crear-spec
description: Crea o actualiza una especificación y plan verificables para una implementación posterior. Usar al pedir un plan detallado o un documento para otra IA; no ejecutar el plan, revisar un PR ni desplegar.
---

# Especificación y plan de implementación

Plantilla neutral: requiere configurar los repositorios autorizados, instrucciones, carpeta documental y plantilla canónica local; no es una copia idéntica de un procedimiento personal. Si falta un dato indispensable o la plantilla obligatoria, informar el bloqueo en vez de inventar una fuente alternativa.

Un pedido de plan no autoriza implementarlo, cambiar datos, publicar código ni desplegar. No convertir un cambio pequeño y evidente en una especificación extensa sin necesidad.

## Flujo

1. Delimitar problema, resultado observable, actores, repositorios, ambientes candidatos y no objetivos. Separar decisiones tomadas de preguntas indispensables.
2. Leer instrucciones y plantilla locales; comprobar Git y cambios ajenos sin modificarlos. Trazar el recorrido real en código y revisar configuración, variables por nombre y datos pertinentes solo con los permisos vigentes. No crear clones, servidores o accesos para planificar.
3. Contrastar documentación histórica con el estado actual. Marcar premisas como verificadas con evidencia o `NO PROBADO`; si las fuentes se contradicen, investigar esa pregunta en vez de elegir silenciosamente una versión.
4. Buscar una especificación vigente del mismo trabajo y actualizarla antes de duplicar. Guardar en la ubicación configurada, separando especificación, estrategia técnica e instrucciones para la implementación posterior.
5. Expresar objetivo, reglas, contratos, casos permitidos/rechazados, requisitos `REQ-*` y criterios observables `ACEPT-*`. Asociar requisitos a prueba permitida, recorrido o justificación de comprobación manual. Respetar la política local de tests; este documento no autoriza casos nuevos fuera de ella.
6. Planificar fases, dependencias, configuración/datos, verificaciones, release y reversión según el riesgo. Incluir condiciones de parada para decisiones materiales, permisos, contradicciones, cambios destructivos y ambientes. Mantener estrategia técnica como propuesta modificable; requisitos y restricciones aprobados forman el contrato.
7. Para requisitos absolutos de datos o acceso, cubrir las superficies afectadas: interfaz, respuestas, impresión, almacenamiento, logs, telemetría, exportaciones y eventos. No equiparar una interfaz oculta a control efectivo del backend.
8. Completar solo secciones aplicables; justificar `No aplica` donde omitirlo genere ambigüedad. Enlazar evidencia sin pegar conversaciones, secretos, revisiones completas o logs extensos.
9. Revisar el documento completo, rutas, enlaces, estructura y diferencias. Resolver contradicciones, decisiones ocultas y placeholders accidentales; aplicar revisión independiente si las reglas vigentes la exigen.

## Cierre

Entregar el Markdown enlazado, estado de borrador/aprobación, evidencia, decisiones necesarias y pendientes. Publicarlo solo conforme a las instrucciones documentales del repositorio. Detenerse tras el plan: una orden posterior explícita puede autorizar su implementación, nunca por inferencia.
