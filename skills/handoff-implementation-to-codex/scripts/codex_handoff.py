#!/usr/bin/env python3
"""Portable, two-file handoff supervisor for Codex CLI."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 4
PROTECTED_BRANCHES = {"main", "master", "develop"}
ABSENT = "absent"
FINAL_STATES = {"pass", "blocked", "needs-user", "failed"}
DEFAULT_MODEL = "gpt-6.1-sol"
EFFORTS = ("medium", "high", "xhigh")
SANDBOX_BY_MODE = {
    "review": "read-only",
    "implement": "workspace-write",
    "closeout": "danger-full-access",
}
RESULT_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "state": {"type": "string", "enum": sorted(FINAL_STATES)},
        "summary": {"type": "string"},
        "changes": {"type": "array", "items": {"type": "string"}},
        "validations": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "command": {"type": "string"},
                    "result": {"type": "string"},
                },
                "required": ["command", "result"],
            },
        },
        "blockers": {"type": "array", "items": {"type": "string"}},
        "question": {"type": ["string", "null"]},
        "next_step": {"type": ["string", "null"]},
        "git": {
            "type": ["object", "null"],
            "additionalProperties": False,
            "properties": {
                "commit": {"type": ["string", "null"]},
                "branch": {"type": ["string", "null"]},
                "pushed": {"type": "boolean"},
                "pr_url": {"type": ["string", "null"]},
            },
            "required": ["commit", "branch", "pushed", "pr_url"],
        },
    },
    "required": [
        "state",
        "summary",
        "changes",
        "validations",
        "blockers",
        "question",
        "next_step",
        "git",
    ],
}


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).astimezone().isoformat()


def atomic_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def read_json(path: Path) -> dict[str, Any]:
    last_error: Exception | None = None
    for _ in range(3):
        try:
            with path.open("r", encoding="utf-8-sig") as handle:
                value = json.load(handle)
            if not isinstance(value, dict):
                raise ValueError(f"{path.name} must contain a JSON object")
            return value
        except (json.JSONDecodeError, OSError, ValueError) as error:
            last_error = error
    raise RuntimeError(f"Cannot read {path}: {last_error}")


def run(
    command: list[str],
    cwd: Path | None = None,
    check: bool = False,
    timeout: float | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    extra: dict[str, Any] = {}
    if os.name == "nt":
        extra["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        completed = subprocess.run(
            command,
            cwd=str(cwd) if cwd else None,
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=timeout,
            env=env,
            **extra,
        )
    except subprocess.TimeoutExpired:
        completed = subprocess.CompletedProcess(command, 124, "", "timeout")
    if check and completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(f"Command failed ({completed.returncode}): {detail}")
    return completed


def git(repo: Path, *arguments: str, check: bool = False) -> str:
    completed = run(
        ["git", "-c", "core.quotePath=false", "-C", str(repo), *arguments], check=check
    )
    return completed.stdout.strip() if completed.returncode == 0 else ""


def remote_heads(repo: Path, remote: str, branches: list[str]) -> dict[str, str | None]:
    """SHA remoto por rama; "absent" si la rama no existe y None si falló la consulta."""
    env = {**os.environ, "GIT_TERMINAL_PROMPT": "0"}
    heads: dict[str, str | None] = {}
    for branch in sorted(set(branches)):
        completed = run(
            ["git", "-c", "core.quotePath=false", "-C", str(repo), "ls-remote", remote,
             f"refs/heads/{branch}"],
            timeout=30,
            env=env,
        )
        if completed.returncode != 0:
            heads[branch] = None
            continue
        lines = completed.stdout.strip().splitlines()
        heads[branch] = lines[0].split()[0] if lines else ABSENT
    return heads


def integrity_hash(handoff: dict[str, Any]) -> str:
    """Huella de lo que los guardrails dan por fijo; vive en result.json, no en handoff.json."""
    repository = handoff["repository"]
    material = {
        "mode": handoff["task"]["mode"],
        "allowed_paths": list(handoff["task"].get("allowed_paths") or []),
        "path": repository.get("path"),
        "snapshot": repository.get("snapshot"),
        "remote_heads": repository.get("remote_heads"),
    }
    return sha256_text(json.dumps(material, sort_keys=True, ensure_ascii=False))


def git_root(repo: Path) -> Path:
    root = git(repo, "rev-parse", "--show-toplevel", check=True)
    return Path(root).resolve()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8", errors="replace")).hexdigest()


def split_git_lines(value: str) -> list[str]:
    return sorted({line.strip().replace("\\", "/") for line in value.splitlines() if line.strip()})


def dirty_paths(repo: Path) -> list[str]:
    names: set[str] = set()
    for arguments in (
        ("diff", "--name-only"),
        ("diff", "--cached", "--name-only"),
        ("ls-files", "--others", "--exclude-standard"),
    ):
        names.update(split_git_lines(git(repo, *arguments)))
    return sorted(names)


def path_fingerprint(repo: Path, relative: str) -> str:
    relative = relative.replace("\\", "/")
    target = repo / Path(relative)
    components = [
        git(repo, "diff", "--binary", "--", relative),
        git(repo, "diff", "--cached", "--binary", "--", relative),
    ]
    if target.is_file():
        components.append(sha256_file(target))
    elif target.exists():
        components.append("directory")
    else:
        components.append("missing")
    return sha256_text("\n\0\n".join(components))


def snapshot(repo: Path) -> dict[str, Any]:
    paths = dirty_paths(repo)
    return {
        "branch": git(repo, "branch", "--show-current"),
        "head": git(repo, "rev-parse", "HEAD"),
        "status": git(repo, "status", "--short"),
        "dirty_paths": paths,
        "fingerprints": {path: path_fingerprint(repo, path) for path in paths},
        "captured_at": now_iso(),
    }


def changed_from_snapshot(repo: Path, initial: dict[str, Any]) -> list[str]:
    current_paths = set(dirty_paths(repo))
    initial_fingerprints = dict(initial.get("fingerprints") or {})
    candidates = current_paths | set(initial_fingerprints)
    changed = []
    for relative in sorted(candidates):
        current = path_fingerprint(repo, relative) if relative in current_paths else None
        if current != initial_fingerprints.get(relative):
            changed.append(relative)
    return changed


def normalize_allowed(value: str) -> str:
    normalized = value.strip().replace("\\", "/")
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized.rstrip("/")


def is_allowed(relative: str, allowed: list[str]) -> bool:
    relative = normalize_allowed(relative)
    for candidate in allowed:
        candidate = normalize_allowed(candidate)
        if not candidate:
            continue
        if relative == candidate or relative.startswith(candidate + "/"):
            return True
    return False


def evaluate_guardrails(
    handoff: dict[str, Any], result: dict[str, Any], repo: Path, check_remote: bool = True
) -> dict[str, Any]:
    """`check_remote` consulta el remoto una sola vez, al terminar el closeout.

    Después se reutiliza lo guardado en result.json: un cambio posterior de otra
    persona en el remoto no puede invalidar un closeout ya terminado.
    """
    mode = handoff["task"]["mode"]
    initial = handoff["repository"]["snapshot"]
    allowed = list(handoff["task"].get("allowed_paths") or [])
    current_branch = git(repo, "branch", "--show-current")
    current_head = git(repo, "rev-parse", "HEAD")
    changed = changed_from_snapshot(repo, initial)
    violations: list[str] = []

    if result.get("integrity") != integrity_hash(handoff):
        violations.append("handoff_integrity_mismatch")

    if current_branch != initial.get("branch"):
        violations.append(
            f"branch_changed:{initial.get('branch') or '<detached>'}->{current_branch or '<detached>'}"
        )

    if mode in {"implement", "review"} and current_head != initial.get("head"):
        violations.append(f"head_changed:{initial.get('head')}->{current_head}")

    if mode == "review" and changed:
        violations.append("review_wrote_files:" + ",".join(changed))

    if mode == "implement":
        outside = [path for path in changed if not is_allowed(path, allowed)]
        if outside:
            violations.append("outside_allowed_paths:" + ",".join(outside))

    committed_paths: list[str] = []
    if mode == "closeout":
        outside_changed = [path for path in changed if not is_allowed(path, allowed)]
        if outside_changed:
            violations.append(
                "closeout_changed_outside_allowed_paths:" + ",".join(outside_changed)
            )
    if mode == "closeout" and initial.get("head") and current_head != initial.get("head"):
        commit_range = f"{initial['head']}..{current_head}"
        committed_paths = split_git_lines(git(repo, "diff", "--name-only", commit_range))
        outside = [path for path in committed_paths if not is_allowed(path, allowed)]
        if outside:
            violations.append("committed_outside_allowed_paths:" + ",".join(outside))
        commit_count = git(repo, "rev-list", "--count", commit_range)
        if commit_count.isdigit() and int(commit_count) > 1:
            violations.append(f"closeout_created_multiple_commits:{commit_count}")
        reported_commit = ((result.get("git") or {}).get("commit") or "").strip()
        if reported_commit and not current_head.startswith(reported_commit):
            violations.append(f"reported_commit_mismatch:{reported_commit}->{current_head}")

    remote_violations: list[str] = []
    unverified_remote: list[str] = []
    if mode == "closeout" and not check_remote:
        stored = result.get("guardrails") or {}
        remote_violations = list(stored.get("remote_violations") or [])
        unverified_remote = list(stored.get("remote_heads_unverified") or [])
    elif mode == "closeout":
        remote = (handoff["task"].get("closeout") or {}).get("remote") or "origin"
        if (result.get("git") or {}).get("pushed"):
            published = {
                git(repo, "rev-parse", f"refs/remotes/{remote}/{current_branch}"),
                git(repo, "rev-parse", "@{upstream}"),
                remote_heads(repo, remote, [current_branch]).get(current_branch),
            }
            published.discard("")
            published.discard(None)
            published.discard(ABSENT)
            if current_head not in published:
                remote_violations.append(
                    f"pushed_head_not_synced:{(sorted(published) or ['<missing>'])[0]}->{current_head}"
                )
        initial_remote = handoff["repository"].get("remote_heads")
        if initial_remote:
            current_remote = remote_heads(repo, remote, list(initial_remote))
            for branch, before in sorted(initial_remote.items()):
                after = current_remote.get(branch)
                if before is None or after is None:
                    unverified_remote.append(branch)
                elif before != after:
                    remote_violations.append(
                        f"protected_remote_branch_changed:{branch}:{before[:12]}->{after[:12]}"
                    )
    violations.extend(remote_violations)

    return {
        "checked_at": now_iso(),
        "mode": mode,
        "violations": violations,
        "changed_since_start": changed,
        "committed_since_start": committed_paths,
        "remote_violations": remote_violations,
        "remote_heads_unverified": unverified_remote,
        "branch": current_branch,
        "head": current_head,
    }


def process_running(process_id: Any) -> bool:
    try:
        pid = int(process_id)
    except (TypeError, ValueError):
        return False
    if pid <= 0:
        return False
    if os.name == "nt":
        completed = run(
            ["powershell", "-NoProfile", "-Command", f"Get-Process -Id {pid} -ErrorAction SilentlyContinue"]
        )
        return completed.returncode == 0 and bool(completed.stdout.strip())
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError):
        return False


def safe_slug(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]", "-", value).strip("-")
    return slug if slug and slug not in {".", ".."} else "phase"


def resolve_workspace(repo: Path, requested: str) -> tuple[Path, str]:
    if requested:
        workspace = Path(requested).expanduser().resolve()
        if not workspace.is_dir():
            raise RuntimeError(f"Workspace root not found: {workspace}")
        return workspace, "parameter"
    environment = os.environ.get("AGENT_WORKSPACE_ROOT", "")
    if environment:
        workspace = Path(environment).expanduser().resolve()
        if not workspace.is_dir():
            raise RuntimeError(f"AGENT_WORKSPACE_ROOT not found: {workspace}")
        return workspace, "environment"
    working = Path.cwd().resolve()
    if working != repo and repo.is_relative_to(working) and (working / "AGENTS.md").is_file():
        return working, "working-directory"
    candidates: list[Path] = []
    for parent in [repo.parent, *repo.parents]:
        if (parent / ".agent-handoffs").is_dir():
            return parent, "existing-handoff-directory"
        if (parent / "AGENTS.md").is_file():
            candidates.append(parent)
    if candidates:
        return candidates[0], "agents-file"
    return repo.parent, "repo-parent-fallback"


def resolve_handoff_root(repo: Path, requested: str, workspace: str) -> tuple[Path, str]:
    if requested:
        root = Path(requested).expanduser().resolve()
        source = "parameter"
    elif os.environ.get("AGENT_HANDOFF_ROOT"):
        root = Path(os.environ["AGENT_HANDOFF_ROOT"]).expanduser().resolve()
        source = "environment"
    else:
        workspace_path, source = resolve_workspace(repo, workspace)
        root = (workspace_path / ".agent-handoffs" / "codex").resolve()
    if root == repo or repo in root.parents:
        raise RuntimeError("Handoff root must be outside the target repo")
    return root, source


def resolve_codex() -> str:
    configured = os.environ.get("CODEX_BIN", "")
    if configured and Path(configured).expanduser().is_file():
        return str(Path(configured).expanduser().resolve())
    # En Windows se prefiere el .exe real y no los shims .cmd/.ps1 de npm.
    for name in ("codex.exe", "codex") if os.name == "nt" else ("codex",):
        found = shutil.which(name)
        if found:
            return found
    local = os.environ.get("LOCALAPPDATA", "")
    if local:
        candidate = Path(local) / "Programs" / "OpenAI" / "Codex" / "bin" / "codex.exe"
        if candidate.is_file():
            return str(candidate)
    return ""


def compact_history(handoff: dict[str, Any], result: dict[str, Any]) -> dict[str, Any]:
    return {
        "attempt_id": handoff.get("attempt_id"),
        "mode": handoff.get("task", {}).get("mode"),
        "objective": handoff.get("task", {}).get("objective"),
        "state": result.get("state"),
        "summary": str(result.get("summary") or "")[:1200],
        "changes": list(result.get("changes") or [])[:100],
        "validations": list(result.get("validations") or [])[:50],
        "blockers": list(result.get("blockers") or [])[:20],
        "git": result.get("git"),
        "guardrails": result.get("guardrails"),
        "finished_at": (result.get("execution") or {}).get("finished_at")
        or result.get("updated_at"),
    }


def validate_previous_phase(phase_dir: Path) -> tuple[list[dict[str, Any]], dict[str, Any] | None]:
    handoff_path = phase_dir / "handoff.json"
    result_path = phase_dir / "result.json"
    if not handoff_path.exists() and not result_path.exists():
        return [], None
    if not handoff_path.is_file() or not result_path.is_file():
        raise RuntimeError("Existing phase must contain handoff.json and result.json")
    handoff = read_json(handoff_path)
    result = read_json(result_path)
    execution = result.get("execution") or {}
    if process_running(execution.get("supervisor_pid")) or process_running(
        execution.get("codex_pid")
    ):
        raise RuntimeError("Previous attempt is still running")
    if execution.get("chain_running"):
        raise RuntimeError("Previous attempt chain did not finish")
    if result.get("state") not in FINAL_STATES:
        raise RuntimeError("Previous attempt has no final result")
    repository = Path(handoff["repository"]["path"])
    guardrails = evaluate_guardrails(handoff, result, repository, check_remote=False)
    result["guardrails"] = guardrails
    if guardrails["violations"]:
        result["state"] = "failed"
        result["blockers"] = list(result.get("blockers") or []) + [
            violation
            for violation in guardrails["violations"]
            if violation not in (result.get("blockers") or [])
        ]
        result["updated_at"] = now_iso()
        atomic_json(result_path, result)
        raise RuntimeError(
            "Previous attempt has guardrail violations: "
            + ", ".join(guardrails["violations"])
        )
    history = list(handoff.get("history") or [])
    history.append(compact_history(handoff, result))
    return history[-20:], handoff


def plan_contract(
    args: argparse.Namespace, previous: dict[str, Any] | None
) -> dict[str, Any] | None:
    if not args.plan_path:
        return None
    path = Path(args.plan_path).expanduser().resolve()
    if not path.is_file():
        raise RuntimeError(f"Plan path not found: {path}")
    digest = sha256_file(path)
    policy = "full" if args.require_full_plan_read else args.plan_read_policy
    previous_plan = (previous or {}).get("task", {}).get("plan") or {}
    if policy == "auto":
        policy = "verify" if previous_plan.get("sha256") == digest else "full"
    if policy == "verify":
        if not previous_plan:
            raise RuntimeError("Plan verify requires a previous attempt in the same phase")
        if previous_plan.get("sha256") != digest:
            raise RuntimeError("Source plan changed; start a full-read attempt")
    return {"path": str(path), "sha256": digest, "read_policy": policy}


def mode_rules(args: argparse.Namespace) -> list[str]:
    common = [
        "No uses aprobaciones automáticas ni intentes salir del sandbox, y no levantes servidores de desarrollo.",
        "No incluyas secretos en archivos, logs ni en tu respuesta.",
        "No modifiques configuración ni memoria de Codex.",
    ]
    if args.mode == "review":
        rules = [
            "Revisa estrictamente en modo lectura; no crees, edites ni borres archivos.",
            "Incluye tracked, staged y untracked.",
            "No ejecutes build, tests ni comandos que escriban artefactos.",
        ]
        if args.review_skill_path:
            rules.append("Lee completa y aplica task.review_skill_path antes de revisar.")
        return [*rules, *common]
    if args.mode == "closeout":
        rules = [
            "No edites producto; realiza únicamente el cierre Git autorizado.",
            "Agrega solo allowed_paths; no uses git add -A ni git add .",
            "Opera solo sobre la rama actual y publícala con git push -u <remoto> <rama>.",
            "Ejecuta git diff --check y Gitleaks staged con redacción si está disponible.",
            "No uses force-push, amend, rebase, merge, tag, release ni deploy.",
        ]
        if args.closeout_action == "pull-request":
            rules.append(
                "Busca primero un PR abierto de la rama actual hacia base_branch y reutilízalo."
            )
            if args.update_existing_pr:
                rules.append(
                    "Crea o actualiza título y cuerpo del PR para reflejar alcance, commits, pruebas, pendientes y PR relacionados."
                )
            else:
                rules.append("Si el PR ya existe, repórtalo sin modificar su cuerpo.")
        else:
            rules.append("No crees ni modifiques PR en este checkpoint.")
        return [*rules, *common]
    return [
        "Edita únicamente allowed_paths.",
        "No hagas commit, push, PR, merge, deploy ni cambios fuera de alcance.",
        "Lee y busca libremente con comandos de solo lectura; para probar o generar artefactos usa solo validation_commands y elimina lo generado fuera de allowed_paths.",
        *common,
    ]


def build_task_prompt(handoff: dict[str, Any]) -> str:
    task = handoff["task"]
    repositorio = handoff["repository"]
    modo = task["mode"]
    lineas: list[str] = [
        f"# Fase {modo} — {repositorio.get('name') or repositorio['path']}",
        "",
        "## Objetivo",
        "",
        task["objective"].strip(),
        "",
        "## Contexto",
        "",
        f"- Repositorio: `{repositorio['path']}`",
        f"- Rama: `{repositorio.get('branch') or '(la actual)'}`",
        f"- Sandbox de esta fase: `{sandbox_for(handoff)}`",
    ]

    plan = task.get("plan") or {}
    plan_path = plan.get("path")
    politica = plan.get("read_policy")
    if plan_path:
        if politica == "verify":
            lineas.append(
                f"- Plan: `{plan_path}` — ya verificado; usa el historial de "
                "abajo en vez de releerlo entero."
            )
        elif politica == "none":
            lineas.append(f"- Plan: `{plan_path}` — no hace falta leerlo.")
        else:
            lineas.append(f"- Plan: `{plan_path}` — **léelo completo antes de empezar**.")

    if task.get("review_skill_path"):
        lineas.append(
            f"- Skill de revisión: `{task['review_skill_path']}` — léela y aplícala."
        )
    if task.get("runtime_setup_command"):
        lineas.append(f"- Preparar entorno con: `{task['runtime_setup_command']}`")

    permitidos = task.get("allowed_paths") or []
    if permitidos:
        lineas.extend(["", "## Rutas que puedes tocar", ""])
        lineas.extend(f"- `{ruta}`" for ruta in permitidos)
        lineas.append("")
        lineas.append(
            "Cualquier cambio fuera de esas rutas invalida la fase completa, "
            "aunque el trabajo esté bien hecho."
        )

    validaciones = task.get("validation_commands") or []
    if validaciones and modo == "review":
        lineas.extend(["", "## Validaciones de la fase (solo contexto)", ""])
        lineas.extend(f"- `{comando}`" for comando in validaciones)
        lineas.append("")
        lineas.append(
            "No se ejecutan en review: ya las corrió el implement. No ejecutes "
            "tests, build ni estos comandos; revisa solo leyendo."
        )
    elif validaciones:
        lineas.extend(["", "## Validaciones obligatorias", ""])
        lineas.extend(f"- `{comando}`" for comando in validaciones)
        lineas.append("")
        lineas.append("Ejecútalas y no des la fase por terminada si alguna falla.")

    closeout = task.get("closeout")
    if closeout:
        lineas.extend(["", "## Cierre Git", ""])
        lineas.append(f"- Acción: `{closeout['action']}`")
        lineas.append(f"- Remoto: `{closeout['remote']}`")
        lineas.append(f"- Rama base: `{closeout['base_branch']}`")
        lineas.append(f"- Mensaje del commit: `{closeout['commit_message']}`")
        if closeout["action"] == "pull-request":
            lineas.append(f"- Título del PR: `{closeout['pr_title']}`")
            if closeout.get("pr_body"):
                lineas.extend(["", "Cuerpo del PR:", "", closeout["pr_body"]])

    lineas.extend(["", "## Reglas", ""])
    lineas.extend(f"- {regla}" for regla in handoff.get("rules") or [])

    historial = handoff.get("history") or []
    if historial:
        lineas.extend(["", "## Intentos anteriores de esta fase", ""])
        for entrada in historial[-5:]:
            estado = entrada.get("state", "?")
            resumen = (entrada.get("summary") or "").strip()
            lineas.append(f"- **{estado}**: {resumen}")

    lineas.extend(
        [
            "",
            "## Cómo terminar",
            "",
            "Tu último mensaje debe ser un JSON con exactamente estas claves: "
            + ", ".join(RESULT_SCHEMA["required"])
            + ".",
            "",
            "`state` vale `pass` si terminaste y las validaciones pasaron, "
            "`blocked` si algo te impidió avanzar, y `needs-user` si hace falta "
            "una decisión del coordinador.",
            "",
            "No escribas `result.json`: lo actualiza el supervisor.",
        ]
    )
    return "\n".join(lineas) + "\n"


def sandbox_for(handoff: dict[str, Any]) -> str:
    task = handoff["task"]
    mode = task["mode"]
    if mode not in SANDBOX_BY_MODE:
        raise RuntimeError(f"Unknown mode: {mode}")
    if mode == "closeout" and not (task.get("closeout") or {}).get("allow_git_closeout"):
        raise RuntimeError("Closeout requires --allow-git-closeout")
    return SANDBOX_BY_MODE[mode]


def build_codex_command(
    handoff: dict[str, Any], codex_bin: str, schema_path: Path, last_message_path: Path
) -> list[str]:
    config = handoff["codex"]
    return [
        codex_bin,
        "exec",
        "-C",
        handoff["repository"]["path"],
        "-m",
        config["model"],
        "-c",
        f"model_reasoning_effort={config['reasoning_effort']}",
        "-c",
        'approval_policy="never"',
        "-s",
        sandbox_for(handoff),
        "--ephemeral",
        "--color",
        "never",
        "--json",
        "--output-schema",
        str(schema_path),
        "-o",
        str(last_message_path),
        "-",
    ]


def initial_result(
    phase_id: str,
    attempt_id: str,
    mode: str,
    supervisor_pid: int | None = None,
    integrity: str | None = None,
    chain_running: bool = False,
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "phase_id": phase_id,
        "attempt_id": attempt_id,
        "mode": mode,
        "integrity": integrity,
        "state": "pending",
        "summary": "",
        "changes": [],
        "validations": [],
        "blockers": [],
        "question": None,
        "next_step": None,
        "git": None,
        "execution": {
            "supervisor_pid": supervisor_pid,
            "codex_pid": None,
            "chain_running": chain_running,
            "started_at": now_iso(),
            "finished_at": None,
            "exit_code": None,
            "diagnostic": None,
            "usage": None,
        },
        "guardrails": None,
        "updated_at": now_iso(),
    }


def validate_start_args(args: argparse.Namespace, repo: Path) -> None:
    if not args.objective.strip():
        raise RuntimeError("Objective is required")
    if not args.reasoning_effort:
        raise RuntimeError("Reasoning effort is required")
    if args.reasoning_effort not in EFFORTS:
        raise RuntimeError(f"Reasoning effort must be one of: {', '.join(EFFORTS)}")
    if not args.reasoning_rationale.strip():
        raise RuntimeError("Reasoning rationale is required")
    if not args.skip_review_gate and not args.review_summary.strip():
        raise RuntimeError("Review gate missing; provide --review-summary")
    if args.review_verdict != "pass":
        if not args.force_handoff or not args.force_reason.strip():
            raise RuntimeError("A non-pass review requires --force-handoff and --force-reason")
    if args.skip_review_gate and not args.force_handoff:
        raise RuntimeError("Skipping the review gate requires --force-handoff")
    if args.mode in {"implement", "closeout"} and not args.allowed_path:
        raise RuntimeError(f"{args.mode} requires at least one --allowed-path")
    if args.mode == "review" and args.reasoning_effort not in {"high", "xhigh"}:
        raise RuntimeError("Review mode requires high or xhigh reasoning effort")
    if args.review_skill_path and not Path(args.review_skill_path).expanduser().is_file():
        raise RuntimeError(f"Review skill not found: {args.review_skill_path}")
    branch = git(repo, "branch", "--show-current")
    if args.mode == "closeout":
        if not args.allow_git_closeout:
            raise RuntimeError("Closeout requires --allow-git-closeout")
        if args.closeout_action not in {"checkpoint", "pull-request"}:
            raise RuntimeError("Closeout action must be checkpoint or pull-request")
        if not args.commit_message.strip():
            raise RuntimeError("Closeout requires --commit-message")
        protected = PROTECTED_BRANCHES | {args.base_branch}
        if not branch or branch in protected:
            raise RuntimeError(f"Refusing closeout on protected or detached branch: {branch}")
        if args.closeout_action == "pull-request" and not args.pr_title.strip():
            raise RuntimeError("Pull-request closeout requires --pr-title")
        if args.update_existing_pr and not args.pr_body.strip():
            raise RuntimeError("Updating an existing PR requires --pr-body")


def start_command(args: argparse.Namespace) -> int:
    repo = git_root(Path(args.repo_path or os.getcwd()).expanduser().resolve())
    validate_start_args(args, repo)
    repo_slug = safe_slug(repo.name)
    if args.phase_dir:
        phase_dir = Path(args.phase_dir).expanduser().resolve()
        existing_path = phase_dir / "handoff.json"
        if not existing_path.is_file():
            raise RuntimeError("--phase-dir must point to an existing phase")
        existing = read_json(existing_path)
        root = Path(existing["handoff_root"]).resolve()
        root_source = "reused-phase"
        if args.handoff_root:
            requested_root = Path(args.handoff_root).expanduser().resolve()
            if requested_root != root:
                raise RuntimeError("Requested handoff root differs from the existing phase")
        if Path(existing["repository"]["path"]).resolve() != repo:
            raise RuntimeError("Existing phase belongs to a different repository")
        expected_parent = (root / repo_slug).resolve()
        if phase_dir.parent != expected_parent:
            raise RuntimeError("Phase directory is outside the resolved repo handoff root")
        phase_id = phase_dir.name
    else:
        root, root_source = resolve_handoff_root(repo, args.handoff_root, args.workspace_root)
        phase_id = safe_slug(args.phase_id) if args.phase_id else (
            dt.datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
        )
        phase_dir = (root / repo_slug / phase_id).resolve()

    history, previous = validate_previous_phase(phase_dir)
    attempt_id = dt.datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
    plan = plan_contract(args, previous)
    initial = snapshot(repo)
    review_skill = (
        str(Path(args.review_skill_path).expanduser().resolve())
        if args.review_skill_path
        else None
    )
    closeout_heads = None
    if args.mode == "closeout":
        closeout_heads = remote_heads(
            repo, args.git_remote, [*PROTECTED_BRANCHES, args.base_branch]
        )
        failed = sorted(branch for branch, head in closeout_heads.items() if head is None)
        if failed:
            raise RuntimeError(
                f"Cannot query remote '{args.git_remote}' (ls-remote failed for "
                f"{', '.join(failed)}); refusing to start closeout without remote protection"
            )
    handoff = {
        "schema_version": SCHEMA_VERSION,
        "phase_id": phase_id,
        "attempt_id": attempt_id,
        "phase_directory": str(phase_dir),
        "handoff_root": str(root),
        "handoff_root_source": root_source,
        "files": ["handoff.json", "result.json"],
        "coordinator": {
            "invoker": args.invoker,
            "review": {
                "verdict": args.review_verdict,
                "summary": args.review_summary,
                "require_review_after": args.require_review_after,
                "forced": args.force_handoff,
                "force_reason": args.force_reason or None,
            },
        },
        "task": {
            "mode": args.mode,
            "objective": args.objective,
            "next_step": args.next_step
            or "Completar solo el alcance, validar y devolver el resultado estructurado.",
            "allowed_paths": [normalize_allowed(path) for path in args.allowed_path],
            "validation_commands": args.validation_command,
            "plan": plan,
            "review_skill_path": review_skill,
            "runtime_setup_command": args.runtime_setup_command or None,
            "auto_review": not args.no_auto_review,
            "require_tests": not args.no_test_gate,
            "closeout": (
                {
                    "action": args.closeout_action,
                    "allow_git_closeout": args.allow_git_closeout,
                    "remote": args.git_remote,
                    "base_branch": args.base_branch,
                    "commit_message": args.commit_message,
                    "pr_title": args.pr_title,
                    "pr_body": args.pr_body,
                    "update_existing_pr": args.update_existing_pr,
                }
                if args.mode == "closeout"
                else None
            ),
        },
        "rules": mode_rules(args),
        "codex": {
            "model": args.model,
            "reasoning_effort": args.reasoning_effort,
            "reasoning_rationale": args.reasoning_rationale,
        },
        "repository": {
            "path": str(repo),
            "branch": initial["branch"],
            "head": initial["head"],
            "snapshot": initial,
            "remote_heads": closeout_heads,
        },
        "history": history,
        "result_path": str(phase_dir / "result.json"),
        "created_at": now_iso(),
    }
    result = initial_result(phase_id, attempt_id, args.mode, integrity=integrity_hash(handoff))
    output = {
        "dry_run": args.dry_run,
        "phaseId": phase_id,
        "attemptId": attempt_id,
        "phaseDirectory": str(phase_dir),
        "runId": phase_id,
        "runDirectory": str(phase_dir),
        "handoffPath": str(phase_dir / "handoff.json"),
        "resultPath": str(phase_dir / "result.json"),
        "processId": None,
        "planReadPolicy": (plan or {}).get("read_policy"),
    }
    if args.dry_run:
        output["handoffPreview"] = handoff
        print(json.dumps(output, ensure_ascii=False, indent=2))
        return 0

    phase_dir.mkdir(parents=True, exist_ok=True)
    atomic_json(phase_dir / "handoff.json", handoff)
    (phase_dir / "prompt.md").write_text(build_task_prompt(handoff), encoding="utf-8")
    atomic_json(phase_dir / "result.json", result)
    if args.launch:
        supervisor_python = Path(getattr(sys, "_base_executable", sys.executable)).resolve()
        if os.name == "nt":
            hidden_python = supervisor_python.with_name("pythonw.exe")
            if hidden_python.is_file():
                supervisor_python = hidden_python
        command = [
            str(supervisor_python),
            str(Path(__file__).resolve()),
            "supervise",
            "--phase-dir",
            str(phase_dir),
        ]
        popen_kwargs: dict[str, Any] = {
            "stdin": subprocess.DEVNULL,
            "stdout": subprocess.DEVNULL,
            "stderr": subprocess.DEVNULL,
            "cwd": str(repo),
        }
        if os.name == "nt":
            popen_kwargs["creationflags"] = (
                getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
                | getattr(subprocess, "DETACHED_PROCESS", 0)
                | getattr(subprocess, "CREATE_NO_WINDOW", 0)
            )
        else:
            popen_kwargs["start_new_session"] = True
        supervisor = subprocess.Popen(command, **popen_kwargs)
        result["execution"]["supervisor_pid"] = supervisor.pid
        atomic_json(phase_dir / "result.json", result)
        output["processId"] = supervisor.pid
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0


def redact_diagnostic(value: str, limit: int = 4000) -> str:
    tail = value[-limit:]
    substitutions = [
        (r"(?i)(authorization:\s*bearer\s+)[^\s]+", r"\1[REDACTED]"),
        (r"(?i)((?:token|secret|password|api[_-]?key)\s*[:=]\s*)[^\s,;]+", r"\1[REDACTED]"),
        (r"-----BEGIN [^-]+ PRIVATE KEY-----[\s\S]*?-----END [^-]+ PRIVATE KEY-----", "[REDACTED PRIVATE KEY]"),
    ]
    for pattern, replacement in substitutions:
        tail = re.sub(pattern, replacement, tail)
    return tail


# Codex carga los MCP de la config del usuario y algunos fallan al conectar;
# ese ruido no es un fallo de la fase.
MCP_NOISE = re.compile(r"(?i)rmcp::|mcp client for|mcp server .*(fail|error)|127\.0\.0\.1:8000")


def filter_noise(value: str) -> str:
    return "\n".join(line for line in value.splitlines() if not MCP_NOISE.search(line))


def parse_structured_output(text: str) -> dict[str, Any]:
    """Devuelve el último objeto con todas las claves del esquema que aparezca en el texto."""
    decoder = json.JSONDecoder()
    encontrados: list[dict[str, Any]] = []
    posicion = 0
    while True:
        inicio = text.find("{", posicion)
        if inicio == -1:
            break
        try:
            value, fin = decoder.raw_decode(text, inicio)
        except json.JSONDecodeError:
            posicion = inicio + 1
            continue
        posicion = fin
        if not isinstance(value, dict):
            continue
        if isinstance(value.get("result"), dict):
            value = value["result"]
        if all(field in value for field in RESULT_SCHEMA["required"]):
            encontrados.append(value)
    if encontrados:
        return encontrados[-1]
    raise RuntimeError("Codex did not return the required structured JSON")


def parse_event_stream(stdout: str) -> dict[str, Any]:
    """Lee el flujo JSONL de `codex exec --json`: mensajes del agente, uso y errores."""
    messages: list[str] = []
    errors: list[str] = []
    usage: dict[str, int] = {}
    for line in stdout.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(event, dict):
            continue
        kind = str(event.get("type") or "")
        item = event.get("item")
        if kind == "item.completed" and isinstance(item, dict):
            if "message" in str(item.get("type") or "") and isinstance(item.get("text"), str):
                messages.append(item["text"])
        elif kind == "turn.completed" and isinstance(event.get("usage"), dict):
            for key, value in event["usage"].items():
                if isinstance(value, int):
                    usage[key] = usage.get(key, 0) + value
        elif kind in {"turn.failed", "error"}:
            detail = event.get("message") or (event.get("error") or {}).get("message")
            if detail:
                errors.append(str(detail))
    return {"messages": messages, "usage": usage or None, "errors": errors}


def load_structured_result(last_message_path: Path, stdout: str, events: dict[str, Any]) -> dict[str, Any]:
    if last_message_path.is_file():
        try:
            text = last_message_path.read_text(encoding="utf-8-sig")
            return parse_structured_output(text)
        except (OSError, RuntimeError):
            pass
    for message in reversed(events["messages"]):
        try:
            return parse_structured_output(message)
        except RuntimeError:
            continue
    return parse_structured_output(stdout)


def launch_codex_process(command: list[str], repo: Path) -> subprocess.Popen[str]:
    extra: dict[str, Any] = {}
    if os.name == "nt":
        extra["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    else:
        extra["start_new_session"] = True
    return subprocess.Popen(
        command,
        cwd=str(repo),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        **extra,
    )


def supervise_command(args: argparse.Namespace) -> int:
    phase_dir = Path(args.phase_dir).expanduser().resolve()
    handoff = read_json(phase_dir / "handoff.json")
    result_path = phase_dir / "result.json"
    result = read_json(result_path)
    codex_bin = resolve_codex()
    if not codex_bin:
        result["state"] = "failed"
        result["blockers"] = ["Codex binary not found"]
        result["execution"]["supervisor_pid"] = None
        result["execution"]["finished_at"] = now_iso()
        result["execution"]["exit_code"] = 127
        result["updated_at"] = now_iso()
        atomic_json(result_path, result)
        return 127

    result["execution"]["supervisor_pid"] = os.getpid()
    atomic_json(result_path, result)
    repo = Path(handoff["repository"]["path"])
    crash: str | None = None
    code = 0
    try:
        will_chain = handoff["task"]["mode"] == "implement" and handoff["task"].get(
            "auto_review", True
        )
        estado = run_codex_once(
            handoff, result, result_path, repo, phase_dir, codex_bin, will_chain=will_chain
        )
        if will_chain and estado.get("state") == "pass":
            estado = run_review_chain(handoff, estado, result_path, repo, phase_dir, codex_bin)
        code = estado.get("execution", {}).get("exit_code") or 0
    except Exception as error:
        crash = str(error)
        code = 1
    finally:
        finalize_supervisor(result_path, crash)
    return code


def finalize_supervisor(result_path: Path, crash: str | None = None) -> None:
    """Único punto donde el supervisor se da por terminado."""
    try:
        latest = read_json(result_path)
    except RuntimeError:
        return
    execution = latest.setdefault("execution", {})
    execution["supervisor_pid"] = None
    execution["codex_pid"] = None
    execution["chain_running"] = False
    execution["finished_at"] = execution.get("finished_at") or now_iso()
    if crash or latest.get("state") == "pending":
        latest["state"] = "failed"
        latest["blockers"] = list(latest.get("blockers") or []) + [
            f"supervisor_error:{crash}" if crash else "supervisor_exited_without_result"
        ]
    latest["updated_at"] = now_iso()
    atomic_json(result_path, latest)


def add_usage(total: dict[str, int] | None, usage: dict[str, int] | None) -> dict[str, int] | None:
    if not usage:
        return total
    merged = dict(total or {})
    for key, value in usage.items():
        merged[key] = merged.get(key, 0) + value
    return merged


def run_review_chain(
    handoff: dict[str, Any],
    estado: dict[str, Any],
    result_path: Path,
    repo: Path,
    phase_dir: Path,
    codex_bin: str,
) -> dict[str, Any]:
    """Reclama tests, revisa lo implementado, corrige y vuelve a revisar."""
    cadena: list[dict[str, Any]] = []
    total = (estado.get("execution") or {}).get("usage")

    def stage(nombre: str, modo: str, objetivo: str) -> dict[str, Any]:
        nonlocal total
        derivado = derive_handoff(handoff, modo, objetivo, repo)
        corrida = run_codex_once(
            derivado,
            initial_result(
                handoff["phase_id"],
                handoff["attempt_id"],
                modo,
                supervisor_pid=os.getpid(),
                integrity=integrity_hash(derivado),
                chain_running=True,
            ),
            result_path,
            repo,
            phase_dir,
            codex_bin,
            keep_result=False,
            chain_running=True,
        )
        total = add_usage(total, (corrida.get("execution") or {}).get("usage"))
        cadena.append(compact_run(nombre, corrida))
        return corrida

    def close(final: dict[str, Any]) -> dict[str, Any]:
        execution = final.setdefault("execution", {})
        execution["usage_total"] = total
        execution["chain_running"] = False
        final["integrity"] = integrity_hash(handoff)
        final["chain"] = cadena
        final["updated_at"] = now_iso()
        atomic_json(result_path, final)
        return final

    if handoff["task"].get("require_tests", True) and not toco_tests(
        (estado.get("guardrails") or {}).get("changed_since_start") or []
    ):
        tests = stage("tests", "implement", TESTS_OBJECTIVE)
        if tests.get("state") != "pass":
            return close(tests)
        estado = tests

    revision = stage("review", "review", REVIEW_OBJECTIVE)

    if tiene_hallazgos(revision):
        correccion = stage("fix", "implement", build_fix_objective(revision))
        revision_final = stage("review", "review", REVIEW_OBJECTIVE)
        if tiene_hallazgos(revision_final):
            estado = revision_final
            if estado.get("state") == "pass":
                estado["state"] = "blocked"
        else:
            estado = correccion

    return close(estado)


def compact_run(etapa: str, estado: dict[str, Any]) -> dict[str, Any]:
    return {
        "stage": etapa,
        "state": estado.get("state"),
        "summary": estado.get("summary"),
        "blockers": estado.get("blockers") or [],
        "validations": estado.get("validations") or [],
        "usage": (estado.get("execution") or {}).get("usage"),
    }


def tiene_hallazgos(revision: dict[str, Any]) -> bool:
    if revision.get("state") != "pass":
        return True
    return bool(revision.get("blockers"))


# Un archivo de test en los stacks que usa el usuario: JS/TS (`x.test.ts`,
# `__tests__/`), Python (`test_x.py`, `x_test.py`) y las carpetas `tests/`.
PATRON_TEST = re.compile(
    r"(^|/)(tests?|__tests__|spec)(/|$)"
    r"|\.(test|spec)\.[cm]?[jt]sx?$"
    r"|(^|/)test_[^/]+\.py$"
    r"|_test\.(py|go|rb)$",
    re.IGNORECASE,
)


def toco_tests(paths: list[str]) -> bool:
    return any(PATRON_TEST.search(path) for path in paths)


TESTS_OBJECTIVE = (
    "La implementación quedó sin tests: ningún archivo de prueba cambió. "
    "Agrega ahora los tests que faltan para lo que acabas de implementar — "
    "funcionalidad nueva y correcciones de error, casos normales y de borde — "
    "dentro de allowed_paths, y ejecútalos junto al resto de validation_commands "
    "antes de terminar. No cambies la implementación salvo que un test revele un "
    "error real. Es una regla del usuario, no una sugerencia: una fase sin tests "
    "se considera incompleta."
)

REVIEW_OBJECTIVE = (
    "Revisa lo que se acaba de implementar en esta fase, de forma estrictamente "
    "no invasiva: no edites archivos, no crees reportes ni ejecutes build o "
    "tests. Compara contra la rama base e incluye los cambios sin commit y los "
    "archivos nuevos. Busca bugs reales, regresiones y violaciones del AGENTS.md "
    "del repo. Reporta cada hallazgo con archivo, línea y severidad "
    "(alta, media o baja) dentro de blockers, y deja state en pass solo si no "
    "encontraste nada."
)

FIX_POLICY = (
    "Corrige los hallazgos de la revisión con este criterio: **alta y media "
    "siempre**; **baja solo si es directa** (renombres, comentarios que quedaron "
    "mentirosos, validaciones simples, duplicación evidente, manejo de error que "
    "falta). Las de baja que impliquen rediseño o decisiones de producto NO se "
    "tocan: se listan en next_step para el coordinador. Vuelve a ejecutar las "
    "validaciones de la fase antes de terminar."
)


def build_fix_objective(revision: dict[str, Any]) -> str:
    hallazgos = revision.get("blockers") or []
    detalle = "\n".join(f"- {item}" for item in hallazgos) or "- (ver summary)"
    return (
        "Corrige los hallazgos de la revisión de esta misma fase.\n\n"
        f"Resumen de la revisión: {revision.get('summary') or 'sin resumen'}\n\n"
        f"Hallazgos:\n{detalle}\n\n" + FIX_POLICY
    )


def derive_handoff(
    handoff: dict[str, Any], mode: str, objective: str, repo: Path
) -> dict[str, Any]:
    derivado = json.loads(json.dumps(handoff))
    derivado["task"]["mode"] = mode
    derivado["task"]["objective"] = objective
    derivado["rules"] = mode_rules_for(mode)
    # Cada etapa se audita contra el estado en que la recibe; con la foto
    # original, los cambios del implement previo se leerían como escrituras
    # del review.
    derivado["repository"]["snapshot"] = snapshot(repo)
    return derivado


def mode_rules_for(mode: str) -> list[str]:
    comunes = [
        "No hagas commit, push, PR, merge ni deploy.",
        "No levantes servidores de desarrollo.",
        "No cambies de rama.",
    ]
    if mode == "review":
        return [
            "No edites ningún archivo, ni siquiera para corregir algo evidente.",
            "No ejecutes build, tests ni comandos que escriban artefactos.",
            *comunes,
        ]
    return [
        "Edita únicamente allowed_paths.",
        "Lee y busca libremente con comandos de solo lectura; para probar usa solo validation_commands.",
        *comunes,
    ]


def run_codex_once(
    handoff: dict[str, Any],
    result: dict[str, Any],
    result_path: Path,
    repo: Path,
    phase_dir: Path,
    codex_bin: str,
    keep_result: bool = True,
    chain_running: bool = False,
    will_chain: bool = False,
) -> dict[str, Any]:
    prompt = build_task_prompt(handoff)
    prompt_path = phase_dir / "prompt.md"
    schema_path = phase_dir / "schema.json"
    last_message_path = phase_dir / "last-message.json"
    prompt_path.write_text(prompt, encoding="utf-8")
    atomic_json(schema_path, RESULT_SCHEMA)
    if last_message_path.exists():
        last_message_path.unlink()
    if not keep_result:
        atomic_json(result_path, result)
    command = build_codex_command(handoff, codex_bin, schema_path, last_message_path)
    process = launch_codex_process(command, repo)
    result["execution"]["codex_pid"] = process.pid
    atomic_json(result_path, result)
    stdout, stderr = process.communicate(input=prompt)
    stdout = stdout or ""
    stderr = stderr or ""
    latest = read_json(result_path)
    latest["execution"]["exit_code"] = process.returncode
    latest["execution"]["finished_at"] = now_iso()
    latest["execution"]["codex_pid"] = None
    events = parse_event_stream(stdout)
    latest["execution"]["usage"] = events["usage"]
    try:
        structured = load_structured_result(last_message_path, stdout, events)
        for key in RESULT_SCHEMA["required"]:
            latest[key] = structured[key]
        if process.returncode != 0 and latest["state"] == "pass":
            latest["state"] = "failed"
            latest["blockers"] = list(latest.get("blockers") or []) + [
                f"Codex exited with code {process.returncode}"
            ]
    except RuntimeError as error:
        latest["state"] = "failed"
        latest["summary"] = "Codex terminó sin un resultado estructurado válido."
        latest["blockers"] = [str(error)]
    if latest["state"] == "failed" or process.returncode != 0:
        detalle = [filter_noise(stderr), *events["errors"]]
        diagnostic = "\n".join(part for part in detalle if part.strip())
        if not diagnostic.strip():
            diagnostic = stdout
        latest["execution"]["diagnostic"] = redact_diagnostic(diagnostic)
    latest["guardrails"] = evaluate_guardrails(handoff, latest, repo)
    if latest["guardrails"]["violations"] and latest["state"] == "pass":
        latest["state"] = "failed"
        latest["blockers"] = list(latest.get("blockers") or []) + list(
            latest["guardrails"]["violations"]
        )
    latest["execution"]["chain_running"] = bool(
        chain_running or (will_chain and latest["state"] == "pass")
    )
    latest["updated_at"] = now_iso()
    atomic_json(result_path, latest)
    return latest


def load_phase(phase_dir_value: str) -> tuple[Path, dict[str, Any], dict[str, Any]]:
    phase_dir = Path(phase_dir_value).expanduser().resolve()
    handoff = read_json(phase_dir / "handoff.json")
    result = read_json(phase_dir / "result.json")
    declared = Path(handoff["phase_directory"]).resolve()
    if declared != phase_dir:
        raise RuntimeError("Phase directory does not match handoff.json")
    root = Path(handoff["handoff_root"]).resolve()
    if phase_dir.parent.parent != root:
        raise RuntimeError("Phase directory is outside the declared handoff root")
    if handoff["phase_id"] != result.get("phase_id"):
        raise RuntimeError("result.json belongs to a different phase")
    if handoff["attempt_id"] != result.get("attempt_id"):
        raise RuntimeError("result.json belongs to a different attempt")
    return phase_dir, handoff, result


def is_running(execution: dict[str, Any]) -> bool:
    return process_running(execution.get("supervisor_pid")) or process_running(
        execution.get("codex_pid")
    )


def status_command(args: argparse.Namespace) -> int:
    phase_dir, handoff, _ = load_phase(args.phase_dir)
    result_path = phase_dir / "result.json"
    repo = Path(handoff["repository"]["path"])
    for _ in range(3):
        result = read_json(result_path)
        original = json.dumps(result, sort_keys=True)
        execution = result.get("execution") or {}
        running = is_running(execution)
        if running and execution.get("chain_running"):
            # Cadena en curso: el resultado de cada etapa es provisional.
            guardrails = result.get("guardrails")
            break
        guardrails = evaluate_guardrails(handoff, result, repo, check_remote=False)
        changed = False
        if result.get("state") == "pending" and not running:
            result["state"] = "failed"
            result["summary"] = result.get("summary") or "El proceso terminó sin cerrar el resultado."
            result["blockers"] = list(result.get("blockers") or []) + [
                "stale_pending_without_process"
            ]
            changed = True
        elif execution.get("chain_running") and not running:
            result["state"] = "failed"
            result["blockers"] = list(result.get("blockers") or []) + [
                "chain_interrupted_without_process"
            ]
            changed = True
        if guardrails["violations"] and result.get("state") == "pass":
            result["state"] = "failed"
            result["blockers"] = list(result.get("blockers") or []) + guardrails["violations"]
            changed = True
        if not changed:
            break
        result["execution"]["finished_at"] = result["execution"].get("finished_at") or now_iso()
        result["execution"]["chain_running"] = False
        result["guardrails"] = guardrails
        result["updated_at"] = now_iso()
        # Solo se escribe si el supervisor no tocó el archivo mientras tanto.
        if json.dumps(read_json(result_path), sort_keys=True) == original:
            atomic_json(result_path, result)
            break
    execution = result.get("execution") or {}
    output = {
        "phase_id": handoff["phase_id"],
        "attempt_id": handoff["attempt_id"],
        "mode": handoff["task"]["mode"],
        "state": result["state"],
        "running": running,
        "chain_running": bool(execution.get("chain_running")),
        "process_id": execution.get("supervisor_pid"),
        "summary": result.get("summary"),
        "changes": result.get("changes"),
        "validations": result.get("validations"),
        "blockers": result.get("blockers"),
        "question": result.get("question"),
        "next_step": result.get("next_step"),
        "git": result.get("git"),
        "usage": execution.get("usage_total") or execution.get("usage"),
        "guardrails": guardrails,
        "history_count": len(handoff.get("history") or []),
        "phase_directory": str(phase_dir),
        "handoff_path": str(phase_dir / "handoff.json"),
        "result_path": str(result_path),
    }
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0 if result["state"] == "pass" or running else 2


def wait_command(args: argparse.Namespace) -> int:
    timeout = max(1, min(int(args.timeout_seconds), 55))
    interval = max(1, min(int(args.poll_seconds), 10))
    deadline = time.monotonic() + timeout
    while True:
        _, _, result = load_phase(args.phase_dir)
        execution = result.get("execution") or {}
        running = is_running(execution)
        waiting = result.get("state") == "pending" or bool(execution.get("chain_running"))
        if not waiting or not running:
            return status_command(args)
        if time.monotonic() >= deadline:
            print(
                json.dumps(
                    {
                        "phase_id": result.get("phase_id"),
                        "attempt_id": result.get("attempt_id"),
                        "state": result.get("state"),
                        "running": True,
                        "process_id": execution.get("supervisor_pid"),
                        "summary": result.get("summary"),
                        "phase_directory": str(Path(args.phase_dir).resolve()),
                        "wait_timed_out": True,
                    },
                    ensure_ascii=False,
                    indent=2,
                )
            )
            return 0
        time.sleep(interval)


def markdown_escape(value: Any) -> str:
    return str(value if value is not None else "").replace("|", "\\|").replace("\n", " ")


def report_text(handoff: dict[str, Any], result: dict[str, Any]) -> str:
    attempts = [*list(handoff.get("history") or []), compact_history(handoff, result)]
    lines = [
        f"# Reporte de handoff Codex — {handoff['phase_id']}",
        "",
        f"- **Repo:** `{handoff['repository']['path']}`",
        f"- **Rama inicial:** `{handoff['repository']['branch']}`",
        f"- **HEAD inicial de la ronda actual:** `{handoff['repository']['head']}`",
        f"- **Modelo:** `{(handoff.get('codex') or {}).get('model')}` "
        f"(`{(handoff.get('codex') or {}).get('reasoning_effort')}`)",
        f"- **Estado final:** `{result.get('state')}`",
        f"- **Generado:** `{now_iso()}`",
    ]
    usage = (result.get("execution") or {}).get("usage_total") or (
        result.get("execution") or {}
    ).get("usage")
    if usage:
        lines.append(
            "- **Consumo:** " + ", ".join(f"{key}={value}" for key, value in sorted(usage.items()))
        )
    plan = handoff.get("task", {}).get("plan")
    if plan:
        lines.extend(
            [
                f"- **Plan fuente:** `{plan['path']}`",
                f"- **SHA-256 del plan:** `{plan['sha256']}`",
                "",
            ]
        )
    else:
        lines.append("")
    lines.extend(
        [
            "## Historial de la fase",
            "",
            "| Intento | Modo | Estado | Objetivo | Resumen |",
            "|---|---|---|---|---|",
        ]
    )
    for attempt in attempts:
        lines.append(
            "| `{}` | `{}` | `{}` | {} | {} |".format(
                markdown_escape(attempt.get("attempt_id")),
                markdown_escape(attempt.get("mode")),
                markdown_escape(attempt.get("state")),
                markdown_escape(attempt.get("objective")),
                markdown_escape(attempt.get("summary")),
            )
        )
    chain = result.get("chain") or []
    if chain:
        lines.extend(["", "## Cadena automática", "", "| Etapa | Estado | Resumen |", "|---|---|---|"])
        for stage in chain:
            lines.append(
                "| `{}` | `{}` | {} |".format(
                    markdown_escape(stage.get("stage")),
                    markdown_escape(stage.get("state")),
                    markdown_escape(stage.get("summary")),
                )
            )
    lines.extend(["", "## Cambios registrados", ""])
    all_changes: list[str] = []
    for attempt in attempts:
        for change in attempt.get("changes") or []:
            if change not in all_changes:
                all_changes.append(change)
    lines.extend([f"- `{change}`" for change in all_changes] or ["- Ninguno registrado."])
    lines.extend(["", "## Validaciones registradas", ""])
    has_validations = False
    for attempt in attempts:
        if attempt.get("validations"):
            has_validations = True
            lines.append(f"### {attempt.get('mode')} — {attempt.get('attempt_id')}")
            lines.append("")
            for validation in attempt["validations"]:
                lines.append(
                    f"- `{markdown_escape(validation.get('command'))}`: "
                    f"{markdown_escape(validation.get('result'))}"
                )
            lines.append("")
    if not has_validations:
        lines.extend(["- Ninguna registrada.", ""])
    lines.extend(["## Git y PR", ""])
    git_data = result.get("git") or {}
    lines.extend(
        [
            f"- **Commit:** `{git_data.get('commit') or 'sin commit'}`",
            f"- **Rama:** `{git_data.get('branch') or handoff['repository']['branch']}`",
            f"- **Push:** `{bool(git_data.get('pushed'))}`",
            f"- **PR:** {git_data.get('pr_url') or 'sin PR registrado'}",
            "",
            "## Guardrails",
            "",
        ]
    )
    guardrails = result.get("guardrails") or {}
    violations = guardrails.get("violations") or []
    lines.append(f"- **Resultado:** `{'pass' if not violations else 'failed'}`")
    lines.append(
        "- **Violaciones:** "
        + (", ".join(f"`{item}`" for item in violations) if violations else "ninguna")
    )
    lines.extend(["", "## Bloqueos y siguiente paso", ""])
    blockers = result.get("blockers") or []
    lines.extend([f"- {blocker}" for blocker in blockers] or ["- Sin bloqueos registrados."])
    lines.extend(
        [
            "",
            f"**Siguiente paso:** {result.get('next_step') or 'No registrado.'}",
            "",
        ]
    )
    return "\n".join(lines)


def report_command(args: argparse.Namespace) -> int:
    _, handoff, result = load_phase(args.phase_dir)
    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    text = report_text(handoff, result)
    temporary = output.with_name(f".{output.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_text(text, encoding="utf-8", newline="\n")
    os.replace(temporary, output)
    print(
        json.dumps(
            {"generated": True, "output": str(output), "attempts": len(handoff.get("history") or []) + 1},
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


def kill_process_tree(pid: Any) -> None:
    if os.name == "nt":
        run(["taskkill", "/PID", str(pid), "/T", "/F"])
        return
    try:
        os.killpg(os.getpgid(int(pid)), signal.SIGTERM)
    except (OSError, ProcessLookupError):
        try:
            os.kill(int(pid), signal.SIGTERM)
        except OSError:
            pass


def cleanup_command(args: argparse.Namespace) -> int:
    phase_dir, handoff, result = load_phase(args.phase_dir)
    execution = result.get("execution") or {}
    running_ids = [
        pid
        for pid in (execution.get("supervisor_pid"), execution.get("codex_pid"))
        if process_running(pid)
    ]
    if running_ids and not args.force_running:
        raise RuntimeError("Codex is still running; stop it explicitly or use --force-running")
    if running_ids:
        for pid in running_ids:
            kill_process_tree(pid)
        time.sleep(1)
    report_output = None
    if args.report_output:
        report_output = str(Path(args.report_output).expanduser().resolve())
        report_args = argparse.Namespace(phase_dir=str(phase_dir), output=report_output)
        report_command(report_args)
    root = Path(handoff["handoff_root"]).resolve()
    if phase_dir == root or root not in phase_dir.parents:
        raise RuntimeError("Refusing to remove outside the declared handoff root")
    shutil.rmtree(phase_dir)
    print(
        json.dumps(
            {
                "removed": True,
                "phase_id": handoff["phase_id"],
                "path": str(phase_dir),
                "report_output": report_output,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)

    start = commands.add_parser("start", help="Create or reuse a phase handoff")
    start.add_argument("--invoker", default="codex")
    start.add_argument("--mode", choices=["implement", "review", "closeout"], default="implement")
    start.add_argument("--objective", required=True)
    start.add_argument("--review-summary", default="")
    start.add_argument(
        "--review-verdict", choices=["pass", "blocked", "needs-user"], default="pass"
    )
    start.add_argument("--next-step", default="")
    start.add_argument("--repo-path", default="")
    start.add_argument("--workspace-root", default="")
    start.add_argument("--handoff-root", default="")
    start.add_argument("--phase-id", default="")
    start.add_argument("--phase-dir", default="")
    start.add_argument("--plan-path", default="")
    start.add_argument(
        "--plan-read-policy", choices=["auto", "full", "verify", "none"], default="auto"
    )
    start.add_argument("--require-full-plan-read", action="store_true")
    start.add_argument("--allowed-path", action="append", default=[])
    start.add_argument("--validation-command", action="append", default=[])
    start.add_argument("--runtime-setup-command", default="")
    start.add_argument("--review-skill-path", default="")
    start.add_argument("--no-auto-review", action="store_true")
    start.add_argument(
        "--no-test-gate",
        action="store_true",
        help="no reclamar tests al terminar implement (fases de docs o config)",
    )
    start.add_argument("--closeout-action", default="")
    start.add_argument("--allow-git-closeout", action="store_true")
    start.add_argument("--git-remote", default="origin")
    start.add_argument("--base-branch", default="develop")
    start.add_argument("--commit-message", default="")
    start.add_argument("--pr-title", default="")
    start.add_argument("--pr-body", default="")
    start.add_argument("--update-existing-pr", action="store_true")
    start.add_argument("--model", default=DEFAULT_MODEL)
    start.add_argument("--reasoning-effort", choices=list(EFFORTS), default="high")
    start.add_argument("--reasoning-rationale", required=True)
    start.add_argument("--require-review-after", action="store_true")
    start.add_argument("--skip-review-gate", action="store_true")
    start.add_argument("--force-handoff", action="store_true")
    start.add_argument("--force-reason", default="")
    start.add_argument("--dry-run", action="store_true")
    start.add_argument("--launch", action="store_true")
    start.set_defaults(function=start_command)

    supervise = commands.add_parser("supervise", help=argparse.SUPPRESS)
    supervise.add_argument("--phase-dir", required=True)
    supervise.set_defaults(function=supervise_command)

    status = commands.add_parser("status", help="Read status and enforce guardrails")
    status.add_argument("--phase-dir", required=True)
    status.set_defaults(function=status_command)

    wait = commands.add_parser("wait", help="Wait up to 55 seconds for a phase update")
    wait.add_argument("--phase-dir", required=True)
    wait.add_argument("--timeout-seconds", type=int, default=55)
    wait.add_argument("--poll-seconds", type=int, default=2)
    wait.set_defaults(function=wait_command)

    report = commands.add_parser("report", help="Generate a Markdown phase report")
    report.add_argument("--phase-dir", required=True)
    report.add_argument("--output", required=True)
    report.set_defaults(function=report_command)

    cleanup = commands.add_parser("cleanup", help="Optionally report and remove a phase")
    cleanup.add_argument("--phase-dir", required=True)
    cleanup.add_argument("--report-output", default="")
    cleanup.add_argument("--force-running", action="store_true")
    cleanup.set_defaults(function=cleanup_command)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        return int(args.function(args))
    except Exception as error:
        print(json.dumps({"error": str(error)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
