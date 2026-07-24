---
name: handoff-implementation-to-grok
description: Use when Codex should remain the coordinator and reviewer while Grok Build implements a scoped coding task with Grok 4.5. Use for requests such as "Codex coordina y Grok implementa", "delegar a Grok pero revisa", or when Grok needs to stop for a decision and Codex must unblock it. Do not use for a full ownership transfer, PR close-out, push, merge, or a pure second opinion.
---

# Delegacion supervisada a Grok Build

Mantener a Codex como responsable del plan, las decisiones y la revision. Grok Build implementa solo una porcion acotada y deja un reporte para que Codex decida el siguiente paso.

## Flujo

1. Revisar el estado, el plan y las reglas del repo antes de delegar. Definir una fase pequena con un resultado verificable.
2. Si hay bloqueantes o falta una decision del usuario, detenerse. No iniciar a Grok hasta que exista un resumen de review que indique `pass`.
3. Ejecutar `scripts/handoff-implementation-to-grok.ps1` con `-ReviewSummary`, el objetivo y el siguiente paso. El script crea:
   - un handoff con el estado objetivo de git;
   - un prompt para Grok;
   - una plantilla de estado que Grok debe completar.
4. Ejecutar el comando `grok` sugerido. Grok usa permisos normales: no pasar `--always-approve` ni `--permission-mode bypassPermissions`.
5. Cuando Grok termine o se bloquee, Codex revisa el archivo de estado, `git diff` y las validaciones. Si falta una decision, Codex la toma y crea una nueva fase; si no, Codex valida el resultado antes de cerrar la tarea.

No existe una conversacion automatica entre ambas herramientas. "Destrabar" significa que Grok deja una pregunta concreta en su reporte y Codex genera la proxima instruccion o fase con la decision resuelta.

## Ejecutar

Desde la raiz del repo objetivo:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\handoff-implementation-to-grok\scripts\handoff-implementation-to-grok.ps1" `
  -Invoker codex `
  -Objective "Implementar solo la validacion del formulario" `
  -ReviewSummary "Sin bloqueantes; conservar el comportamiento actual." `
  -NextStep "Implementar la validacion, agregar o actualizar tests y dejar el reporte para revision de Codex."
```

Usar `-DryRun` para revisar los archivos y el comando sin escribir. Usar `-Launch` solo si se quiere abrir Grok Build de inmediato en la misma terminal.

## Reglas de coordinacion

- Mantener las fases pequenas: una decision o cambio coherente por ejecucion.
- Pedir a Grok que pare y documente la duda cuando necesite cambiar alcance, arquitectura, datos, permisos o comportamiento no definido.
- No permitir que Grok haga commit, push, PR o merge salvo autorizacion explicita del usuario en la sesion actual.
- No tratar el reporte de Grok como aprobacion: Codex revisa los cambios y las validaciones antes de continuar o cerrar.
