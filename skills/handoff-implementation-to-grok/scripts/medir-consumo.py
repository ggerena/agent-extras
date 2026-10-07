#!/usr/bin/env python3
"""Compara lo que consume el coordinador (Claude Code) contra lo que produce Grok.

Sirve para responder si delegar en Grok realmente ahorra plan del coordinador, en
vez de estimarlo a ojo. Une tres fuentes que ya existen:

- transcripts de Claude Code (`~/.claude/projects/<proyecto>/*.jsonl`), que traen
  el `usage` de cada mensaje;
- `result.json` de cada fase de la skill, que trae costo y tokens de Grok;
- `git diff --shortstat` de los repos, para saber cuánto código se entregó.

Uso:
    python medir-consumo.py --proyecto C--Users-gery--Code-gear3 \
        --handoffs C:/Users/gery_/Code/gear3/.agent-handoffs/grok \
        --repo C:/Users/gery_/Code/gear3/goflow/goflow-api develop
"""

from __future__ import annotations

import argparse
import glob
import io
import json
import os
import re
import subprocess
from pathlib import Path


def tokens_claude(proyecto: Path, sesion: str | None) -> dict:
    archivos = sorted(glob.glob(str(proyecto / "*.jsonl")), key=os.path.getmtime)
    if sesion:
        archivos = [a for a in archivos if sesion in os.path.basename(a)]
    elif archivos:
        archivos = [archivos[-1]]
    total = {"mensajes": 0, "input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
    for archivo in archivos:
        for linea in io.open(archivo, encoding="utf-8"):
            try:
                dato = json.loads(linea)
            except json.JSONDecodeError:
                continue
            mensaje = dato.get("message")
            uso = mensaje.get("usage") if isinstance(mensaje, dict) else None
            if not uso:
                continue
            total["mensajes"] += 1
            total["input"] += uso.get("input_tokens", 0)
            total["output"] += uso.get("output_tokens", 0)
            total["cache_read"] += uso.get("cache_read_input_tokens", 0)
            total["cache_write"] += uso.get("cache_creation_input_tokens", 0)
    total["sesiones"] = [os.path.basename(a)[:8] for a in archivos]
    return total


def consumo_grok(raiz: Path) -> dict:
    fases = []
    costo = 0.0
    tokens = 0
    for archivo in glob.glob(str(raiz / "*" / "*" / "result.json")):
        try:
            dato = json.load(io.open(archivo, encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        diagnostico = (dato.get("execution") or {}).get("diagnostic") or ""
        usd = re.search(r'"total_cost_usd":\s*([0-9.]+)', diagnostico)
        tks = re.search(r'"total_tokens":\s*(\d+)', diagnostico)
        if not usd:
            continue
        costo += float(usd.group(1))
        tokens += int(tks.group(1)) if tks else 0
        fases.append(
            {
                "repo": Path(archivo).parent.parent.name,
                "estado": dato.get("state"),
                "usd": round(float(usd.group(1)), 4),
            }
        )
    return {"fases": fases, "usd": round(costo, 4), "tokens": tokens}


def lineas_entregadas(repo: Path, base: str) -> dict:
    salida = subprocess.run(
        ["git", "-C", str(repo), "diff", "--shortstat", f"{base}...HEAD"],
        capture_output=True,
        text=True,
    ).stdout
    agregadas = re.search(r"(\d+) insertion", salida)
    borradas = re.search(r"(\d+) deletion", salida)
    return {
        "repo": repo.name,
        "agregadas": int(agregadas.group(1)) if agregadas else 0,
        "borradas": int(borradas.group(1)) if borradas else 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--proyecto", required=True, help="carpeta en ~/.claude/projects")
    parser.add_argument("--sesion", default=None, help="prefijo del id de sesión")
    parser.add_argument("--handoffs", default=None, help="raíz .agent-handoffs/grok")
    parser.add_argument(
        "--repo",
        nargs=2,
        action="append",
        metavar=("RUTA", "BASE"),
        default=[],
        help="repo y rama base, repetible",
    )
    args = parser.parse_args()

    base_claude = Path.home() / ".claude" / "projects" / args.proyecto
    claude = tokens_claude(base_claude, args.sesion)
    print(f"Claude Code — sesiones {', '.join(claude.pop('sesiones')) or '(ninguna)'}")
    for clave, valor in claude.items():
        print(f"  {clave:12} {valor:>12,}")

    if args.handoffs:
        grok = consumo_grok(Path(args.handoffs))
        print(f"\nGrok — {len(grok['fases'])} fases con costo registrado")
        print(f"  usd          {grok['usd']:>12}")
        print(f"  tokens       {grok['tokens']:>12,}")
        fallidas = [f for f in grok["fases"] if f["estado"] != "pass"]
        if fallidas:
            perdido = round(sum(f["usd"] for f in fallidas), 4)
            print(f"  {len(fallidas)} fases sin pasar, {perdido} usd gastados en ellas")

    entregado = 0
    for ruta, base in args.repo:
        stat = lineas_entregadas(Path(ruta), base)
        entregado += stat["agregadas"]
        print(f"\n{stat['repo']}: +{stat['agregadas']} / -{stat['borradas']} líneas")

    if entregado and claude["output"]:
        print(
            f"\nTokens de salida del coordinador por línea entregada: "
            f"{claude['output'] / entregado:.1f}"
        )
        print("Cuanto más bajo, más trabajo hizo Grok en vez del coordinador.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
