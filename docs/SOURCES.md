# Fuentes y referencias externas

El catálogo siguiente reúne enlaces públicos para trabajos especializados. Las revisiones identificadas permiten localizar las fuentes registradas el 2026-10-15; no afirman que sean las versiones más recientes ni ordenan instalar o actualizar nada. Consulta en origen las instrucciones, los recursos auxiliares, los permisos y la licencia antes de usar cada proyecto.

Esta biblioteca mantiene procedimientos propios en español. Las referencias de terceros se ofrecen como enlaces, sin copias de sus skills ni de sus recursos. La traducción local de la biblioteca no es una traducción oficial de esas fuentes ni una copia textual de sus versiones originales.

## Skills especializadas

| Referencia | Fuente pública | Licencia indicada en la referencia |
| --- | --- | --- |
| Cloudflare: selección de productos y arquitectura | [cloudflare](https://github.com/cloudflare/skills/blob/9177f9a0bafc1ab61a0dae8dca57a8eb4d9f636d/skills/cloudflare/SKILL.md) | Apache-2.0 |
| Envío y recepción de correo con Cloudflare | [cloudflare-email-service](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/cloudflare-email-service/SKILL.md) | Apache-2.0 |
| Cloudflare One y acceso de confianza cero | [cloudflare-one](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/cloudflare-one/SKILL.md) | Apache-2.0 |
| Durable Objects | [durable-objects](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/durable-objects/SKILL.md) | Apache-2.0 |
| Rendimiento de carga web | [web-perf](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/web-perf/SKILL.md) | Apache-2.0 |
| Buenas prácticas de Workers | [workers-best-practices](https://github.com/cloudflare/skills/blob/426c3b406b3d3ef2ad3ca9bc2d3f41dd5be32ba0/skills/workers-best-practices/SKILL.md) | Apache-2.0 |
| Wrangler | [wrangler](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/wrangler/SKILL.md) | Apache-2.0 |
| Auditoría de seguridad | [security-audit](https://github.com/cloudflare/security-audit-skill/blob/c1c8a8c1471069fb0e188eeaff69b8e8db6564a8/skills/security-audit/SKILL.md) | MIT |
| Ingeniería de interfaces | [frontend-ui-engineering](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/frontend-ui-engineering/SKILL.md) | MIT |
| Seguridad OWASP | [owasp-security](https://github.com/agamm/claude-code-owasp/blob/8ac7965caa212b4a850aff8d3df0081ab3fa9eed/.claude/skills/owasp-security/SKILL.md) | MIT |
| Rendimiento de React y Next.js | [react-best-practices](https://github.com/vercel-labs/agent-skills/blob/063bee94c3f4df8453406c830b0a7df0f2860278/skills/react-best-practices/SKILL.md) | MIT, declarada en los metadatos de la skill |
| Enseñanza | [teach](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/productivity/teach/SKILL.md) | MIT |
| Funciones de IA con TypeSafe | [typesafe-ai](https://github.com/typesafe-ai/skills/blob/65a39f393687675ce170e6094757de20370365b9/skills/typesafe-ai/SKILL.md) | MIT |

Las licencias y la autoría corresponden a cada fuente. Los enlaces no convierten esos proyectos en dependencias instaladas ni conceden permisos adicionales sobre sus herramientas o sobre el proyecto del usuario. Una adaptación local puede diferir de la fuente citada; comprueba ambas antes de reemplazar instrucciones existentes.

## Ideas incorporadas a procedimientos propios

Estas ideas se contrastaron con procedimientos existentes y se incorporaron de forma selectiva. Eso no atribuye a los proyectos citados la autoría completa de las skills propias ni implica instalar sus bibliotecas completas.

| Idea | Fuente original | Destino |
| --- | --- | --- |
| Comparar mediciones, trabajo real, errores y variación | [pstack benchmark-checklist](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/benchmark-checklist/SKILL.md) | `diagnostico-con-evidencia` |
| Considerar una guía de privacidad chilena como punto de partida y contrastar sus requisitos con fuentes oficiales | [Lelemon Studio, compliance-cl](https://github.com/Lelemon-studio/compliance-cl/tree/4972a821ff98caf777e809baf468d72517616ada), licencia MIT | `proteccion-datos-chile`, redacción propia sin copiar la skill externa; las conclusiones legales se fundan en las fuentes oficiales enlazadas en su mapa legal |
| Comprobar un supuesto crítico y sus consumidores indirectos | [pstack blast-radius](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/blast-radius/SKILL.md) | `cambio-minimo`, `code-review` |
| Una prueba de regresión debe fallar por el motivo previsto | [pstack tdd](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/tdd/SKILL.md) | `diagnostico-con-evidencia`, `code-review`, según la política de pruebas del usuario |
| Una guía reutilizable para comprobar el comportamiento afectado | [create-verification-skill](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/create-verification-skill/SKILL.md), [maintain-verification-skill](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/maintain-verification-skill/SKILL.md) | `autodev`, sin iniciar servidores ni escribir en un encargo de solo lectura |
| Merge expresamente autorizado, vinculado al último commit verificado | [pstack merge safety](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/poteto-mode/references/merge-safety.md), [manual de GitHub CLI](https://cli.github.com/manual/gh_pr_merge) | Política personal o del proyecto, fuera de esta biblioteca; `cerrar-pr` nunca hace merge |

La discusión pública que motivó comparar las guías de verificación es [la publicación de Daniel Lockyer](https://x.com/DanielLockyer/status/2110035356737232942). El porcentaje que menciona es una experiencia personal, no una medición de estas skills.

Los demás procedimientos propios y las plantillas configurables se consolidaron desde instrucciones locales. No se estableció una skill externa original para ellos; no deduzcas autoría a partir de nombres o comportamientos parecidos. Las notas históricas mencionan Ponytail y una revisión de mattpocock/skills como influencias sobre la simplificación, pero no identifican archivos fuente exactos para esos cambios; no se les atribuye una relación más precisa.

## Recursos administrados por aplicaciones

La interfaz utilizada por `revisar-errores-slack` se contrastó con la documentación de [conversaciones](https://github.com/shaharia-lab/slackcli/blob/v0.15.0/docs/user-guide/conversations.md) y [uso desde scripts](https://github.com/shaharia-lab/slackcli/blob/v0.15.0/docs/user-guide/scripting.md) de SlackCLI v0.15.0, proyecto de [Shaharia Lab](https://github.com/shaharia-lab/slackcli). La skill tiene redacción propia; no incluye copias de documentación ni configuración privada.

Las skills suministradas por un cliente o sincronizadas por una aplicación se recuperan mediante esa aplicación o su complemento. Sus dependencias internas, derechos de distribución y versiones dependen del proveedor. Esto incluye control del navegador o del equipo, documentos, investigación, importación de memoria, informes matinales y administración de skills. No sustituyas uno de esos paquetes por otro con nombre parecido afirmando que es el mismo.
