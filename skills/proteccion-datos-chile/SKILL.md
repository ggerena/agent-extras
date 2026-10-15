---
name: proteccion-datos-chile
description: Revisa, diseña o implementa privacidad conforme a la normativa chilena cuando se pide esa revisión o adecuación, incluido «revisa con la ley de protección de datos» o $proteccion-datos-chile. No activar una auditoría completa por la sola presencia de datos personales.
---

# Protección de datos en Chile

Conecta cada obligación aplicable con el tratamiento real, su control y su evidencia. Una revisión técnica no certifica cumplimiento jurídico integral.

## Alcance y permisos

- Conserva el objetivo del encargo: una consulta o revisión es de solo lectura; implementar requiere autorización y sigue las reglas del proyecto. Esta skill no autoriza publicar, cambiar ambientes, tratar datos reales ni enviar información a terceros.
- Reutiliza decisiones, inventarios, contratos y documentación existentes. Pregunta solo hechos indispensables que no puedas comprobar; evita cuestionarios masivos y no generes por defecto todas las políticas o contratos.
- Acota la revisión a los datos, finalidades, personas y recorridos afectados. Amplíala solo si una dependencia concreta impide evaluar el requisito o revela un acceso indebido.

## Determinar la norma aplicable

1. Fija la fecha del análisis y del tratamiento previsto. Abre fuentes oficiales y comprueba versión, artículo, vigencia y disposiciones transitorias; separa el régimen vigente de las reformas publicadas aún futuras. Consulta también normativa sectorial solo cuando corresponda al caso.
2. Lee el apartado pertinente del [mapa legal](references/mapa-legal.md) cuando debas comprobar bases, derechos, incidentes, evaluación de impacto o gobernanza. Es una orientación para localizar fuentes, no sustituye el texto oficial. Reutiliza las fuentes ya abiertas y la evidencia vigente del mismo encargo; revalida si cambian la fecha aplicable, la norma, el alcance o el estado del sistema.
3. Cita ley, artículo, fecha de entrada en vigor y enlace oficial junto a cada conclusión jurídica. Distingue obligación legal, decisión de negocio, trabajo técnico y evidencia pendiente; no conviertas una recomendación en obligación.
4. Identifica por finalidad quién decide el tratamiento, quién lo ejecuta por encargo y con qué base. No supongas que el consentimiento es la única base ni que habilita cualquier dato o finalidad.
5. Si una fuente o hecho indispensable no se puede verificar, marca esa conclusión `NO PROBADO`, explica qué falta y continúa el trabajo independiente. No inventes artículos, plazos, requisitos ni excepciones.

Deriva a validación jurídica una ambigüedad concreta o la aprobación exigida por el proyecto, indicando la pregunta y su efecto. Resuelve con evidencia las decisiones rutinarias; esta skill no sustituye una validación jurídica obligatoria. La aceptación de riesgo no permite omitir una obligación aplicable.

## Revisar el tratamiento real

- Sigue la recolección, uso, comunicación, descarga, conservación y eliminación. Identifica datos necesarios, finalidad, destinatarios, plazos y obligación de conservación; incluye archivos, enlaces, registros y respaldos cuando intervengan.
- Comprueba permisos e aislamiento entre empresas en backend, consultas, procesos y descargas. La interfaz o una opción configurable no sustituyen una restricción de acceso efectiva.
- Revisa la revocación de permisos, sesiones y enlaces; para consentimiento u otra habilitación, comprueba el efecto que corresponda a su base. No confundas retirar acceso con borrar datos ni elimines conservación obligatoria.
- Para derechos de titulares, sigue solicitud, verificación proporcional de identidad, respuesta y ejecución en los consumidores reales. Comprueba plazos, excepciones, bloqueo y evidencia según el régimen aplicable.
- Para proveedores, identifica encargo, subencargo, ubicación, transferencias, acceso y destino de los datos al terminar el servicio. Verifica condiciones y garantías concretas; no deduzcas una transferencia lícita de una marca comercial.
- Evalúa incidentes, evaluación de impacto y delegado solo cuando los hechos y la norma los hagan pertinentes. No traslades automáticamente reglas del RGPD ni requisitos de un modelo voluntario a todo tratamiento.

## Diseñar o implementar dentro del encargo

- Prefiere capacidades y controles existentes suficientes antes de crear endpoints, pantallas o abstracciones. La lógica de permisos y aislamiento se impone en backend.
- Complementa la privacidad con controles OWASP pertinentes, sin requerir un plugin instalado ni transformar el encargo en una auditoría general de seguridad.
- Distingue capacidad disponible de configuración aplicada: indica opción concreta, quién puede cambiarla, valor seguro, evidencia de su aplicación y pendiente de activación. Un control ausente o solo visual no acredita protección.
- Verifica proporcionalmente con código productivo y sus consumidores, según las pruebas autorizadas por el proyecto. Para accesos y aislamiento cubre casos permitidos, rechazados y límite; usa datos sintéticos y respeta las restricciones sobre servidores, ambientes y creación de tests.

## Entrega

Informa brevemente los hallazgos y sus límites. Reutiliza la documentación del proyecto para guardar, cuando el alcance lo requiera, requisito y fuente → control o procedimiento → consumidor → evidencia → pendiente y responsable.

Separa lo comprobado, la configuración necesaria por empresa y las obligaciones organizativas pendientes. Si falta una condición necesaria, no presentes el tratamiento como habilitado para uso real ni como conforme; señala `NO PROBADO` donde corresponda. Una mejora opcional no es por sí sola un bloqueo de cierre.
