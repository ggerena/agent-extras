import argparse
import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import grok_handoff as handoff  # noqa: E402


STRUCTURED = {
    "state": "pass",
    "summary": "implemented",
    "changes": ["allowed.txt"],
    "validations": [{"command": "test", "result": "pass"}],
    "blockers": [],
    "question": None,
    "next_step": "review",
    "git": None,
}
HEADS = {"develop": "a" * 40, "main": "b" * 40, "master": handoff.ABSENT}
CLOSEOUT_EXTRA = (
    "--closeout-action",
    "checkpoint",
    "--commit-message",
    "msg",
    "--allow-git-closeout",
)


class FakeProcess:
    pid = 43210
    returncode = 0

    def __init__(self, stdout="", stderr="", effect=None):
        self.stdout = stdout
        self.stderr = stderr
        self.effect = effect

    def communicate(self, input=None):
        if self.effect:
            self.effect()
        return self.stdout, self.stderr


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.workspace = self.root / "workspace"
        self.repo = self.workspace / "sample-repo"
        self.repo.mkdir(parents=True)
        (self.workspace / "AGENTS.md").write_text("# rules\n", encoding="utf-8")
        (self.repo / "allowed.txt").write_text("initial\n", encoding="utf-8")
        (self.repo / "outside.txt").write_text("initial\n", encoding="utf-8")
        self.git("init", "-b", "feature/test")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "user.name", "Test")
        self.git("add", "allowed.txt", "outside.txt")
        self.git("commit", "-m", "initial")
        self.plan = self.workspace / "PLAN.md"
        self.plan.write_text("# Plan\n\nImplementar la fase.\n", encoding="utf-8")
        self.handoff_root = self.root / "handoffs"

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *arguments):
        subprocess.run(
            ["git", "-C", str(self.repo), *arguments],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def start(self, mode="implement", phase_dir="", phase_id="phase-a", extra=()):
        arguments = [
            "start",
            "--mode",
            mode,
            "--objective",
            f"{mode} phase",
            "--repo-path",
            str(self.repo),
            "--plan-path",
            str(self.plan),
            "--plan-read-policy",
            "auto",
            "--reasoning-effort",
            "high" if mode == "review" else "medium",
            "--reasoning-rationale",
            "test",
            "--review-summary",
            "pass",
        ]
        if mode != "review":
            arguments.extend(["--allowed-path", "allowed.txt"])
        if phase_dir:
            arguments.extend(["--phase-dir", phase_dir])
        else:
            arguments.extend(["--handoff-root", str(self.handoff_root)])
            arguments.extend(["--phase-id", phase_id])
        arguments.extend(extra)
        args = handoff.parser().parse_args(arguments)
        self.assertEqual(handoff.start_command(args), 0)
        return self.handoff_root / self.repo.name / phase_id

    def complete(self, phase_dir, state="pass"):
        result_path = phase_dir / "result.json"
        result = handoff.read_json(result_path)
        result.update(
            {
                "state": state,
                "summary": "done",
                "changes": [],
                "validations": [],
                "blockers": [],
                "question": None,
                "next_step": None,
                "git": None,
            }
        )
        result["execution"]["finished_at"] = handoff.now_iso()
        handoff.atomic_json(result_path, result)

    def test_reuses_two_files_and_verifies_plan_hash(self):
        phase_dir = self.start()
        self.complete(phase_dir)
        self.start(mode="review", phase_dir=str(phase_dir))
        files = sorted(path.name for path in phase_dir.iterdir())
        self.assertEqual(files, ["handoff.json", "prompt.md", "result.json"])
        contract = handoff.read_json(phase_dir / "handoff.json")
        self.assertEqual(contract["task"]["plan"]["read_policy"], "verify")
        self.assertEqual(len(contract["history"]), 1)
        self.assertEqual(contract["history"][0]["mode"], "implement")
        self.assertNotIn("instructions", contract)

    def test_review_detects_any_write(self):
        phase_dir = self.start(mode="review")
        (self.repo / "outside.txt").write_text("changed\n", encoding="utf-8")
        self.complete(phase_dir)
        _, contract, result = handoff.load_phase(str(phase_dir))
        guardrails = handoff.evaluate_guardrails(contract, result, self.repo)
        self.assertTrue(
            any(item.startswith("review_wrote_files:") for item in guardrails["violations"])
        )

    def test_implement_detects_change_outside_allowed_paths(self):
        phase_dir = self.start()
        (self.repo / "outside.txt").write_text("changed\n", encoding="utf-8")
        self.complete(phase_dir)
        _, contract, result = handoff.load_phase(str(phase_dir))
        guardrails = handoff.evaluate_guardrails(contract, result, self.repo)
        self.assertIn("outside_allowed_paths:outside.txt", guardrails["violations"])

    def test_plan_change_blocks_verify_reuse(self):
        phase_dir = self.start()
        self.complete(phase_dir)
        self.plan.write_text("# Changed plan\n", encoding="utf-8")
        arguments = [
            "start",
            "--mode",
            "review",
            "--objective",
            "review",
            "--repo-path",
            str(self.repo),
            "--handoff-root",
            str(self.handoff_root),
            "--phase-dir",
            str(phase_dir),
            "--plan-path",
            str(self.plan),
            "--plan-read-policy",
            "verify",
            "--reasoning-effort",
            "high",
            "--reasoning-rationale",
            "test",
            "--review-summary",
            "pass",
        ]
        args = handoff.parser().parse_args(arguments)
        with self.assertRaisesRegex(RuntimeError, "Source plan changed"):
            handoff.start_command(args)

    def test_guardrail_violation_blocks_next_attempt(self):
        phase_dir = self.start()
        (self.repo / "outside.txt").write_text("changed\n", encoding="utf-8")
        self.complete(phase_dir)
        arguments = [
            "start",
            "--mode",
            "review",
            "--objective",
            "review",
            "--repo-path",
            str(self.repo),
            "--handoff-root",
            str(self.handoff_root),
            "--phase-dir",
            str(phase_dir),
            "--reasoning-effort",
            "high",
            "--reasoning-rationale",
            "test",
            "--review-summary",
            "pass",
        ]
        args = handoff.parser().parse_args(arguments)
        with self.assertRaisesRegex(RuntimeError, "guardrail violations"):
            handoff.start_command(args)

    def supervise(self, phase_dir, process):
        arguments = argparse.Namespace(phase_dir=str(phase_dir))
        with mock.patch.object(handoff, "resolve_grok", return_value="grok"), mock.patch.object(
            handoff, "launch_grok_process", return_value=process
        ):
            return handoff.supervise_command(arguments)

    def test_chain_stage_snapshot_ignores_earlier_implement_changes(self):
        phase_dir = self.start()
        contract = handoff.read_json(phase_dir / "handoff.json")
        (self.repo / "allowed.txt").write_text("implemented\n", encoding="utf-8")
        review = handoff.derive_handoff(contract, "review", "review", self.repo)
        guardrails = handoff.evaluate_guardrails(
            review, dict(STRUCTURED, integrity=handoff.integrity_hash(review)), self.repo
        )
        self.assertEqual(guardrails["violations"], [])

    def test_status_and_wait_do_not_close_a_live_chain(self):
        phase_dir = self.start()
        result_path = phase_dir / "result.json"
        for state in ("pending", "pass"):
            result = handoff.read_json(result_path)
            result["state"] = state
            result["execution"]["supervisor_pid"] = os.getpid()
            result["execution"]["chain_running"] = True
            handoff.atomic_json(result_path, result)
            before = result_path.read_text(encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()) as out:
                self.assertEqual(
                    handoff.status_command(argparse.Namespace(phase_dir=str(phase_dir))), 0
                )
            self.assertTrue(json.loads(out.getvalue())["running"])
            self.assertEqual(result_path.read_text(encoding="utf-8"), before)
            with contextlib.redirect_stdout(io.StringIO()) as out:
                handoff.wait_command(
                    argparse.Namespace(phase_dir=str(phase_dir), timeout_seconds=1, poll_seconds=1)
                )
            self.assertTrue(json.loads(out.getvalue()).get("wait_timed_out"))
        with self.assertRaisesRegex(RuntimeError, "still running"):
            self.start(mode="review", phase_dir=str(phase_dir))

        result = handoff.read_json(result_path)
        result["execution"]["supervisor_pid"] = None
        handoff.atomic_json(result_path, result)
        with contextlib.redirect_stdout(io.StringIO()):
            handoff.status_command(argparse.Namespace(phase_dir=str(phase_dir)))
        self.assertEqual(handoff.read_json(result_path)["state"], "failed")

    def test_failed_tests_stage_cuts_the_chain(self):
        phase_dir = self.start()
        contract = handoff.read_json(phase_dir / "handoff.json")
        calls = []

        def fake(derived, result, result_path, repo, prompt_path, binary, keep_result=True, **_):
            calls.append(derived["task"]["mode"])
            return dict(STRUCTURED, state="failed", execution={})

        estado = dict(STRUCTURED, execution={}, guardrails={"changed_since_start": ["src/x.py"]})
        with mock.patch.object(handoff, "run_grok_once", side_effect=fake):
            final = handoff.run_review_chain(
                contract, estado, phase_dir / "result.json", self.repo,
                phase_dir / "prompt.md", "grok",
            )
        self.assertEqual(calls, ["implement"])
        self.assertEqual(final["state"], "failed")
        self.assertEqual([stage["stage"] for stage in final["chain"]], ["tests"])
        stored = handoff.read_json(phase_dir / "result.json")
        self.assertEqual(stored["state"], "failed")
        self.assertFalse(stored["execution"]["chain_running"])

    def test_review_prompt_does_not_demand_validation_commands(self):
        phase_dir = self.start(mode="review", extra=("--validation-command", "npm test"))
        prompt = (phase_dir / "prompt.md").read_text(encoding="utf-8")
        self.assertNotIn("Validaciones obligatorias", prompt)
        self.assertIn("No se ejecutan en review", prompt)
        implement_dir = self.start(phase_id="phase-i", extra=("--validation-command", "npm test"))
        self.assertIn(
            "Validaciones obligatorias", (implement_dir / "prompt.md").read_text(encoding="utf-8")
        )

    def test_remote_protection_is_checked_once_and_reused(self):
        with mock.patch.object(handoff, "remote_heads", return_value=dict(HEADS)):
            phase_dir = self.start(mode="closeout", extra=CLOSEOUT_EXTRA)
            self.supervise(phase_dir, FakeProcess(stdout=json.dumps(STRUCTURED)))
        self.assertEqual(handoff.read_json(phase_dir / "result.json")["state"], "pass")

        moved = dict(HEADS, develop="c" * 40)
        with mock.patch.object(handoff, "remote_heads", return_value=moved) as query:
            with contextlib.redirect_stdout(io.StringIO()):
                handoff.status_command(argparse.Namespace(phase_dir=str(phase_dir)))
            self.assertEqual(handoff.read_json(phase_dir / "result.json")["state"], "pass")
            self.start(mode="review", phase_dir=str(phase_dir))
            query.assert_not_called()

        with mock.patch.object(handoff, "remote_heads", return_value=dict(HEADS)):
            other = self.start(mode="closeout", phase_id="phase-m", extra=CLOSEOUT_EXTRA)
        with mock.patch.object(handoff, "remote_heads", return_value=moved):
            self.supervise(other, FakeProcess(stdout=json.dumps(STRUCTURED)))
        stored = handoff.read_json(other / "result.json")
        self.assertEqual(stored["state"], "failed")
        with mock.patch.object(handoff, "remote_heads", side_effect=AssertionError("no query")):
            with contextlib.redirect_stdout(io.StringIO()):
                handoff.status_command(argparse.Namespace(phase_dir=str(other)))
        self.assertTrue(
            any(item.startswith("protected_remote_branch_changed:develop") for item in stored["blockers"])
        )

    def test_closeout_refuses_to_start_when_ls_remote_fails(self):
        broken = dict(HEADS, develop=None)
        with mock.patch.object(handoff, "remote_heads", return_value=broken):
            with self.assertRaisesRegex(RuntimeError, "Cannot query remote"):
                self.start(mode="closeout", extra=CLOSEOUT_EXTRA)

        with mock.patch.object(handoff, "remote_heads", return_value=dict(HEADS)):
            phase_dir = self.start(mode="closeout", phase_id="phase-a2", extra=CLOSEOUT_EXTRA)
        contract = handoff.read_json(phase_dir / "handoff.json")
        self.assertEqual(contract["repository"]["remote_heads"]["master"], handoff.ABSENT)
        result = handoff.read_json(phase_dir / "result.json")
        appeared = dict(HEADS, master="d" * 40)
        with mock.patch.object(handoff, "remote_heads", return_value=appeared):
            guardrails = handoff.evaluate_guardrails(contract, result, self.repo)
        self.assertTrue(
            any(item.startswith("protected_remote_branch_changed:master") for item in guardrails["violations"])
        )

    def test_report_then_cleanup(self):
        phase_dir = self.start()
        self.complete(phase_dir)
        output = self.root / "REPORT.md"
        report_args = argparse.Namespace(phase_dir=str(phase_dir), output=str(output))
        self.assertEqual(handoff.report_command(report_args), 0)
        report = output.read_text(encoding="utf-8")
        self.assertIn("# Reporte de handoff Grok", report)
        cleanup_args = argparse.Namespace(
            phase_dir=str(phase_dir), report_output="", force_running=False
        )
        self.assertEqual(handoff.cleanup_command(cleanup_args), 0)
        self.assertFalse(phase_dir.exists())

    def test_supervisor_persists_structured_result(self):
        phase_dir = self.start()
        structured = {
            "state": "pass",
            "summary": "implemented",
            "changes": ["allowed.txt"],
            "validations": [{"command": "test", "result": "pass"}],
            "blockers": [],
            "question": None,
            "next_step": "review",
            "git": None,
        }

        class FakeProcess:
            pid = 43210
            returncode = 0

            def __init__(self, *args, **kwargs):
                pass

            def communicate(self):
                return json.dumps(structured), ""

        arguments = argparse.Namespace(phase_dir=str(phase_dir))
        with mock.patch.object(handoff, "resolve_grok", return_value="grok"), mock.patch.object(
            handoff, "launch_grok_process", return_value=FakeProcess()
        ):
            self.assertEqual(handoff.supervise_command(arguments), 0)
        result = handoff.read_json(phase_dir / "result.json")
        self.assertEqual(result["state"], "pass")
        self.assertEqual(result["summary"], "implemented")
        self.assertEqual(result["execution"]["exit_code"], 0)
        self.assertIsNone(result["execution"]["supervisor_pid"])

    def test_parses_result_fenced_inside_text_field(self):
        salida = json.dumps(
            {
                "text": "Listo.```json\n" + json.dumps(STRUCTURED) + "\n```",
                "stopReason": "end_turn",
            }
        )
        self.assertEqual(handoff.parse_structured_output(salida)["summary"], "implemented")

    def test_closeout_denies_merge_and_force_push(self):
        flags = handoff.build_permission_flags(
            {
                "task": {"mode": "closeout", "validation_commands": []},
                "repository": {"path": str(Path.cwd())},
            }
        )
        denegados = {flags[i + 1] for i, flag in enumerate(flags) if flag == "--deny"}
        for patron in ("gh pr merge*", "git push --force*", "git push *:*"):
            self.assertIn(f"Bash({patron})", denegados)
        self.assertIn("Bash(git push*)", flags)


if __name__ == "__main__":
    unittest.main()
