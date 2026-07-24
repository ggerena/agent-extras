import argparse
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import grok_handoff as handoff  # noqa: E402


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

    def start(self, mode="implement", phase_dir="", phase_id="phase-a"):
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
        self.assertEqual(files, ["handoff.json", "result.json"])
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


if __name__ == "__main__":
    unittest.main()
