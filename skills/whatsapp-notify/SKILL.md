---
name: whatsapp-notify
description: Envía mensajes o archivos expresamente autorizados por WhatsApp mediante wacli, resolviendo destinatarios y verificando aceptación. Consultar capacidades, redactar o revisar no autoriza enviar.
---

# Notificar por WhatsApp

Plantilla neutral: requiere `wacli`, una sesión vinculada y configuración local de destinatarios o un destinatario inequívoco indicado por el usuario. No es copia idéntica de reglas personales y no trae números, grupos predeterminados, identificadores ni correspondencias de contactos. Mantener esa configuración fuera del repositorio compartido.

## Envío autorizado

1. Confirmar mensaje/archivo, canal, destinatario y alcance expresamente autorizados. No deducir un envío por una mención citada, revisión de texto o publicación en otro servicio.
2. Comprobar la sesión con las capacidades locales de wacli; usar `wacli doctor --connect` si el estado no está confirmado. No mostrar credenciales o registros privados.
3. Resolver contacto o grupo con búsquedas de solo lectura. No elegir por aproximación entre varios resultados; preguntar si el destino no es inequívoco. No guardar identificadores reales en esta plantilla.
4. Usar la operación de envío adecuada con salida JSON. Para texto, `wacli --json send text`; comprobar sus opciones con la ayuda instalada. Enviar exactamente el contenido autorizado.
5. Considerar completado el envío solo con `success: true` y `sent: true`: confirma aceptación de WhatsApp, no lectura del destinatario. Un fallo o resultado incierto no autoriza reenviar automáticamente.

## Menciones y enlaces

- Si se solicita una mención real, resolver el contacto mediante `wacli --read-only --json contacts search` y comprobar pertenencia con `wacli --json groups info --jid <identificador-resuelto>`.
- Construir la mención y pasar `--mention` según la ayuda vigente del CLI. Nombrar a alguien en texto no equivale a mencionarlo. Si falta, sobra o no coincide el participante, consultar antes del envío.
- Si el mensaje acompaña una acción autorizada en otro servicio, obtener primero su enlace directo verificado; no inventarlo ni sustituirlo por uno general. Cada escritura externa debe estar autorizada por el pedido o las reglas locales, sin trasladar autorizaciones personales de otra instalación.

## Correcciones y cierre

Si se corrige el texto después de su aceptación, informar que ya salió y pedir autorización antes de otro mensaje. Nunca borrar, revocar o editar mensajes sin pedido específico. Reportar brevemente destino comprobado, aceptación o pendiente, sin copiar datos privados innecesarios.
