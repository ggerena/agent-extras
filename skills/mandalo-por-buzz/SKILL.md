---
name: mandalo-por-buzz
description: Envía un encargo por Buzz solo cuando el usuario pide expresamente esa vía o identifica inequívocamente un agente de Buzz. Requiere un helper configurado; no usar para delegación genérica ni desde una sesión iniciada en Buzz.
disable-model-invocation: true
---

# Encargar trabajo por Buzz

Plantilla neutral, no copia íntegra de una instalación personal. **No incluye script de envío.** Requiere un helper instalado y configurado explícitamente por el usuario, con documentación local sobre destino, permisos, autenticación, vista previa, envío, espera y resultados. No contiene rutas internas, contactos, agentes predeterminados ni credenciales.

## Precondiciones

- Si la sesión fue iniciada desde Buzz, no reenviar: trabajar y responder en ese mismo hilo. Si el origen no se puede determinar, no enviar y aclararlo.
- Un pedido genérico de otra IA, subagentes o delegación no activa Buzz. El encargo debe autorizar esa vía y delimitar objetivo, destinatario y permisos; consultar únicamente si falta un dato indispensable.
- Resolver la ubicación del helper desde configuración local explícita, comprobar su ayuda/documentación y el destino efectivo. No descargar, instalar, buscar credenciales ni copiar scripts de otra persona para suplirlo. Si falta o no permite el seguimiento requerido, informar el bloqueo sin enviar.
- La vista previa, si el helper la ofrece, no envía ni autoriza un envío posterior. No incluir secretos, datos personales ni contenido ajeno al encargo.

## Enviar y seguir

1. Preparar el encargo exacto, con contexto mínimo, restricciones, criterio de cierre y solicitud de respuesta en el mismo hilo. No convertir análisis en implementación ni ampliar permisos.
2. Hacer un solo envío autorizado mediante el helper configurado; conservar el identificador devuelto sin credenciales. Una respuesta `sent` o un acuse solo acreditan el envío, no la ejecución.
3. Esperar y revisar una respuesta final sustantiva, también en encargos de implementación. Usar el mecanismo de espera documentado por el helper y los límites de tiempo/rondas de las instrucciones locales. No detener la escucha por ver `sent` ni tratar avances como resultado final.
4. Si vence el plazo, falla el transporte o se requiere intervención, informar que sigue pendiente. No reenviar ni cambiar destinatario, modelo o transporte automáticamente. Detener antes si el usuario lo pide.
5. Revisar la respuesta contra el objetivo y la evidencia antes de cerrar. Reportar brevemente resultado comprobado o pendiente, estado e identificador necesario para retomarlo.

El envío nunca autoriza merge, push protegido, despliegues, cambios de ambiente, acciones destructivas u otras escrituras externas no pedidas. Una autorización vale para ese encargo y sus límites, no para nuevas fases o destinatarios.
