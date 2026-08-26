---
name: km-analyze
description: Analiza la salud de un repositorio con km, incluyendo complejidad, mantenibilidad, duplicacion, hotspots, acoplamiento temporal y riesgo de conocimiento. Usar cuando se pida medir calidad o deuda tecnica, encontrar archivos problematicos, duplicados, hotspots o dependencias ocultas; no usar para revisar funcionalmente un PR ni para explicar un repositorio leyendo solo su README.
---

# km — Code Metrics Analysis Skill

You have access to the `km` CLI tool for comprehensive code analysis. Use it to analyze repositories across multiple dimensions.

## Available Commands

Run these via the Bash tool. Always use `--json` for machine-readable output.

### Lines of Code
```bash
km loc [PATH] --json
```
Language breakdown: files, blank lines, comment lines, code lines.

### Code Health Score
```bash
km score [PATH] --json
km score [PATH] --json --model legacy
```
Overall grade (A++ to F--). Default model (cogcom): 5 dimensions — cognitive complexity, duplication, indentation, Halstead effort, file size. Legacy model (--model legacy): 6 dimensions — MI, cyclomatic complexity, duplication, indentation, Halstead effort, file size.

### Score Diff (requires git)
```bash
km score diff [PATH] --json --git-ref HEAD~1
```
Compare current code health score against a git ref. Shows per-dimension deltas.

### Cognitive Complexity
```bash
km cogcom [PATH] --json --top 20
```
SonarSource method (2017). Measures how difficult code is to understand, penalizing deep nesting.

### Cyclomatic Complexity
```bash
km cycom [PATH] --json --top 20
```
Per-file and per-function complexity. High values indicate hard-to-test code.

### Maintainability Index
```bash
km miv [PATH] --json --top 20
```
Verifysoft variant (with comment weight). Values below 65 are hard to maintain.

### Halstead Complexity
```bash
km hal [PATH] --json --top 20 --sort-by effort
```
Effort, volume, and estimated bugs per file.

### Indentation Complexity
```bash
km indent [PATH] --json
```
Indentation depth stddev — high values suggest deeply nested code.

### Duplicate Code
```bash
km dups [PATH] --json --report
```
Duplicate blocks across the project.

### Hotspots (requires git)
```bash
km hotspots [PATH] --json --top 20
```
Files that change frequently AND have high complexity — top refactoring targets.

### Code Ownership (requires git)
```bash
km knowledge [PATH] --json --top 20
```
Bus factor risk per file via git blame analysis.

### Temporal Coupling (requires git)
```bash
km tc [PATH] --json --top 20
```
Files that change together in commits — hidden dependencies.

## Analysis Workflow

1. Start with `km score` for the overall health grade
2. Run `km loc` for project size and language breakdown
3. Use `km cogcom`, `km cycom` and `km miv` to find the most complex/unmaintainable files
4. Run `km hotspots` to find high-risk change-prone files
5. Check `km dups` for code duplication opportunities
6. Optionally run `km knowledge` and `km tc` for team/architecture insights
7. Use `km score diff --git-ref HEAD~N` to track score changes over time

## Output Format

Produce a structured report with:
- **Overview**: Project size, languages, overall grade
- **Code Health**: Score breakdown by dimension
- **Complexity Hotspots**: Worst files by complexity
- **Maintainability**: Files hardest to maintain
- **Key Findings**: Notable patterns and risks
- **Recommendations**: Prioritized, actionable suggestions

Reference specific file names and metric values. Be concise but thorough.
