# Fuentes y referencias externas

El catálogo siguiente reúne enlaces públicos para trabajos especializados. Las revisiones identificadas permiten localizar las fuentes registradas el 2026-10-15; no afirman que sean las versiones más recientes ni ordenan instalar o actualizar nada. Consulta en origen las instrucciones, los recursos auxiliares, los permisos y la licencia antes de usar cada proyecto.

Esta biblioteca mantiene procedimientos propios en español. Las referencias de terceros se ofrecen como enlaces, sin copias de sus skills ni de sus recursos. La traducción local de la biblioteca no es una traducción oficial de esas fuentes ni una copia textual de sus versiones originales.

## Repositorios recomendados

Resumen de los repositorios de terceros que conviene conocer. El detalle de qué se tomó de cada uno está en las secciones siguientes. Antes de instalar algo, lee su README y su licencia.

### Base de esta biblioteca

| Repositorio | Autor | Para qué sirve | Relación con esta biblioteca | Licencia |
| --- | --- | --- | --- | --- |
| [kimun](https://github.com/lnds/kimun) | Eduardo Díaz (lnds) | Herramienta `km`: nota de salud del código, complejidad, duplicación, puntos críticos y alcance de un cambio. | Necesaria para `km-analyze` y las señales de `km` en `code-review`; se instala aparte. | MIT |
| [compliance-cl](https://github.com/Lelemon-studio/compliance-cl) | Lelemon Studio | Skill de auditoría y cumplimiento de las leyes chilenas 21.719 (datos personales) y 21.595 (delitos económicos). | Punto de partida de `proteccion-datos-chile`, con redacción propia. | MIT |
| [pstack-claude](https://github.com/michael-denyer/pstack-claude) | Michael Denyer, sobre el pstack de Lauren ([poteto](https://github.com/poteto)) | Flujos rigurosos para agentes: pruebas, verificación, impacto de un cambio y merge seguro. | Varias ideas en `diagnostico-con-evidencia`, `cambio-minimo`, `code-review` y `autodev`. | MIT |
| [ponytail](https://github.com/DietrichGebert/ponytail) | DietrichGebert | Hace que el agente escriba el mínimo código necesario. | Base de `cambio-minimo`. | MIT |
| [agent-skills](https://github.com/addyosmani/agent-skills) | Addy Osmani | Skills de ingeniería para agentes, entre ellas `frontend-ui-engineering`. | Recomendada para interfaces. | MIT |
| [skills](https://github.com/emilkowalski/skills) | Emil Kowalski | Skills de diseño de interfaces y animación, entre ellas `break-ui`. | Recomendada para UX/UI. | MIT |
| [skills](https://github.com/anthropics/skills) | Anthropic | Skills oficiales: diseño de interfaces (`frontend-design`), documentos, PDF, planillas y creación de skills. | `frontend-design` recomendada para UX/UI. | Indicada en cada skill |
| [skills](https://github.com/mattpocock/skills) | Matt Pocock | Skills de ingeniería tomadas de su propia configuración. | Idea del revisor con contexto nuevo en `code-review`. | MIT |
| [skills](https://github.com/cloudflare/skills) | Cloudflare | Skills de productos de Cloudflare, rendimiento web (`web-perf`) y seguridad. | Recomendadas solo si usas Cloudflare o para medir rendimiento web. | Apache-2.0 |

### Otros repositorios populares

Recomendados en una [publicación de neerajjj6785](https://x.com/neerajjj6785/status/2104895659157684597) (septiembre de 2026). Se revisaron por encima, leyendo su README; no se instalaron ni se probaron (`NO PROBADO`). Que sean populares no demuestra que sean mejores.

| Repositorio | Autor | Para qué sirve | Licencia |
| --- | --- | --- | --- |
| [superpowers](https://github.com/obra/superpowers) | Jesse Vincent (obra) | Metodología completa con skills de pruebas, revisión, depuración y planes. Gran parte ya está cubierta por las skills de esta biblioteca. | MIT |
| [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | nextlevelbuilder | Criterios de diseño para construir interfaces profesionales en varias plataformas. | MIT |
| [impeccable](https://github.com/pbakaus/impeccable) | Paul Bakaus | Vocabulario de diseño para pulir, criticar y auditar interfaces. | Apache-2.0 |
| [graphify](https://github.com/Graphify-Labs/graphify) | Graphify Labs | Convierte un repositorio y su documentación en un grafo de conocimiento consultable. | Apache-2.0 |
| [Understand-Anything](https://github.com/Egonex-AI/Understand-Anything) | Egonex AI | Convierte código en un grafo interactivo para entenderlo. | MIT |
| [archify](https://github.com/tt-a1i/archify) | tt-a1i | Convierte una idea, un plan o un repositorio en un diagrama interactivo. | Apache-2.0 |
| [caveman](https://github.com/JuliusBrussee/caveman) | Julius Brussee | Respuestas más breves del agente para gastar menos tokens. | Apache-2.0 |
| [awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) | Composio | Directorio de skills y recursos para Claude. | Apache-2.0 según su README; cada skill enlazada tiene su propia licencia |

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

### Diseño de interfaces (UX/UI)

Selección de la tabla anterior, más `break-ui` y `frontend-design`, para quien diseña, construye o revisa pantallas. Instala cada una desde su fuente con la carpeta completa.

| Skill | Para qué sirve | Requisitos y licencia |
| --- | --- | --- |
| [break-ui](https://github.com/emilkowalski/skills/tree/2d228630ba1446365f614a108cb8252f1feda202/skills/break-ui) | Revisa una pantalla con datos extremos realistas (nombres muy largos, listas vacías, textos en otros idiomas) e informa qué se rompe y cómo arreglarlo. La versión original además crea datos de prueba y agrega un selector en la pantalla para verlos; si solo quieres el informe, pídeselo así. | Proyecto con interfaz web. MIT. |
| [frontend-ui-engineering](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/frontend-ui-engineering/SKILL.md) | Guía para construir interfaces accesibles, adaptables a celular y con aspecto profesional. | Proyecto con interfaz web. MIT. |
| [web-perf](https://github.com/cloudflare/skills/blob/be68fd8db614c22ed6f4d21a439a641e4904eb94/skills/web-perf/SKILL.md) | Mide qué tan rápido carga una página y detecta problemas de rendimiento y accesibilidad. | Chrome DevTools MCP. Apache-2.0. |
| [react-best-practices](https://github.com/vercel-labs/agent-skills/blob/063bee94c3f4df8453406c830b0a7df0f2860278/skills/react-best-practices/SKILL.md) | Buenas prácticas de rendimiento en React y Next.js. | Solo para proyectos con React o Next.js. MIT. |
| [frontend-design](https://github.com/anthropics/skills/tree/41bbe19d1a1a7eaab5e7bb9050a417e5c6cffc8f/skills/frontend-design) (Anthropic) | Ayuda a elegir una dirección visual propia (colores, tipografía, diagramación) para que la interfaz no se vea como una plantilla genérica. | Proyecto con interfaz web. Apache-2.0. |

Las licencias y la autoría corresponden a cada fuente. Los enlaces no convierten esos proyectos en dependencias instaladas ni conceden permisos adicionales sobre sus herramientas o sobre el proyecto del usuario. Una adaptación local puede diferir de la fuente citada; comprueba ambas antes de reemplazar instrucciones existentes.

## Ideas incorporadas a procedimientos propios

Estas ideas se contrastaron con procedimientos existentes y se incorporaron de forma selectiva. Eso no atribuye a los proyectos citados la autoría completa de las skills propias ni implica instalar sus bibliotecas completas.

| Idea | Fuente original | Destino |
| --- | --- | --- |
| Comparar mediciones, trabajo real, errores y variación | [pstack benchmark-checklist](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/benchmark-checklist/SKILL.md) | `diagnostico-con-evidencia` |
| Considerar una guía de privacidad chilena como punto de partida y contrastar sus requisitos con fuentes oficiales | [Lelemon Studio, compliance-cl](https://github.com/Lelemon-studio/compliance-cl/tree/4972a821ff98caf777e809baf468d72517616ada), licencia MIT | `proteccion-datos-chile`, redacción propia sin copiar la skill externa; las conclusiones legales se fundan en las fuentes oficiales enlazadas en su mapa legal |
| Comprobar un supuesto crítico y sus consumidores indirectos | [pstack blast-radius](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/blast-radius/SKILL.md) | `cambio-minimo`, `code-review` |
| Revisar el costo de revertir un cambio y los errores silenciados | [Warp merge-risk](https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/merge-risk/SKILL.md), licencia MIT | `code-review`, como criterios de revisión sin puntaje de riesgo |
| Probar una pantalla con datos extremos realistas y reportar qué se rompe | [Emil Kowalski, break-ui](https://github.com/emilkowalski/skills/tree/2d228630ba1446365f614a108cb8252f1feda202/skills/break-ui), licencia MIT | Instalada adaptada fuera de esta biblioteca, en solo lectura por defecto |
| Limitar las rondas de revisión entre agentes cuando no convergen | [Addy Osmani, «How the Claude Code team does code review»](https://x.com/addyosmani/status/2114604912520921136) | `cerrar-pr`, `autodev`, con tope de tres rondas y aviso al usuario |
| Una prueba de regresión debe fallar por el motivo previsto | [pstack tdd](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/tdd/SKILL.md) | `diagnostico-con-evidencia`, `code-review`, según la política de pruebas del usuario |
| Una guía reutilizable para comprobar el comportamiento afectado | [create-verification-skill](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/create-verification-skill/SKILL.md), [maintain-verification-skill](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/maintain-verification-skill/SKILL.md) | `autodev`, sin iniciar servidores ni escribir en un encargo de solo lectura |
| Resolver con el menor cambio que deba mantenerse, reutilizando y evitando la sobreingeniería | [DietrichGebert, Ponytail](https://github.com/dietrichgebert/ponytail), licencia MIT | `cambio-minimo`, redacción propia; se revisó entre agosto y septiembre de 2026 y no se instaló |
| El revisor independiente parte con contexto nuevo, sin heredar la conversación | [Matt Pocock, mattpocock/skills#1341](https://github.com/mattpocock/skills/pull/1341), licencia MIT | `code-review` |
| Revisar textos, estados vacíos y complejidad innecesaria en cambios de interfaz | [Nate Berkopec, publicación sobre proyectos hechos con IA](https://x.com/nateberkopec/status/2115263368064045136) | `code-review`, sección de cambios de interfaz |
| Medir salud del código, duplicación y archivos que suelen cambiar juntos | [Kimün (`km`), de Eduardo Díaz](https://github.com/lnds/kimun), licencia MIT | `km-analyze` y señales de `km` en `code-review`; la herramienta se instala aparte |
| Pedir evidencia, encargar con objetivo y verificación, y revisar las reglas al cambiar de modelo | [Addy Osmani, «You're probably overprompting Claude»](https://x.com/addyosmani/status/2115688494865465370) | [Reglas de trabajo](REGLAS-DE-TRABAJO.md) |
| Merge expresamente autorizado, vinculado al último commit verificado | [pstack merge safety](https://github.com/michael-denyer/pstack-claude/blob/94f5ce95abe8a9dec976967d79941f631cf477cd/plugins/pstack/skills/poteto-mode/references/merge-safety.md), [manual de GitHub CLI](https://cli.github.com/manual/gh_pr_merge) | Política personal o del proyecto, fuera de esta biblioteca; `cerrar-pr` nunca hace merge |

Las filas de `pstack` enlazan [pstack-claude](https://github.com/michael-denyer/pstack-claude) de Michael Denyer (MIT), versión para Claude Code y otros clientes del pstack original de Lauren ([poteto](https://github.com/poteto)).

La discusión pública que motivó comparar las guías de verificación es [la publicación de Daniel Lockyer](https://x.com/DanielLockyer/status/2110035356737232942). El porcentaje que menciona es una experiencia personal, no una medición de estas skills.

Los demás procedimientos propios y las plantillas configurables se consolidaron desde instrucciones locales. No se estableció una skill externa original para ellos; no deduzcas autoría a partir de nombres o comportamientos parecidos. Las notas históricas también mencionan una revisión general de mattpocock/skills como influencia sobre la simplificación, sin identificar archivos fuente exactos; no se le atribuye una relación más precisa.

## Referencias revisadas sin incorporar

Se leyeron y compararon con estas skills, pero no se copiaron ni instalaron: sus ideas útiles ya estaban cubiertas o chocaban con las reglas de trabajo. Se citan como lectura recomendada.

| Referencia | Autor | Por qué no se incorporó |
| --- | --- | --- |
| [ub-mode](https://github.com/unclebob/ub-mode) | Robert C. Martin («Uncle Bob», autor de *Clean Code*) | Deriva de pstack, ya citado. Coincide con `cambio-minimo` y la búsqueda de la causa raíz; exige TDD y pruebas de mutación obligatorias, push a la rama principal y rediseños, que chocan con las reglas de trabajo. Sin licencia visible al revisarlo. |
| [crapper](https://github.com/unclebob/crapper), [dryer](https://github.com/unclebob/dryer), [mutator](https://github.com/unclebob/mutator) | Robert C. Martin | Miden riesgo por complejidad y cobertura, duplicación y calidad de las pruebas. `km-analyze` cubre complejidad y duplicación; la mutación queda como opción para reglas críticas. Licencia 0BSD. |
| [swarm-forge](https://github.com/unclebob/swarm-forge) | Robert C. Martin | Coordina varios agentes con worktrees y traspasos auditables; depende de herramientas Unix y permite más de lo que aceptan las reglas de trabajo. |
| [«Becoming a better writer»](https://newsletter.pragmaticengineer.com/p/becoming-a-better-writer), de The Pragmatic Engineer | Gergely Orosz | Tácticas para escribir mejor sin depender del texto generado por IA: editar, usar frases cortas y pedir comentarios concretos. Lo aplicable a los agentes ya está en las [reglas de trabajo](REGLAS-DE-TRABAJO.md) (respuestas cortas, frases simples y revisión por otro modelo de documentos para terceros); el resto es hábito personal. |

## Recursos administrados por aplicaciones

La interfaz utilizada por `revisar-errores-slack` se contrastó con la documentación de [conversaciones](https://github.com/shaharia-lab/slackcli/blob/v0.15.0/docs/user-guide/conversations.md) y [uso desde scripts](https://github.com/shaharia-lab/slackcli/blob/v0.15.0/docs/user-guide/scripting.md) de SlackCLI v0.15.0, proyecto de [Shaharia Lab](https://github.com/shaharia-lab/slackcli). La skill tiene redacción propia; no incluye copias de documentación ni configuración privada.

Las skills suministradas por un cliente o sincronizadas por una aplicación se recuperan mediante esa aplicación o su complemento. Sus dependencias internas, derechos de distribución y versiones dependen del proveedor. Esto incluye control del navegador o del equipo, documentos, investigación, importación de memoria, informes matinales y administración de skills. No sustituyas uno de esos paquetes por otro con nombre parecido afirmando que es el mismo.
