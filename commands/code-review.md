---
description: "Revision de codigo de un PR o del diff de la rama actual contra develop."
---

# Code review

Revisa el codigo de un Pull Request o del diff de la rama actual contra `develop`.
No hagas cambios de codigo, commits, push ni merge.

## Pasos

1. **Elegibilidad.** Antes de revisar, descarta el PR si esta cerrado, es draft, es trivial/automatico y obviamente correcto, o ya tiene una revision tuya previa. Si aplica alguno, no continues.

2. **Contexto de guias.** Ubica las instrucciones relevantes: `AGENTS.md`, `CLAUDE.md`, `.opencode` o equivalentes de la raiz y de las carpetas modificadas. Lee solo las que apliquen al diff.

3. **Resumen del cambio.** Lee el diff con `gh pr diff <n>` si hay PR, o `git diff develop...HEAD` si revisas la rama actual. Escribe un resumen breve de que hace el cambio.

4. **Revision por dimensiones.** Revisa el cambio desde estos angulos:
   a. Adherencia a las instrucciones del proyecto.
   b. Bugs funcionales o regresiones evidentes.
   c. Contexto historico con `git blame` o historial de las lineas tocadas cuando ayude a validar una sospecha.
   d. PRs anteriores que tocaron los mismos archivos, si hay senales de comentarios repetibles.
   e. Comentarios existentes en el codigo que el cambio pueda contradecir.

5. **Confianza.** Para cada hallazgo, asigna confianza 0-100. Descarta hallazgos bajo 80. Evita nitpicks, falsos positivos y problemas preexistentes.

6. **Re-chequeo.** Si estas revisando un PR, vuelve a confirmar que no cambio a cerrado/draft y que no hay una revision tuya previa antes de comentar.

7. **Resultado.** Si corresponde, comenta en el PR con `gh pr comment`. Si no hay PR, entrega el resultado en el chat.

## Falsos positivos tipicos

- Problemas preexistentes fuera de las lineas modificadas.
- Nitpicks de estilo no pedidos.
- Cosas que ya atrapa el linter, typechecker, compilador o CI.
- Cambios de comportamiento claramente intencionales.
- Calidad general, cobertura o documentacion salvo que una guia del proyecto lo exija.

## Formato de salida

Si hay problemas:

```markdown
### Code review

Se encontraron N problemas:

1. <descripcion breve> (confianza: <80-100>)
<archivo:linea o enlace al PR>
<explicacion concreta>
```

Si no hay problemas:

```markdown
### Code review

Sin problemas. Se reviso en busca de bugs y cumplimiento de instrucciones del proyecto.
```

## Notas

- Para enlazar lineas en GitHub usa el sha completo del commit.
- En repos con subproyectos, corre el diff dentro del subproyecto correcto.
- Si usas OpenCode/GLM, trata GLM como OpenCode Go con `opencode-go/glm-5.2`. Si el entorno soporta subagentes, puedes paralelizar pasadas; si no, hazlas en secuencia.
