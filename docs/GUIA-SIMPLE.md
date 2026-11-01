# Guía simple

Para quien no programa o recién empieza a trabajar con Claude Code. No necesitas usar comandos: Claude hace los pasos y te pide tu OK antes de guardar.

## Dos principios clave

Todo lo demás se apoya en estas dos ideas:

1. **Evidencia antes que palabras.** Claude no da nada por hecho ni por terminado sin mostrar una prueba: el resultado de lo que ejecutó, una captura o el dato exacto de donde lo sacó. Lo que no pudo comprobar lo marca `NO PROBADO`, en vez de suponer que funciona. Ante un problema, primero encuentra la causa con pruebas y recién después propone corregirlo. Esto vale para cualquier trabajo, no solo para programar. Si una respuesta no trae su prueba, pídesela.
2. **Cambio mínimo.** Antes de construir algo nuevo, Claude busca si ya se resuelve con lo que existe: un ajuste de configuración, una función que la herramienta ya trae o algo ya hecho que se pueda reutilizar. Si hay que cambiar, toca solo lo necesario, en el lugar que corresponde. Mínimo no significa cambiar menos líneas ni dejar un parche a medias, sino resolver el problema completo dejando menos complejidad que mantener.

Las skills [diagnostico-con-evidencia](../skills/diagnostico-con-evidencia/SKILL.md) y [cambio-minimo](../skills/cambio-minimo/SKILL.md) aplican estas ideas paso a paso en trabajos de programación.

## Instalar

Sigue los tres pasos de [Integrarla en Claude Code con un mensaje](REGLAS-DE-TRABAJO.md#integrarla-en-claude-code-con-un-mensaje): abrir Claude Code, pegar un mensaje y responder lo que te pregunte.

## Actualizar

Cuando te avisen de cambios, o cada uno o dos meses, abre una sesión nueva de Claude Code (Local, carpeta Documentos) y pega este mensaje:

```text
Actualiza la biblioteca agent-extras que instalaste antes
(https://github.com/ggerena/agent-extras).

1. Descarga la versión nueva en la misma carpeta de antes.
2. Explícame en palabras simples qué cambió desde la última vez.
3. Compara mis reglas en ~/.claude/CLAUDE.md (o en el archivo que
   importe, si las tengo en una fuente única), las guías que copiaste
   en ~/.claude/ (VERIFICACION.md y DESARROLLOS-LARGOS.md, si las
   tengo) y mis skills en ~/.claude/skills/ con las versiones nuevas.
   No borres ni reemplaces lo que yo haya cambiado: si algo choca,
   muéstramelo y pregúntame. Si una skill que tengo instalada ya no
   está en la biblioteca, consérvala y avísame.
4. Revisa también la «Configuración recomendada» de
   docs/GUIA-SIMPLE.md para las herramientas que tengo y muéstrame
   las diferencias con mi configuración.
5. Antes de guardar, muéstrame qué vas a cambiar y espera mi OK.
```

## Configuración recomendada

Una subsección por herramienta. Usa solo la de las herramientas que tengas instaladas.

### Claude Code

Estos ajustes van en `~/.claude/settings.json`. Si el archivo ya existe, se agregan sin borrar ni cambiar lo demás.

```json
{
  "autoCompactWindow": 400000,
  "outputStyle": "Concise",
  "attribution": { "commit": "", "pr": "" },
  "pluginConfigs": {
    "cc-plugin-agents-md@builtin": {
      "options": { "instructionFiles": "claude-md-and-agents-md" }
    }
  }
}
```

- **Compactar a los 400.000 tokens (`autoCompactWindow`).** Cuando una conversación se alarga, Claude Code la resume para seguir trabajando (compactación automática). Si tu modelo admite más contexto (por ejemplo, 1 millón de tokens), resumir antes, a los 400.000, evita que crezca hasta el máximo. Como cada mensaje vuelve a leer toda la conversación, una más corta consume menos cuota por mensaje; el ahorro total depende de cómo trabajes, porque resumir también consume. Con modelos de 200.000 tokens o menos no cambia nada.
- **Respuestas concisas (`outputStyle`).** Claude va al resultado, sin rodeos. Si un día necesitas más detalle, basta con pedirlo.
- **Sin firma de IA en commits ni PR (`attribution`).** Claude Code no agrega su firma; así lo piden las reglas.
- **Leer también los `AGENTS.md` (`pluginConfigs`).** Claude lee los `CLAUDE.md` y además los `AGENTS.md` de cada proyecto, que es donde otras IAs, como Codex, buscan sus reglas. Así todas siguen las mismas.
- **Solo en Windows:** agregar `"env": { "PYTHONIOENCODING": "utf-8" }` para que tildes y eñes no salgan con símbolos raros cuando Claude usa Python.
- **Recordatorio al cerrar (opcional).** Pídele a Claude un hook `UserPromptSubmit` que, cuando escribas algo como «terminamos», «por hoy» o «gracias», le recuerde guardar lo aprendido en la sesión (decisiones, correcciones, pendientes) en tus reglas o en la documentación del proyecto, donde otras IAs también lo lean.

Más detalles en la [documentación de Claude Code](https://code.claude.com/docs/en/settings).

### Codex

En `~/.codex/config.toml`, `model_verbosity = "low"` pide respuestas más cortas y directas.

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
