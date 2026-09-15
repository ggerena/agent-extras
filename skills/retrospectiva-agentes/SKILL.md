---
name: retrospectiva-agentes
description: Analiza sesiones con agentes y propone mejoras verificables para reducir errores, contexto y llamadas repetidas. Usar ante retrospectivas o gasto excesivo de tokens; no revisa diffs.
---

# Retrospectiva de agentes

Convierte dificultades observadas en mejoras pequenas del entorno. Analiza fuentes primarias de la sesion indicada; si no se indica una, usa la actual. Una anécdota aislada no justifica una regla permanente.

## Analisis

1. Identifica los desvíos reales: errores, búsquedas repetidas, contexto cargado sin uso, llamadas costosas, bloqueos y correcciones del usuario.
2. Busca primero una capacidad ya existente en instrucciones, skills, scripts, configuración o CI. Una capacidad desconectada, difícil de descubrir o rota es el hallazgo; no la dupliques.
3. Clasifica cada mejora y detente en la primera solución suficiente:
   - **Mecánica:** patrón sintáctico, API prohibida, forma de importación, ubicación de archivos o invariante comprobable. Propón ampliar el lint, test, hook o CI existente más barato. No crees infraestructura solo porque un repositorio carece de ella.
   - **Navegación:** información difícil de encontrar. Propón un puntero corto con una condición precisa hacia la fuente vigente.
   - **Detalle condicional:** material usado solo en algunos casos. Muévelo detrás de una referencia cargada bajo demanda.
   - **Trabajo repetitivo:** transformación o consulta estable repetida. Propón un script o comando determinista solo si reduce trabajo futuro de forma demostrable.
   - **Criterio:** decisión que requiere intención o contexto. Conserva una instrucción breve en la fuente de verdad correspondiente.
4. Para ahorrar tokens, prioriza el contexto siempre cargado: elimina duplicados, datos fáciles de consultar, reglas obsoletas y frases que no cambian decisiones. Acorta primero los punteros y descripciones que se pagan en cada turno; no ocultes límites de seguridad, autorización o finalización.
5. Presenta solo mejoras respaldadas por evidencia, ordenadas por impacto esperado. Para cada una indica evidencia, cambio mínimo, destino y riesgo. Separa lo ya cubierto de lo nuevo.

## Límites

- La retrospectiva propone; no edita archivos, instala herramientas ni cambia CI salvo que el usuario también lo pida.
- No conviertas una preferencia puntual en regla universal.
- No prometas ahorro exacto de tokens sin una medición comparable. Si se editan instrucciones, informa al menos el cambio de palabras o caracteres del contenido siempre cargado.
- Prefiere una fuente de verdad y referencias bajo demanda sobre repetir la misma regla en varias skills.

## Cierre

Termina con un máximo de cinco mejoras: adoptar ahora, observar en próximas tareas o descartar. Si no hay evidencia suficiente, dilo y no agregues proceso.
