# Guía simple

Para quien no programa o recién empieza a trabajar con Claude Code. No necesitas usar comandos: Claude hace los pasos y te pide tu OK antes de guardar.

## Instalar

Sigue los tres pasos de [Integrarla en Claude Code con un mensaje](REGLAS-DE-TRABAJO.md#integrarla-en-claude-code-con-un-mensaje): abrir Claude Code, pegar un mensaje y responder lo que te pregunte.

## Actualizar

Cuando te avisen de cambios, o cada uno o dos meses, abre una sesión nueva de Claude Code (Local, carpeta Documentos) y pega este mensaje:

```text
Actualiza la biblioteca agent-extras que instalaste antes
(https://github.com/ggerena/agent-extras).

1. Descarga la versión nueva en la misma carpeta de antes.
2. Explícame en palabras simples qué cambió desde la última vez.
3. Compara mis reglas en ~/.claude/CLAUDE.md, las guías que copiaste
   en ~/.claude/ (VERIFICACION.md y DESARROLLOS-LARGOS.md, si las tengo) y mis skills en ~/.claude/skills/
   con las versiones nuevas. No borres ni reemplaces
   lo que yo haya cambiado: si algo choca, muéstramelo y pregúntame.
4. Antes de guardar, muéstrame qué vas a cambiar y espera mi OK.
```

## Configuración recomendada de Claude Code

Compactar la conversación a los 400.000 tokens. Cuando una conversación se alarga, Claude Code la resume para seguir trabajando (compactación automática). Si tu modelo admite más contexto (por ejemplo, 1 millón de tokens), resumir antes, a los 400.000, evita que crezca hasta el máximo. Como cada mensaje vuelve a leer toda la conversación, una más corta consume menos cuota por mensaje; el ahorro total depende de cómo trabajes, porque resumir también consume. Se configura en `~/.claude/settings.json`:

```json
{
  "autoCompactWindow": 400000
}
```

Si el archivo ya existe, se agrega solo esa línea, sin borrar lo demás. Con modelos de 200.000 tokens o menos no cambia nada. Más detalles en la [documentación de Claude Code](https://code.claude.com/docs/en/settings).

## Segunda opinión de otra empresa

Las reglas piden que un modelo de otra empresa revise los trabajos importantes antes de darlos por listos: un modelo de la misma empresa suele pasar por alto los mismos errores. Por ejemplo, si usas Claude, puedes instalar Codex (de OpenAI, con una cuenta de ChatGPT). Pídele a Claude que te ayude a instalarlo, revisa antes si tiene costo y dile que quede escrito en tus reglas como revisor: así ya cuenta con tu autorización para enviarle los trabajos a revisar. Sin él, Claude te avisa que no hay revisor externo y usa una sesión separada como respaldo; ese respaldo no sirve para documentos o recomendaciones que vayan a otras personas, que siempre necesitan un modelo de otra empresa.

## Qué instalar según tu rol

Las reglas de trabajo sirven a todos. Las skills conviene instalarlas solo si las vas a usar.

| Rol | Skills recomendadas |
| --- | --- |
| Cualquier persona | [mira](../skills/mira/SKILL.md), para entender de qué se trata un proyecto leyendo solo su descripción. |
| Diseño de pantallas (UX/UI) | Las de la sección [Diseño de interfaces](SOURCES.md#diseño-de-interfaces-uxui): `break-ui`, `frontend-design` y `frontend-ui-engineering`. `web-perf` solo si alguien te configura Chrome DevTools MCP. |
| Gestión o coordinación | [crear-spec](../skills/crear-spec/SKILL.md) para preparar planes que otra persona o IA implementa, [daily](../skills/daily/SKILL.md) para resumir lo hecho en un periodo y [retrospectiva-agentes](../skills/retrospectiva-agentes/SKILL.md) para mejorar cómo se trabaja con la IA. |
| Desarrollo | Los siete flujos principales del [README](../README.md), más [km-analyze](../skills/km-analyze/SKILL.md) para medir la calidad del código y [proteccion-datos-chile](../skills/proteccion-datos-chile/SKILL.md) si el sistema trata datos personales. |

Las demás skills dependen de herramientas concretas (Codex, Grok, WhatsApp, Slack) o de Windows; revisa sus requisitos en [PORTABILITY.md](PORTABILITY.md) antes de instalarlas.

## Glosario

| Término | Qué significa |
| --- | --- |
| Repositorio (repo) | Carpeta de un proyecto con todo su historial de cambios, guardada por ejemplo en GitHub. |
| Skill | Archivo de instrucciones que le enseña a Claude un procedimiento. |
| `CLAUDE.md` | Archivo donde Claude Code lee tus instrucciones permanentes. |
| Commit | Un cambio guardado en el historial, con una descripción. |
| Rama (branch) | Copia paralela del proyecto para trabajar sin tocar la versión principal. |
| `develop` y `main` | Ramas permanentes: `develop` junta lo terminado y `main` (o `master`) es la versión de producción. |
| Hotfix | Corrección urgente de producción, que después se lleva también a `develop`. |
| Push | Subir los commits a GitHub. |
| PR (pull request) | Solicitud para sumar los cambios de una rama a la versión principal; ahí se revisan. Un PR borrador aún no está listo. |
| Merge | Sumar definitivamente los cambios de un PR a la versión principal. |
| Revisión de código | Otra persona o un modelo de otra empresa lee los cambios buscando errores. |
| Test (prueba) | Programa que comprueba automáticamente que algo funciona. |
| Ambientes (Dev, QA, Prod) | Copias del sistema para desarrollo, para pruebas y la de producción, que usan los clientes. |
| Desplegar | Publicar una versión en un ambiente. |
| `NO PROBADO` | Marca que indica que algo no se pudo comprobar. |
| MCP | Conector que le da a Claude acceso a otra herramienta, por ejemplo Chrome. |
