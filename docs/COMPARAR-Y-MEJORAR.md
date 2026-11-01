# Comparar con tu forma de trabajo y proponer mejoras

Para quien ya trabaja con agentes (Claude Code, Codex u otros) y quiere comparar su forma actual de trabajar con esta biblioteca. Puede salir algo para adoptar, algo para proponer al repositorio o ambas cosas. No hace falta instalar nada antes.

## 1. Comparar

Abre una sesión nueva de tu agente en modo local, en una carpeta de trabajo segura (no Descargas), y pega este mensaje:

```text
Quiero comparar mi forma actual de trabajar con agentes con la
biblioteca https://github.com/ggerena/agent-extras. Es solo una
comparación: no cambies ninguna regla, skill ni configuración mía.
La única excepción es el informe del punto 5.

1. Descarga el repositorio en una carpeta temporal y lee README.md,
   docs/REGLAS-DE-TRABAJO.md, docs/VERIFICACION.md,
   docs/DESARROLLOS-LARGOS.md y la sección «Configuración recomendada»
   de docs/GUIA-SIMPLE.md. Revisa también el catálogo de skills.
2. Reúne mis instrucciones actuales: mis reglas globales (por ejemplo
   ~/.claude/CLAUDE.md y los archivos que importe, o ~/.codex/AGENTS.md),
   mis skills instaladas y la configuración de mis herramientas.
   No copies ni muestres secretos, contraseñas, tokens ni datos de
   clientes.
3. Pon especial atención a los dos principios de la biblioteca:
   evidencia y cambio mínimo.
4. Arma estas cuatro listas, en palabras simples y sin datos
   personales, de clientes, credenciales ni rutas de mi equipo:
   a. Lo que la biblioteca tiene y yo no, y si me conviene adoptarlo.
   b. Lo que yo tengo y la biblioteca no, y si conviene proponerlo
      (en versión genérica, sin datos de un proyecto concreto).
   c. Contradicciones entre ambas, cuál conviene y por qué.
   d. Lo que ya es equivalente.
5. Guarda el informe en un archivo .md en la carpeta de trabajo y
   dime dónde quedó.
6. Si tienes acceso a un modelo de otra empresa sin costo adicional,
   pídele que revise el informe en solo lectura antes de
   entregármelo. Si se cobra aparte, pregúntame antes y dime el costo
   estimado. Si no tienes, dímelo.
7. No adoptes ni cambies nada. Después decido qué adopto y qué
   propongo.
```

## 2. Adoptar lo que te sirva

Con el informe en mano, pide a tu agente que adopte solo los puntos que elijas, mostrándote antes qué va a cambiar y esperando tu OK. Si nunca has instalado la biblioteca, sigue la [guía simple](GUIA-SIMPLE.md).

## 3. Proponer una mejora al repositorio

Si encuentras algo que la biblioteca debería tener, corregir o quitar:

- **Con cuenta de GitHub:** abre un [issue](https://github.com/ggerena/agent-extras/issues) con la propuesta y el motivo, o un pull request desde tu copia (fork) del repositorio.
- **Sin GitHub:** envía el informe o la propuesta a quien mantiene la biblioteca.

Toda propuesta debe ser genérica: sin datos personales, de clientes, credenciales ni rutas de tu equipo. Si viene de una fuente externa, cítala con su enlace para registrarla en [SOURCES.md](SOURCES.md). Cada cambio aceptado lo revisa antes un modelo de otra empresa, como pide la [plantilla de reglas](REGLAS-DE-TRABAJO.md).
