---
name: crear-release
description: Prepara o revisa una versión de los repositorios configurados, relacionando el candidato con evidencia previa y condiciones operativas. Usar para crear una versión o revisar su riesgo; no autoriza merge, despliegue ni cambios en ambientes.
---

# Preparar o revisar una versión

Plantilla neutral: requiere configuración local y no es una copia idéntica de reglas de un proyecto. Configurar repositorios, ramas origen/destino, convención de versiones, ambientes permitidos, documentación y controles obligatorios antes de operar. No inferirlos de nombres habituales.

## Alcance

Revisar no autoriza corregir, publicar ni cambiar ambientes. Crear una versión permite preparar la rama y su PR únicamente si ese pedido y las instrucciones aplicables autorizan la publicación. Nunca incluye merge o despliegue. Consultar antes de acciones destructivas, nuevos accesos o decisiones materiales.

## Procedimiento

1. Comprobar instrucciones, estado local, destinos y referencias vigentes. Preservar cambios ajenos; no alinear el checkout descartándolos. Para creación autorizada, preparar el candidato desde la base configurada, publicar la rama segura y abrir su PR conforme a las reglas del repositorio.
2. Registrar base, head y alcance exactos. Detectar hotfixes de la rama destino ausentes en origen, resoluciones de conflictos y diferencias respecto de lo ya probado.
3. Revisar contratos entre consumidores, endpoints, autenticación, permisos efectivos, migraciones, variables, configuración, jobs, colas, cachés e integraciones afectadas. Un menú oculto o flag no demuestra autorización backend ni activación real.
4. Revisar configuración de cada ambiente solo con acceso autorizado. Comparar por campo/ruta; conservar exclusivas del destino. No promover objetos completos, dumps o valores de otro ambiente. Distinguir variable obligatoria de opción con default seguro; no copiar secretos ni mostrar valores.
5. Preparar cambios de configuración como lista permitida con actor/canal autorizado, condición previa o hash y comprobación posterior. Un reemplazo completo, permiso nuevo o activación de acceso requiere autorización específica. Verificar herencia, valores ausentes/null/vacíos, defaults, cachés y consumidores que puedan sobrescribir objetos completos.
6. Relacionar cada candidato con pruebas y CI vigentes del mismo código. Reutilizar evidencia equivalente cuando pueda acreditarse; comprobar solo el delta faltante. No atribuir a otro SHA resultados sin comparar el contenido afectado. No crear imágenes, contenedores o servidores para revisar por rutina.
7. Describir orden, compatibilidad, condiciones de activación, responsables, observación y reversión conforme al proyecto. No ejecutar acciones operativas por estar enumeradas. Si una condición crítica falta, indicar acción y momento obligatorios, sin afirmar que quedó resuelta.

## Entrega

Guardar el informe en la documentación configurada y enlazar el PR cuando exista. Ordenar precondiciones antes del paso, acciones durante la ventana y comprobaciones posteriores. Separar evidencia comprobada, decisiones pendientes y `NO PROBADO`; indicar SHA revisado, alcance y riesgos. No exigir políticas de respaldo, clientes, notificaciones o aprobaciones particulares que no estén en las instrucciones locales.
