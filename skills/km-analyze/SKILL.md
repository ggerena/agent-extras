---
name: km-analyze
description: Analiza la salud de un repositorio con km, incluyendo complejidad, mantenibilidad, duplicación, puntos críticos, acoplamiento temporal y riesgo de concentración de conocimiento. Usar cuando se pida medir calidad o deuda técnica, encontrar archivos problemáticos, duplicados, puntos críticos o dependencias ocultas; no usar para revisar funcionalmente un PR ni para explicar un repositorio leyendo solo su README.
---

# Análisis de métricas de código con km

Usa la herramienta de línea de comandos `km` para analizar un repositorio en varias dimensiones.
Comprueba que esté disponible en el entorno antes de ejecutar el análisis.

## Comandos disponibles

Ejecuta los comandos desde el intérprete disponible en el entorno actual; los ejemplos funcionan
en Bash y PowerShell. Usa siempre `--format json` para obtener salida procesable por herramientas.

### Líneas de código
```bash
km loc [PATH] --format json
```
Desglose por lenguaje: archivos, líneas vacías, líneas de comentarios y líneas de código.

### Puntuación de salud del código
```bash
km score [PATH] --format json
km score [PATH] --format json --model legacy
```
Calificación global de A++ a F--. El modelo predeterminado (`cogcom`) usa cinco dimensiones:
complejidad cognitiva, duplicación, sangría, esfuerzo de Halstead y tamaño del archivo. El modelo
anterior (`--model legacy`) usa seis: índice de mantenibilidad, complejidad ciclomática,
duplicación, sangría, esfuerzo de Halstead y tamaño del archivo.

### Diferencia de puntuación (requiere Git)
```bash
km score diff [PATH] --format short --git-ref HEAD~1
```
Compara la puntuación actual de salud del código con una referencia de Git. Muestra las diferencias
por dimensión.

### Complejidad cognitiva
```bash
km cogcom [PATH] --format json --top 20
```
Método de SonarSource (2017). Mide la dificultad de entender el código y penaliza el anidamiento profundo.

### Complejidad ciclomática
```bash
km cycom [PATH] --format json --top 20
```
Complejidad por archivo y función. Los valores altos indican código difícil de probar.

### Índice de mantenibilidad
```bash
km miv [PATH] --format json --top 20
```
Variante de Verifysoft que pondera los comentarios. Los valores inferiores a 65 indican dificultad
de mantenimiento.

### Complejidad de Halstead
```bash
km hal [PATH] --format json --top 20 --sort-by effort
```
Esfuerzo, volumen y errores estimados por archivo.

### Complejidad de sangría
```bash
km indent [PATH] --format json
```
Desviación estándar de la profundidad de sangría: los valores altos sugieren código muy anidado.

### Código duplicado
```bash
km dups [PATH] --format json --report
```
Bloques duplicados en el proyecto.

### Puntos críticos (requiere Git)
```bash
km hotspots [PATH] --format json --top 20
```
Archivos que cambian con frecuencia y tienen alta complejidad: principales candidatos a refactorización.

### Distribución del conocimiento del código (requiere Git)
```bash
km knowledge [PATH] --format json --top 20
```
Riesgo por concentración del conocimiento en pocas personas para cada archivo, mediante el análisis
de `git blame`.

### Acoplamiento temporal (requiere Git)
```bash
km tc [PATH] --format json --top 20
```
Archivos que cambian juntos en los commits: posibles dependencias ocultas.

## Flujo de análisis

1. Empieza con `km score` para obtener la calificación global de salud.
2. Ejecuta `km loc` para conocer el tamaño del proyecto y el desglose por lenguaje.
3. Usa `km cogcom`, `km cycom` y `km miv` para encontrar los archivos más complejos o difíciles de mantener.
4. Ejecuta `km hotspots` para localizar archivos de alto riesgo que cambian con frecuencia.
5. Revisa `km dups` para detectar oportunidades de reducir duplicación.
6. Opcionalmente, ejecuta `km knowledge` y `km tc` para analizar riesgos del equipo y la arquitectura.
7. Usa `km score diff --git-ref HEAD~N` para seguir las variaciones de puntuación en el tiempo.

## Formato de entrega

Prepara un informe estructurado con:

- **Panorama general:** tamaño del proyecto, lenguajes y calificación global.
- **Salud del código:** puntuación desglosada por dimensión.
- **Puntos críticos de complejidad:** archivos con mayor complejidad.
- **Mantenibilidad:** archivos más difíciles de mantener.
- **Hallazgos principales:** patrones y riesgos destacados.
- **Recomendaciones:** sugerencias priorizadas y aplicables.

Cita nombres concretos de archivos y valores de las métricas. Sé breve sin omitir información pertinente.
