Actúa como revisor de código senior.

Quiero que compares mi rama actual contra `develop` y me des feedback de code review. No hagas cambios de código, no commits, no push.

Pasos que debes ejecutar:
1. Identifica rama actual y estado del working tree.
2. Compara `develop...HEAD` (3 puntos), no `develop..HEAD`.
3. Muestra archivos cambiados y analiza el diff completo.
4. Evalúa riesgos de:
   - bugs funcionales
   - regresiones de UX
   - inconsistencias de API/props
   - deuda técnica introducida
5. Evalúa calidad de código para asegurar que:
   - código duplicado no debe aumentar (DRY): detectar copy-paste o lógica repetida que debería extraerse
   - funciones/componentes demasiado largos que deberían dividirse
   - nombres de variables/funciones poco claros
   - constantes hardcodeadas que deberían centralizarse
   - manejo de errores ausente o insuficiente
   - complejidad innecesaria (hay forma más simple de lograr lo mismo?)
   - patrones inconsistentes con el resto del codebase
6. Si puedes, corre build para validar compilación.
7. Omite tests por ahora.
8. Ejecuta `km score .` y `km hotspots .` para métricas de calidad:
   a. Busca el reporte km más reciente en `docs/md/` (archivo que matchee `*_km-score.md`).
   b. Ejecuta `km score .` y `km hotspots .` en el directorio del sub-repo que se está revisando.
   c. Guarda los resultados en `docs/md/yyyymmdd_km-score.md` (fecha de hoy) con formato:
      ```
      # KM Score — {rama} — {fecha}
      ## Score: {score}
      ## Hotspots
      {top 10 hotspots}
      ## Comparación
      {score anterior} → {score actual} ({mejoró/empeoró/igual})
      {hotspots nuevos o resueltos vs reporte anterior}
      ```
   d. Si existe reporte anterior, comparar e incluir la diferencia en los hallazgos de la revisión.
   e. Si no existe reporte anterior, indicar que es la primera medición (baseline).

Formato de respuesta (obligatorio):
- Hallazgos (ordenados por severidad: Alta, Media, Baja)
- Cada hallazgo con referencia `archivo:línea` y explicación concreta
- Métricas km: score actual, comparación con anterior, hotspots relevantes
- Preguntas/Asunciones
- Veredicto final: "Listo para merge" o "No listo para merge"
- Resumen breve de 2-4 líneas
