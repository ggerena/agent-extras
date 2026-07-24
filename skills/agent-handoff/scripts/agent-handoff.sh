#!/usr/bin/env bash
set -euo pipefail

FROM="codex"
TO="opencode"
OBJECTIVE=""
REASON=""
NEXTSTEP=""
OPENQUESTIONS=""
COMMANDS_EXECUTED=""
VALIDATIONS=""
BLOCKERS=""
NOTES_FILE=""
OUT_DIR="docs"
REPO_PATH=""
OPENCODE_MODEL="opencode-go/glm-5.2"
OPENCODE_VARIANT="max"
CLAUDE_MODEL="claude-opus-4-8"
CLAUDE_EFFORT="medium"
CLAUDE_PERMISSION_MODE="plan"
GROK_MODEL="grok-4.5"
BITACORA_TAIL=40
DRY_RUN=0
LAUNCH=0

usage() {
  cat <<'EOF'
Usage: agent-handoff.sh -From codex -To opencode [options]

Options:
  -From codex|claude|opencode|grok  Origin agent (default codex)
  -To codex|claude|opencode|grok    Destination agent (default opencode)
  -Objective "..."                  Original objective
  -Reason "..."                     Reason for the handoff
  -NextStep "..."                   Recommended next step
  -OpenQuestions "..."              Open questions
  -CommandsExecuted "..."           Commands already run
  -Validations "..."                Validations already done
  -Blockers "..."                   Problems or blockers
  -NotesFile path                   Markdown notes file with ## sections
  -OutDir docs                      Output dir relative to repo (default docs)
  -RepoPath path                    Repo path (default cwd)
  -OpenCodeModel opencode-go/glm-5.2
  -OpenCodeVariant high|max         OpenCode variant (default max)
  -ClaudeModel claude-opus-4-8      Claude Code model (default claude-opus-4-8)
  -ClaudeEffort low|medium|high|max Claude Code effort (default medium)
  -ClaudePermissionMode plan        Claude Code permission mode (default plan)
  -GrokModel grok-4.5               Grok Build model (default grok-4.5)
  -BitacoraTail 40                  Lines of BITACORA.md to embed (default 40)
  -DryRun                           Print without writing files
  -Launch                           Run OpenCode or Grok Build when that is the destination
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -From) FROM="$2"; shift 2;;
    -To) TO="$2"; shift 2;;
    -Objective) OBJECTIVE="$2"; shift 2;;
    -Reason) REASON="$2"; shift 2;;
    -NextStep) NEXTSTEP="$2"; shift 2;;
    -OpenQuestions) OPENQUESTIONS="$2"; shift 2;;
    -CommandsExecuted) COMMANDS_EXECUTED="$2"; shift 2;;
    -Validations) VALIDATIONS="$2"; shift 2;;
    -Blockers) BLOCKERS="$2"; shift 2;;
    -NotesFile) NOTES_FILE="$2"; shift 2;;
    -OutDir) OUT_DIR="$2"; shift 2;;
    -RepoPath) REPO_PATH="$2"; shift 2;;
    -OpenCodeModel) OPENCODE_MODEL="$2"; shift 2;;
    -OpenCodeVariant) OPENCODE_VARIANT="$2"; shift 2;;
    -ClaudeModel) CLAUDE_MODEL="$2"; shift 2;;
    -ClaudeEffort) CLAUDE_EFFORT="$2"; shift 2;;
    -ClaudePermissionMode) CLAUDE_PERMISSION_MODE="$2"; shift 2;;
    -GrokModel) GROK_MODEL="$2"; shift 2;;
    -BitacoraTail) BITACORA_TAIL="$2"; shift 2;;
    -DryRun) DRY_RUN=1; shift;;
    -Launch) LAUNCH=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2;;
  esac
done

case "$FROM" in codex|claude|opencode|grok) :;; *) echo "-From must be codex|claude|opencode|grok" >&2; exit 2;; esac
case "$TO" in codex|claude|opencode|grok) :;; *) echo "-To must be codex|claude|opencode|grok" >&2; exit 2;; esac
case "$CLAUDE_EFFORT" in low|medium|high|max) :;; *) echo "-ClaudeEffort must be low|medium|high|max" >&2; exit 2;; esac

if [ -z "$REPO_PATH" ]; then REPO_PATH="$(pwd)"; fi
if [ ! -d "$REPO_PATH" ]; then echo "Repo path not found: $REPO_PATH" >&2; exit 2; fi

normalize_opencode_model() {
  local m="$1"
  if [ -z "$m" ]; then echo "opencode-go/glm-5.2"; return; fi
  local alias
  alias="$(printf '%s' "$m" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr -d '[:space:]')"
  case "$alias" in
    glm|glm5.2|glm-5.2|glm-5-2|opencode-go/glm-5-2) echo "opencode-go/glm-5.2"; return;;
  esac
  echo "$m"
}
OPENCODE_MODEL="$(normalize_opencode_model "$OPENCODE_MODEL")"

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

git_safe() {
  if ! command -v git >/dev/null 2>&1; then echo ""; return; fi
  git -C "$REPO_PATH" "$@" 2>/dev/null || true
}

BRANCH="$(git_safe rev-parse --abbrev-ref HEAD)"
HEAD_SHA="$(git_safe rev-parse HEAD)"
STATUS="$(git_safe status --porcelain)"
LOG_OUT="$(git_safe log --oneline -20)"
DIFF_STAT="$(git_safe diff --stat)"
DIFF_CACHED_STAT="$(git_safe diff --cached --stat)"

GIT_AVAILABLE=0
if [ -n "$BRANCH" ]; then GIT_AVAILABLE=1; fi
if [ "$GIT_AVAILABLE" -eq 1 ]; then
  BRANCH_LABEL="$BRANCH"
else
  BRANCH_LABEL="no disponible (repo sin git o git no encontrado)"
fi
if [ -n "$HEAD_SHA" ]; then HEAD_LABEL="$HEAD_SHA"; else HEAD_LABEL="no disponible"; fi

RULE_FILES="AGENTS.md CLAUDE.md LOCAL_CHANGES.md BITACORA.md"
RULE_STATUS=""
for f in $RULE_FILES; do
  if [ -f "$REPO_PATH/$f" ]; then RULE_STATUS="$RULE_STATUS- $f : presente"$'\n'; else RULE_STATUS="$RULE_STATUS- $f : ausente"$'\n'; fi
done

BITACORA_TAIL_TEXT=""
if [ -f "$REPO_PATH/BITACORA.md" ]; then
  BITACORA_TAIL_TEXT="$(tail -n "$BITACORA_TAIL" "$REPO_PATH/BITACORA.md" 2>/dev/null || true)"
fi

get_notes_field() {
  local file="$1"; shift
  local keys="$*"
  [ -f "$file" ] || { echo ""; return; }
  awk -v keys="$keys" '
    BEGIN {
      n = split(keys, k, "|");
      for (i = 1; i <= n; i++) want[tolower(k[i])] = 1;
      cur = ""; buf = "";
    }
    /^##[[:space:]]+/ {
      if (cur != "") { if (want[tolower(cur)]) print buf; }
      line = $0; sub(/^##[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line);
      cur = line; buf = "";
      next;
    }
    {
      if (cur != "") { if (buf != "") buf = buf "\n" $0; else buf = $0; }
    }
    END {
      if (cur != "" && want[tolower(cur)]) print buf;
    }
  ' "$file"
}

if [ -n "$NOTES_FILE" ]; then
  NOTES_PATH="$NOTES_FILE"
  case "$NOTES_PATH" in
    /*) :;;
    *) NOTES_PATH="$REPO_PATH/$NOTES_FILE";;
  esac
  if [ ! -f "$NOTES_PATH" ]; then echo "Notes file not found: $NOTES_PATH" >&2; exit 2; fi
  [ -z "$OBJECTIVE" ] && OBJECTIVE="$(get_notes_field "$NOTES_PATH" "objetivo|objetivo original")"
  [ -z "$REASON" ] && REASON="$(get_notes_field "$NOTES_PATH" "motivo|motivo del traspaso")"
  [ -z "$NEXTSTEP" ] && NEXTSTEP="$(get_notes_field "$NOTES_PATH" "siguiente paso|siguiente paso recomendado")"
  [ -z "$OPENQUESTIONS" ] && OPENQUESTIONS="$(get_notes_field "$NOTES_PATH" "dudas|dudas abiertas")"
  [ -z "$COMMANDS_EXECUTED" ] && COMMANDS_EXECUTED="$(get_notes_field "$NOTES_PATH" "comandos ejecutados|comandos")"
  [ -z "$VALIDATIONS" ] && VALIDATIONS="$(get_notes_field "$NOTES_PATH" "validaciones")"
  [ -z "$BLOCKERS" ] && BLOCKERS="$(get_notes_field "$NOTES_PATH" "problemas o bloqueos|problemas|bloqueos")"
fi

TIMESTAMP="$(date '+%Y-%m-%d %H:%M')"
DATE_STAMP="$(date '+%Y%m%d')"

case "$OUT_DIR" in
  /*) OUT_DIR_FULL="$OUT_DIR";;
  *) OUT_DIR_FULL="$REPO_PATH/$OUT_DIR";;
esac
case "$OUT_DIR" in
  /*) OUT_DIR_PROMPT_PATH="$OUT_DIR_FULL";;
  *) OUT_DIR_PROMPT_PATH="$OUT_DIR";;
esac

BASE_NAME="${DATE_STAMP}_HANDOFF-${FROM}-to-${TO}"
HANDOFF_NAME="${BASE_NAME}.md"
HANDOFF_PATH="$OUT_DIR_FULL/$HANDOFF_NAME"
SEQ=2
while [ -f "$OUT_DIR_FULL/${BASE_NAME}-${SEQ}.md" ]; do SEQ=$((SEQ+1)); done
if [ -f "$HANDOFF_PATH" ]; then
  HANDOFF_NAME="${BASE_NAME}-${SEQ}.md"
  HANDOFF_PATH="$OUT_DIR_FULL/$HANDOFF_NAME"
fi

format_value() {
  if [ -z "$1" ]; then echo ""; else echo "$1"; fi
}

build_md() {
  {
    echo "# Handoff: $FROM -> $TO"
    echo ""
    echo "- Fecha: $TIMESTAMP"
    echo "- Repo: $REPO_PATH"
    echo "- Branch: $BRANCH_LABEL"
    echo "- Commit actual: $HEAD_LABEL"
    echo ""
    echo "## Objetivo original"
    echo ""
    if [ -z "$OBJECTIVE" ]; then echo "_Pendiente de completar por el agente origen._"; else echo "$OBJECTIVE"; fi
    echo ""
    echo "## Motivo del traspaso"
    echo ""
    if [ -z "$REASON" ]; then echo "_Pendiente de completar por el agente origen. Si el traspaso ocurre porque el agente se perdio, decirlo aqui._"; else echo "$REASON"; fi
    echo ""
    echo "## Estado actual (hechos comprobados)"
    echo ""
    echo "Capturado automaticamente desde git, no desde la memoria del agente."
    echo ""
    echo "- Branch: $BRANCH_LABEL"
    echo "- HEAD: $HEAD_LABEL"
    echo ""
    echo "### Archivos modificados o sin confirmar (git status --porcelain)"
    echo ""
    if [ -z "$STATUS" ]; then echo "_Sin cambios pendientes o git no disponible._"; else printf '```text\n%s\n```\n' "$STATUS"; fi
    echo ""
    echo "### Historial reciente (git log --oneline -20)"
    echo ""
    if [ -z "$LOG_OUT" ]; then echo "_No disponible._"; else printf '```text\n%s\n```\n' "$LOG_OUT"; fi
    echo ""
    echo "### Cambios sin confirmar (git diff --stat)"
    echo ""
    if [ -z "$DIFF_STAT" ]; then echo "_Sin cambios sin confirmar o git no disponible._"; else printf '```text\n%s\n```\n' "$DIFF_STAT"; fi
    echo ""
    echo "### Cambios preparados (git diff --cached --stat)"
    echo ""
    if [ -z "$DIFF_CACHED_STAT" ]; then echo "_Sin cambios preparados o git no disponible._"; else printf '```text\n%s\n```\n' "$DIFF_CACHED_STAT"; fi
    echo ""
    echo "## Comandos ejecutados"
    echo ""
    if [ -z "$COMMANDS_EXECUTED" ]; then echo "_No capturado automaticamente. El agente origen puede completar a mano los comandos relevantes que ya corrio._"; else echo "$COMMANDS_EXECUTED"; fi
    echo ""
    echo "## Validaciones"
    echo ""
    if [ -z "$VALIDATIONS" ]; then echo "_No capturado automaticamente. El agente origen puede completar a mano las validaciones ya hechas._"; else echo "$VALIDATIONS"; fi
    echo ""
    echo "## Problemas o bloqueos"
    echo ""
    if [ -z "$BLOCKERS" ]; then echo "_Ninguno reportado._"; else echo "$BLOCKERS"; fi
    echo ""
    echo "## Decisiones tomadas (cola de BITACORA.md)"
    echo ""
    if [ -z "$BITACORA_TAIL_TEXT" ]; then echo "_BITACORA.md no encontrada o vacia._"; else printf 'Ultimas %s lineas de BITACORA.md:\n\n```markdown\n%s\n```\n' "$BITACORA_TAIL" "$BITACORA_TAIL_TEXT"; fi
    echo ""
    echo "## Reglas del repo que debe respetar el agente destino"
    echo ""
    echo "Archivos de reglas detectados en la raiz del repo:"
    echo ""
    printf '%s' "$RULE_STATUS"
    echo ""
    echo "El agente destino debe leer AGENTS.md y CLAUDE.md antes de hacer cambios. Respetar en particular: no hacer merge ni push sin autorizacion, no levantar servidores de desarrollo, no borrar archivos o estado sin confirmacion, mantener el traspaso factual y no esconder errores."
    echo ""
    echo "## Siguiente paso recomendado"
    echo ""
    if [ -z "$NEXTSTEP" ]; then echo "_Pendiente de completar por el agente origen._"; else echo "$NEXTSTEP"; fi
    echo ""
    echo "## Dudas abiertas"
    echo ""
    if [ -z "$OPENQUESTIONS" ]; then echo "_Ninguna reportada._"; else echo "$OPENQUESTIONS"; fi
    echo ""
    echo "## Prompt para el agente destino"
    echo ""
    echo '```text'
    echo "$DEST_PROMPT"
    echo '```'
    echo ""
  }
}

HANDOFF_PROMPT_PATH="$OUT_DIR_PROMPT_PATH/$HANDOFF_NAME"
DEST_PROMPT="Continuas el trabajo que dejo $FROM en el repo $REPO_PATH. Lee el handoff en $HANDOFF_PROMPT_PATH antes de hacer nada. Respeta las reglas del repo en AGENTS.md y CLAUDE.md. Empieza confirmando en una linea: objetivo, archivos tocados y reglas a respetar. Luego avanza al siguiente paso recomendado del handoff. No pisar el trabajo ya hecho. No hacer merge ni push sin autorizacion. No levantar servidores de desarrollo."

PROMPT_FILE_NAME="${BASE_NAME}-prompt.txt"
if [ "$HANDOFF_NAME" != "${BASE_NAME}.md" ]; then
  SEQ_NUM="${HANDOFF_NAME##*-}"; SEQ_NUM="${SEQ_NUM%.md}"
  PROMPT_FILE_NAME="${BASE_NAME}-${SEQ_NUM}-prompt.txt"
fi
PROMPT_DISPLAY_PATH="$OUT_DIR_PROMPT_PATH/$PROMPT_FILE_NAME"
HANDOFF_DISPLAY_PATH="$OUT_DIR_PROMPT_PATH/$HANDOFF_NAME"
SESSION_NAME="handoff ${FROM}-to-${TO} ${DATE_STAMP}"

VARIANT_ARG=""
if [ -n "$OPENCODE_VARIANT" ]; then VARIANT_ARG=" --variant $OPENCODE_VARIANT"; fi
CLAUDE_PERMISSION_ARG=""
if [ -n "$CLAUDE_PERMISSION_MODE" ]; then CLAUDE_PERMISSION_ARG=" --permission-mode $(shell_quote "$CLAUDE_PERMISSION_MODE")"; fi
PROMPT_COMMAND_SUBSTITUTION="\$(cat $(shell_quote "$PROMPT_DISPLAY_PATH"))"
case "$TO" in
  opencode) LAUNCH_CMD="opencode run $(shell_quote "$DEST_PROMPT") --dir $(shell_quote "$REPO_PATH") --model $OPENCODE_MODEL$VARIANT_ARG --file $(shell_quote "$HANDOFF_DISPLAY_PATH")";;
  claude) LAUNCH_CMD="claude --model $(shell_quote "$CLAUDE_MODEL") --effort $(shell_quote "$CLAUDE_EFFORT")$CLAUDE_PERMISSION_ARG --add-dir $(shell_quote "$REPO_PATH") --name $(shell_quote "$SESSION_NAME") \"$PROMPT_COMMAND_SUBSTITUTION\"";;
  grok) LAUNCH_CMD="grok --model $(shell_quote "$GROK_MODEL") --cwd $(shell_quote "$REPO_PATH") --prompt-file $(shell_quote "$PROMPT_DISPLAY_PATH")";;
  codex) LAUNCH_CMD="codex exec --sandbox read-only -m gpt-5.5 -c model_reasoning_effort=\"xhigh\" < $(shell_quote "$PROMPT_DISPLAY_PATH")";;
esac

MD_TEXT="$(build_md)"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[agent-handoff] Dry run: no se escriben archivos."
  echo ""
  echo "$MD_TEXT"
  echo ""
  echo '[agent-handoff] Prompt sugerido para el agente destino:'
  echo "$DEST_PROMPT"
  echo ""
  echo '[agent-handoff] Comando sugerido:'
  echo "$LAUNCH_CMD"
  exit 0
fi

mkdir -p "$OUT_DIR_FULL"
printf '%s\n' "$MD_TEXT" > "$HANDOFF_PATH"
echo "[agent-handoff] Handoff escrito: $HANDOFF_PATH"

PROMPT_FILE_PATH="$OUT_DIR_FULL/$PROMPT_FILE_NAME"
printf '%s\n' "$DEST_PROMPT" > "$PROMPT_FILE_PATH"
echo "[agent-handoff] Prompt escrito: $PROMPT_FILE_PATH"

INDEX_PATH="$OUT_DIR_FULL/HANDOFF-index.md"
if [ -z "$OBJECTIVE" ]; then OBJECTIVE_LINE="(sin objetivo)"; else OBJECTIVE_LINE="$(printf '%s' "$OBJECTIVE" | head -n1)"; fi
if [ "${#OBJECTIVE_LINE}" -gt 80 ]; then OBJECTIVE_LINE="$(printf '%s' "$OBJECTIVE_LINE" | cut -c1-77)..."; fi
INDEX_ENTRY="- $TIMESTAMP - $FROM -> $TO - [$HANDOFF_NAME]($HANDOFF_NAME) - objetivo: $OBJECTIVE_LINE"

if [ -f "$INDEX_PATH" ]; then
  TMP_INDEX="$(mktemp)"
  printed=0
  while IFS= read -r line; do
    if [ "$printed" -eq 0 ] && case "$line" in -\ *) true;; *) false;; esac; then
      printf '%s\n' "$INDEX_ENTRY" >> "$TMP_INDEX"
      printed=1
    fi
    printf '%s\n' "$line" >> "$TMP_INDEX"
  done < "$INDEX_PATH"
  if [ "$printed" -eq 0 ]; then printf '%s\n' "$INDEX_ENTRY" >> "$TMP_INDEX"; fi
  mv "$TMP_INDEX" "$INDEX_PATH"
else
  {
    echo "# Handoff index"
    echo ""
    echo "Registro de traspasos en este repo. El mas reciente arriba."
    echo ""
    echo "$INDEX_ENTRY"
  } > "$INDEX_PATH"
fi
echo "[agent-handoff] Indice actualizado: $INDEX_PATH"

echo ""
echo '[agent-handoff] Prompt para el agente destino:'
echo "$DEST_PROMPT"
echo ""
echo '[agent-handoff] Comando sugerido:'
echo "$LAUNCH_CMD"
echo ""
if [ "$TO" = "claude" ]; then
  echo '[agent-handoff] Claude Code se inicia en modo interactivo y la sesion queda nombrada para /resume.'
elif [ "$TO" = "opencode" ]; then
  echo '[agent-handoff] opencode run registra una sesion visible en OpenCode Desktop. Abre Desktop y continua esa sesion; no hace falta abrir otra terminal.'
elif [ "$TO" = "grok" ]; then
  echo '[agent-handoff] El comando inicia una sesion interactiva de Grok Build en el repo. Usa los permisos normales de Grok; no agrega aprobacion automatica.'
fi

if [ "$LAUNCH" -eq 1 ] && [ "$TO" = "opencode" ]; then
  if ! command -v opencode >/dev/null 2>&1; then
    echo "[agent-handoff] No se encontro binario opencode; -Launch omitido." >&2
  else
    echo "[agent-handoff] Ejecutando opencode (no interactivo)..." 
    if [ -n "$OPENCODE_VARIANT" ]; then
      opencode run "$DEST_PROMPT" --dir "$REPO_PATH" --model "$OPENCODE_MODEL" --variant "$OPENCODE_VARIANT" --file "$HANDOFF_PATH"
    else
      opencode run "$DEST_PROMPT" --dir "$REPO_PATH" --model "$OPENCODE_MODEL" --file "$HANDOFF_PATH"
    fi
    exit $?
  fi
fi

if [ "$LAUNCH" -eq 1 ] && [ "$TO" = "grok" ]; then
  if ! command -v grok >/dev/null 2>&1; then
    echo "[agent-handoff] No se encontro binario grok; -Launch omitido." >&2
  else
    echo "[agent-handoff] Ejecutando Grok Build interactivo..."
    grok --model "$GROK_MODEL" --cwd "$REPO_PATH" --prompt-file "$PROMPT_FILE_PATH"
    exit $?
  fi
fi

exit 0
