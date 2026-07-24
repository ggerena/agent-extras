#!/usr/bin/env python3
"""Portable, two-file handoff supervisor for Grok Build."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 3
PROTECTED_BRANCHES = {"main", "master", "develop"}
FINAL_STATES = {"pass", "blocked", "needs-user", "failed"}
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
    command: list[str], cwd: Path | None = None, check: bool = False
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(f"Command failed ({completed.returncode}): {detail}")
    return completed


def git(repo: Path, *arguments: str, check: bool = False) -> str:
    completed = run(["git", "-C", str(repo), *arguments], check=check)
    return completed.stdout.strip() if completed.returncode == 0 else ""


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
    handoff: dict[str, Any], result: dict[str, Any], repo: Path
) -> dict[str, Any]:
    mode = handoff["task"]["mode"]
    initial = handoff["repository"]["snapshot"]
    allowed = list(handoff["task"].get("allowed_paths") or [])
    current_branch = git(repo, "branch", "--show-current")
    current_head = git(repo, "rev-parse", "HEAD")
    changed = changed_from_snapshot(repo, initial)
    violations: list[str] = []

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
        if (result.get("git") or {}).get("pushed"):
            upstream_head = git(repo, "rev-parse", "@{upstream}")
            if not upstream_head or upstream_head != current_head:
                violations.append(
                    f"pushed_head_not_synced:{upstream_head or '<missing>'}->{current_head}"
                )

    return {
        "checked_at": now_iso(),
        "mode": mode,
        "violations": violations,
        "changed_since_start": changed,
        "committed_since_start": committed_paths,
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
        root = (workspace_path / ".agent-handoffs" / "grok").resolve()
    if root == repo or repo in root.parents:
        raise RuntimeError("Handoff root must be outside the target repo")
    return root, source


def resolve_grok() -> str:
    configured = os.environ.get("GROK_BIN", "")
    candidates = [Path(configured).expanduser()] if configured else []
    candidates.append(Path.home() / ".grok" / "bin" / ("grok.exe" if os.name == "nt" else "grok"))
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate.resolve())
    found = shutil.which("grok")
    return found or ""


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
        execution.get("grok_pid")
    ):
        raise RuntimeError("Previous attempt is still running")
    if result.get("state") not in FINAL_STATES:
        raise RuntimeError("Previous attempt has no final result")
    repository = Path(handoff["repository"]["path"])
    guardrails = evaluate_guardrails(handoff, result, repository)
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
        "No uses aprobaciones automáticas, worktrees, servidores de desarrollo ni secretos.",
        "No modifiques configuración o memoria de Grok.",
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
        "Ejecuta solo validation_commands y elimina artefactos generados fuera de allowed_paths.",
        *common,
    ]


def build_prompt() -> str:
    return (
        "Lee este JSON completo. Actúa solo sobre task y respeta rules. "
        "El coordinador conserva decisiones y aprobación final. "
        "Si task.plan.read_policy es full, lee el plan completo; si es verify, "
        "el supervisor ya verificó su hash: usa history sin releerlo completo; "
        "si es none, no lo leas. "
        "Al terminar, devuelve únicamente JSON válido conforme al schema solicitado. "
        "No escribas result.json: el supervisor lo actualizará de forma atómica."
    )


def initial_result(
    phase_id: str, attempt_id: str, mode: str, supervisor_pid: int | None = None
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "phase_id": phase_id,
        "attempt_id": attempt_id,
        "mode": mode,
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
            "grok_pid": None,
            "started_at": now_iso(),
            "finished_at": None,
            "exit_code": None,
            "diagnostic": None,
        },
        "guardrails": None,
        "updated_at": now_iso(),
    }


def validate_start_args(args: argparse.Namespace, repo: Path) -> None:
    if not args.objective.strip():
        raise RuntimeError("Objective is required")
    if not args.reasoning_effort:
        raise RuntimeError("Reasoning effort is required")
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
    if args.mode == "review" and args.reasoning_effort != "high":
        raise RuntimeError("Review mode requires high reasoning effort")
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
    handoff = {
        "type": "acp",
        "schema_version": SCHEMA_VERSION,
        "content": [{"type": "text", "text": build_prompt()}],
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
            "closeout": (
                {
                    "action": args.closeout_action,
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
        "grok": {
            "model": args.model,
            "reasoning_effort": args.reasoning_effort,
            "reasoning_rationale": args.reasoning_rationale,
        },
        "repository": {
            "path": str(repo),
            "branch": initial["branch"],
            "head": initial["head"],
            "snapshot": initial,
        },
        "history": history,
        "result_path": str(phase_dir / "result.json"),
        "created_at": now_iso(),
    }
    result = initial_result(phase_id, attempt_id, args.mode)
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
    atomic_json(phase_dir / "result.json", result)
    if args.launch:
        command = [
            sys.executable,
            str(Path(__file__).resolve()),
            "supervise",
            "--phase-dir",
            str(phase_dir),
        ]
        creationflags = 0
        popen_kwargs: dict[str, Any] = {
            "stdin": subprocess.DEVNULL,
            "stdout": subprocess.DEVNULL,
            "stderr": subprocess.DEVNULL,
            "cwd": str(repo),
        }
        if os.name == "nt":
            creationflags = (
                getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
                | getattr(subprocess, "DETACHED_PROCESS", 0)
                | getattr(subprocess, "CREATE_NO_WINDOW", 0)
            )
            popen_kwargs["creationflags"] = creationflags
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


def parse_structured_output(stdout: str) -> dict[str, Any]:
    text = stdout.strip()
    candidates = [text]
    for line in reversed(text.splitlines()):
        if line.lstrip().startswith("{"):
            candidates.append(line.strip())
    for candidate in candidates:
        try:
            value = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            if isinstance(value.get("result"), dict):
                value = value["result"]
            if all(field in value for field in RESULT_SCHEMA["required"]):
                return value
    raise RuntimeError("Grok did not return the required structured JSON")


def launch_grok_process(command: list[str], repo: Path) -> subprocess.Popen[str]:
    return subprocess.Popen(
        command,
        cwd=str(repo),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def supervise_command(args: argparse.Namespace) -> int:
    phase_dir = Path(args.phase_dir).expanduser().resolve()
    handoff_path = phase_dir / "handoff.json"
    result_path = phase_dir / "result.json"
    handoff = read_json(handoff_path)
    result = read_json(result_path)
    grok_bin = resolve_grok()
    if not grok_bin:
        result["state"] = "failed"
        result["blockers"] = ["Grok binary not found"]
        result["execution"]["supervisor_pid"] = None
        result["execution"]["finished_at"] = now_iso()
        result["execution"]["exit_code"] = 127
        result["updated_at"] = now_iso()
        atomic_json(result_path, result)
        return 127

    grok = handoff["grok"]
    repo = Path(handoff["repository"]["path"])
    command = [
        grok_bin,
        "--model",
        grok["model"],
        "--reasoning-effort",
        grok["reasoning_effort"],
        "--cwd",
        str(repo),
        "--prompt-file",
        str(handoff_path),
        "--json-schema",
        json.dumps(RESULT_SCHEMA, separators=(",", ":")),
        "--no-subagents",
        "--disable-web-search",
        "--no-memory",
    ]
    process = launch_grok_process(command, repo)
    result["execution"]["grok_pid"] = process.pid
    atomic_json(result_path, result)
    stdout, stderr = process.communicate()
    latest = read_json(result_path)
    latest["execution"]["exit_code"] = process.returncode
    latest["execution"]["finished_at"] = now_iso()
    latest["execution"]["supervisor_pid"] = None
    latest["execution"]["grok_pid"] = None
    try:
        structured = parse_structured_output(stdout)
        for key in RESULT_SCHEMA["required"]:
            latest[key] = structured[key]
        if process.returncode != 0 and latest["state"] == "pass":
            latest["state"] = "failed"
            latest["blockers"] = list(latest.get("blockers") or []) + [
                f"Grok exited with code {process.returncode}"
            ]
        if stderr.strip():
            latest["execution"]["diagnostic"] = redact_diagnostic(stderr)
    except RuntimeError as error:
        latest["state"] = "failed"
        latest["summary"] = "Grok terminó sin un resultado estructurado válido."
        latest["blockers"] = [str(error)]
        diagnostic = "\n".join(part for part in [stderr, stdout] if part.strip())
        latest["execution"]["diagnostic"] = redact_diagnostic(diagnostic)
    latest["guardrails"] = evaluate_guardrails(handoff, latest, repo)
    if latest["guardrails"]["violations"] and latest["state"] == "pass":
        latest["state"] = "failed"
        latest["blockers"] = list(latest.get("blockers") or []) + list(
            latest["guardrails"]["violations"]
        )
    latest["updated_at"] = now_iso()
    atomic_json(result_path, latest)
    return process.returncode


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


def status_command(args: argparse.Namespace) -> int:
    phase_dir, handoff, result = load_phase(args.phase_dir)
    execution = result.get("execution") or {}
    running = process_running(execution.get("supervisor_pid")) or process_running(
        execution.get("grok_pid")
    )
    repo = Path(handoff["repository"]["path"])
    guardrails = evaluate_guardrails(handoff, result, repo)
    result["guardrails"] = guardrails
    if result.get("state") == "pending" and not running:
        result["state"] = "failed"
        result["summary"] = result.get("summary") or "El proceso terminó sin cerrar el resultado."
        result["blockers"] = list(result.get("blockers") or []) + [
            "stale_pending_without_process"
        ]
        result["execution"]["finished_at"] = result["execution"].get("finished_at") or now_iso()
    if guardrails["violations"] and result.get("state") == "pass":
        result["state"] = "failed"
        result["blockers"] = list(result.get("blockers") or []) + guardrails["violations"]
    result["updated_at"] = now_iso()
    atomic_json(phase_dir / "result.json", result)
    output = {
        "phase_id": handoff["phase_id"],
        "attempt_id": handoff["attempt_id"],
        "mode": handoff["task"]["mode"],
        "state": result["state"],
        "running": running,
        "process_id": execution.get("supervisor_pid"),
        "summary": result.get("summary"),
        "changes": result.get("changes"),
        "validations": result.get("validations"),
        "blockers": result.get("blockers"),
        "question": result.get("question"),
        "next_step": result.get("next_step"),
        "git": result.get("git"),
        "guardrails": guardrails,
        "history_count": len(handoff.get("history") or []),
        "phase_directory": str(phase_dir),
        "handoff_path": str(phase_dir / "handoff.json"),
        "result_path": str(phase_dir / "result.json"),
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
        running = process_running(execution.get("supervisor_pid")) or process_running(
            execution.get("grok_pid")
        )
        if result.get("state") != "pending" or not running:
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
        f"# Reporte de handoff Grok — {handoff['phase_id']}",
        "",
        f"- **Repo:** `{handoff['repository']['path']}`",
        f"- **Rama inicial:** `{handoff['repository']['branch']}`",
        f"- **HEAD inicial de la ronda actual:** `{handoff['repository']['head']}`",
        f"- **Estado final:** `{result.get('state')}`",
        f"- **Generado:** `{now_iso()}`",
    ]
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


def cleanup_command(args: argparse.Namespace) -> int:
    phase_dir, handoff, result = load_phase(args.phase_dir)
    execution = result.get("execution") or {}
    running_ids = [
        pid
        for pid in (execution.get("supervisor_pid"), execution.get("grok_pid"))
        if process_running(pid)
    ]
    if running_ids and not args.force_running:
        raise RuntimeError("Grok is still running; stop it explicitly or use --force-running")
    if running_ids and args.force_running:
        for pid in running_ids:
            if os.name == "nt":
                run(["taskkill", "/PID", str(pid), "/T", "/F"])
            else:
                try:
                    os.kill(int(pid), 15)
                except OSError:
                    pass
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
    start.add_argument("--closeout-action", default="")
    start.add_argument("--allow-git-closeout", action="store_true")
    start.add_argument("--git-remote", default="origin")
    start.add_argument("--base-branch", default="develop")
    start.add_argument("--commit-message", default="")
    start.add_argument("--pr-title", default="")
    start.add_argument("--pr-body", default="")
    start.add_argument("--update-existing-pr", action="store_true")
    start.add_argument("--model", default="grok-4.5")
    start.add_argument("--reasoning-effort", choices=["medium", "high"], required=True)
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
