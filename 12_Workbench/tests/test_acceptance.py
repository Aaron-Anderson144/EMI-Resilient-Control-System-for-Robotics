"""Acceptance adapter boundaries; synthetic fixtures never create acceptance."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("emi_workbench_acceptance", Path(__file__).resolve().parents[1] / "acceptance.py")
acceptance = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(acceptance)


class AcceptanceAdapterTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.receipt = self.root / "receipt.json"
        self.verifier = self.root / acceptance.VERIFIER_RELATIVE_PATH
        self.verifier.parent.mkdir(parents=True)
        self.source = b'import json\ndef verify(path):\n    return json.loads(path.read_text())\n'
        self.verifier.write_bytes(self.source)
        self.receipt.write_text(json.dumps({"design_id": acceptance.DESIGN_ID, "passed": True}), encoding="utf-8")
        for field, data in (("EXPECTED_VERIFIER_SHA256", self.source),
                            ("EXPECTED_ACCEPTANCE_SHA256", self.receipt.read_bytes())):
            context = patch.object(acceptance, field, acceptance._sha(data))
            context.start()
            self.addCleanup(context.stop)
        prerequisite = patch.object(acceptance, "check_prerequisites", return_value={"python312_available": True, "reason": "Ready"})
        prerequisite.start()
        self.addCleanup(prerequisite.stop)

    def success_process(self):
        report = acceptance._result(self.root, self.receipt, True, "Verified")
        return subprocess.CompletedProcess([], 0, json.dumps(report), "")

    def test_worker_executes_only_pinned_fixed_source(self):
        result = acceptance._verify_worker(self.root, self.receipt)
        self.assertTrue(result["passed"])
        self.assertEqual(result["binding_kind"], "original_local_evidence")

    def test_missing_workspace_blocks_before_spawn(self):
        with patch.object(acceptance.subprocess, "run") as process:
            result = acceptance.check_acceptance(self.root / "absent", self.receipt)
        self.assertFalse(result["enabled"])
        process.assert_not_called()

    def test_missing_receipt_blocks_before_spawn(self):
        self.receipt.unlink()
        with patch.object(acceptance.subprocess, "run") as process:
            result = acceptance.check_acceptance(self.root, self.receipt)
        self.assertFalse(result["passed"])
        process.assert_not_called()

    def test_changed_verifier_cannot_execute(self):
        marker = self.root / "untrusted_executed.txt"
        self.verifier.write_text(f"from pathlib import Path\nPath({str(marker)!r}).write_text('bad')\n")
        result = acceptance._verify_worker(self.root, self.receipt)
        self.assertFalse(result["passed"])
        self.assertFalse(marker.exists())

    def test_changed_receipt_blocks(self):
        self.receipt.write_text('{"passed":true,"verifier_path":"untrusted.py"}')
        self.assertFalse(acceptance._verify_worker(self.root, self.receipt)["passed"])

    def test_receipt_executable_hint_is_never_used(self):
        marker = self.root / "untrusted_executed.txt"
        alternate = self.root / "untrusted.py"
        alternate.write_text(f"from pathlib import Path\nPath({str(marker)!r}).write_text('bad')\n")
        data = {"design_id": acceptance.DESIGN_ID, "passed": True, "verifier_path": str(alternate)}
        self.receipt.write_text(json.dumps(data))
        with patch.object(acceptance, "EXPECTED_ACCEPTANCE_SHA256", acceptance._sha(self.receipt.read_bytes())):
            self.assertTrue(acceptance._verify_worker(self.root, self.receipt)["passed"])
        self.assertFalse(marker.exists())

    def test_worker_failure_is_disabled(self):
        failure = subprocess.CompletedProcess([], 1, json.dumps({"reason": "Raw evidence changed"}), "")
        with patch.object(acceptance.subprocess, "run", return_value=failure):
            result = acceptance.check_acceptance(self.root, self.receipt)
        self.assertFalse(result["enabled"])
        self.assertIn("Raw evidence changed", result["reason"])

    def test_success_requires_expected_binding(self):
        report = json.loads(self.success_process().stdout)
        report["scientific_project_root"] = str(self.root / "different")
        with patch.object(acceptance.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, json.dumps(report), "")):
            self.assertFalse(acceptance.check_acceptance(self.root, self.receipt)["passed"])

    def test_malformed_success_output_is_disabled(self):
        with patch.object(acceptance.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "[]", "")):
            self.assertFalse(acceptance.check_acceptance(self.root, self.receipt)["passed"])

    def test_timeout_is_disabled(self):
        with patch.object(acceptance.subprocess, "run", side_effect=subprocess.TimeoutExpired("worker", 1)):
            result = acceptance.check_acceptance(self.root, self.receipt, timeout=1)
        self.assertFalse(result["enabled"])
        self.assertIn("timed out", result["reason"])

    def test_each_launch_check_is_fresh_and_shell_free(self):
        with patch.object(acceptance.subprocess, "run", return_value=self.success_process()) as process:
            for _ in range(2):
                self.assertTrue(acceptance.check_acceptance(self.root, self.receipt)["passed"])
        self.assertEqual(process.call_count, 2)
        command = process.call_args.args[0]
        self.assertIn("-I", command)
        self.assertEqual(Path(command[2]).resolve(), Path(acceptance.__file__).resolve())
        self.assertFalse(process.call_args.kwargs["shell"])

    def test_startup_check_never_enables_launch(self):
        result = acceptance.binding_status(self.root, self.receipt)
        self.assertTrue(result["ready_for_verification"])
        self.assertEqual(result["state"], "checking")
        self.assertFalse(result["enabled"])

    def test_missing_python312_blocks_full_check(self):
        with patch.object(acceptance, "check_prerequisites", return_value={"python312_available": False, "reason": "Python 3.12 missing"}), \
                patch.object(acceptance.subprocess, "run") as process:
            result = acceptance.check_acceptance(self.root, self.receipt)
        self.assertFalse(result["passed"])
        process.assert_not_called()

    def test_relative_binding_is_rejected(self):
        self.assertFalse(acceptance.check_acceptance("relative/root", self.receipt)["passed"])

    def test_source_change_during_verification_is_rejected(self):
        source = b'from pathlib import Path\ndef verify(path):\n    Path(__file__).write_text("changed")\n    return {"design_id":"FOUR-WAY-EMI-PLAN-V2","passed":True}\n'
        self.verifier.write_bytes(source)
        with patch.object(acceptance, "EXPECTED_VERIFIER_SHA256", acceptance._sha(source)):
            result = acceptance._verify_worker(self.root, self.receipt)
        self.assertFalse(result["passed"])


class PythonPrerequisiteTests(unittest.TestCase):
    def test_missing_launcher(self):
        with patch.object(acceptance.shutil, "which", return_value=None):
            self.assertFalse(acceptance.check_prerequisites()["python312_available"])

    def test_wrong_version_is_rejected(self):
        with patch.object(acceptance.shutil, "which", return_value="py.exe"), \
                patch.object(acceptance.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "[3, 13]", "")):
            self.assertFalse(acceptance.check_prerequisites()["python312_available"])

    def test_python312_is_accepted(self):
        with patch.object(acceptance.shutil, "which", return_value="py.exe"), \
                patch.object(acceptance.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "[3, 12]", "")):
            self.assertTrue(acceptance.check_prerequisites()["python312_available"])


class LocalBindingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.config = self.root / "accepted-science.json"
        self.receipt = self.root / "acceptance.json"
        context = patch.object(acceptance, "LOCAL_BINDING_PATH", self.config)
        context.start()
        self.addCleanup(context.stop)

    def write_binding(self, **overrides):
        binding = {"scientific_project_root": str(self.root), "acceptance_path": str(self.receipt)}
        binding.update(overrides)
        self.config.write_text(json.dumps(binding), encoding="utf-8")

    def test_missing_configuration_is_disabled_without_spawning(self):
        with patch.object(acceptance.subprocess, "run") as process:
            result = acceptance.check_acceptance()
        self.assertFalse(result["enabled"])
        self.assertIn("not configured", result["reason"])
        self.assertEqual(result["scientific_project_root"], "")
        self.assertEqual(result["acceptance_path"], "")
        process.assert_not_called()

    def test_valid_configuration_resolves_both_paths(self):
        self.write_binding()
        self.assertEqual(acceptance._paths(None, None), (self.root, self.receipt))

    def test_explicit_paths_do_not_depend_on_local_configuration(self):
        self.config.write_text("invalid JSON", encoding="utf-8")
        self.assertEqual(acceptance._paths(self.root, self.receipt), (self.root, self.receipt))

    def test_partial_explicit_binding_cannot_mix_with_local_configuration(self):
        self.write_binding()
        for root, receipt in ((self.root, None), (None, self.receipt)):
            with self.subTest(root=root, receipt=receipt):
                result = acceptance.check_acceptance(root, receipt)
                self.assertFalse(result["passed"])
                self.assertIn("supplied together", result["reason"])

    def test_configured_paths_must_be_absolute(self):
        self.write_binding(scientific_project_root="relative/source")
        self.assertIn("absolute", acceptance.check_acceptance()["reason"])

    def test_configuration_cannot_override_pinned_identity(self):
        for extra in ({"verifier_path": "arbitrary.py"}, {"verifier_sha256": "0" * 64},
                      {"acceptance_sha256": "0" * 64}):
            with self.subTest(extra=extra):
                self.write_binding(**extra)
                with patch.object(acceptance.subprocess, "run") as process:
                    self.assertFalse(acceptance.check_acceptance()["passed"])
                process.assert_not_called()

    def test_malformed_missing_empty_and_oversized_configurations_are_disabled(self):
        for text in ("invalid JSON", "[]", "{}", '{"scientific_project_root":true,"acceptance_path":"x"}',
                     '{"scientific_project_root":"","acceptance_path":"x"}', " " * (acceptance.MAX_BINDING_BYTES + 1)):
            with self.subTest(text=text[:100]):
                self.config.write_text(text, encoding="utf-8")
                status = acceptance.binding_status()
                self.assertFalse(status["enabled"])
                self.assertFalse(status["ready_for_verification"])

    def test_configuration_does_not_bypass_source_checks(self):
        self.write_binding()
        with patch.object(acceptance.subprocess, "run") as process:
            result = acceptance.check_acceptance()
        self.assertFalse(result["passed"])
        self.assertIn("verifier is unavailable", result["reason"])
        process.assert_not_called()


if __name__ == "__main__":
    unittest.main()
