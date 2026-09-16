"""Regression tests for launch isolation, honest completion, and local HTTP access."""
import http.client
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("emi_workbench_server", Path(__file__).resolve().parents[1] / "server.py")
server = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(server)


class FakeProcess:
    def __init__(self, code=0):
        self.pid = os.getpid()
        self.code = code
        self.done = threading.Event()

    def wait(self):
        self.done.wait(5)
        return self.code


class WorkbenchTests(unittest.TestCase):
    def setUp(self):
        fixture = {"passed": True, "reason": "", "scientific_project_root": "C:/accepted/project", "acceptance_path": "C:/accepted/receipt.json"}
        checker = patch.object(server.acceptance, "check_acceptance", return_value=fixture)
        checker.start()
        self.addCleanup(checker.stop)
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "12_Workbench/matlab").mkdir(parents=True)
        (self.root / "12_Workbench/matlab/emi_workbench_run.m").write_text("% adapter fixture\n")
        self.workbench = server.Workbench(self.root, matlab=sys.executable)

    def tearDown(self):
        self.workbench.close()
        self.temp.cleanup()

    def write(self, relative, value):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def start_fake(self, process=None, workflow="baseline"):
        process = process or FakeProcess()
        with patch.object(server.subprocess, "Popen", return_value=process) as popen:
            run = self.workbench.start_run(workflow)
        return process, run, popen

    def finish(self, process, run, result=None):
        folder = self.workbench._run_dir(run["id"])
        if result is not None:
            server.write_json(folder / "result.json", result)
        process.done.set()
        deadline = time.monotonic() + 2
        while self.workbench.get_run(run["id"])["status"] == "running" and time.monotonic() < deadline:
            time.sleep(0.01)
        return self.workbench.get_run(run["id"])

    def test_imported_evidence_is_absent_but_original_files_are_preserved(self):
        run_id = "20260915T120000Z_123456abcdef"
        path = self.write(f"12_Workbench/runs/{run_id}/run.json", {
            "id": run_id, "workflow": "four_way_v2_development", "status": "completed",
            "provenance": {"kind": "imported_completed_development_evidence"}})
        self.workbench._load_runs()
        self.assertNotIn("evidence", self.workbench.state())
        self.assertEqual(self.workbench.state()["runs"], [])
        self.assertTrue(path.is_file())
        with self.assertRaises(server.WorkbenchError):
            self.workbench.get_run(run_id)

    def test_missing_acceptance_only_blocks_reserved_workflows(self):
        self.workbench.acceptance_status = {"passed": False, "reason": "Accepted evidence is missing."}
        self.workbench.acceptance_checked = time.monotonic()
        workflows = {w["id"]: w for w in self.workbench.state()["workflows"]}
        for key in server.GATED_WORKFLOWS:
            self.assertFalse(workflows[key]["enabled"])
            self.assertEqual(workflows[key]["disabled_reason"], "Accepted evidence is missing.")
        self.assertTrue(workflows["baseline"]["enabled"])

    def test_changed_acceptance_is_rechecked_before_any_output_or_launch(self):
        self.workbench.acceptance_status = {"passed": True}
        self.workbench.acceptance_checker = lambda: {"passed": False, "reason": "Evidence changed."}
        with patch.object(server.subprocess, "Popen") as popen:
            for workflow in server.GATED_WORKFLOWS:
                with self.assertRaisesRegex(server.WorkbenchError, "Evidence changed"):
                    self.workbench.start_run(workflow)
            popen.assert_not_called()
        self.assertEqual(list(self.workbench.runs_dir.iterdir()), [])
        self.assertFalse(self.workbench.launch_preflight)

    def test_preflight_reserves_launch_without_blocking_status(self):
        started, release = threading.Event(), threading.Event()
        def check():
            started.set()
            release.wait(2)
            return {"passed": False, "reason": "Evidence changed."}
        self.workbench.acceptance_checker = check
        failures = []
        def launch():
            try:
                self.workbench.start_run("four_way_v2_evaluation")
            except server.WorkbenchError as exc:
                failures.append(str(exc))
        worker = threading.Thread(target=launch)
        worker.start()
        try:
            self.assertTrue(started.wait(1))
            self.assertTrue(self.workbench.state()["launch_pending"])
            self.assertTrue(all(not w["enabled"] for w in self.workbench.state()["workflows"]))
            with self.assertRaises(server.WorkbenchError):
                self.workbench.start_run("baseline")
        finally:
            release.set()
            worker.join(2)
        self.assertEqual(failures, ["Evidence changed."])

    def test_reserved_runs_use_verified_binding_and_preserve_negative_findings(self):
        for workflow, payload_key in [("four_way_v2_evaluation", "evaluation"), ("four_way_v2_closure", "closure")]:
            process, run, _ = self.start_fake(workflow=workflow)
            runner = (self.workbench._run_dir(run["id"]) / "runner.m").read_text()
            self.assertIn("'C:/accepted/project'", runner)
            self.assertIn("'C:/accepted/receipt.json'", runner)
            payload = {"summary": {"complete": True, "allHypothesesBenefitPass": False}, "pairs": [{"Variant": "V01"}]}
            result = self.finish(process, run, {"workflow": workflow, "status": "passed", payload_key: payload})
            self.assertEqual(result["status"], "completed")
            self.assertEqual(result[payload_key], payload)
            self.assertNotIn(payload_key, self.workbench.state()["runs"][0])
            self.workbench.close()
            self.workbench = server.Workbench(self.root, matlab=sys.executable)
            self.assertEqual(self.workbench.get_run(run["id"])[payload_key], payload)

    def test_reserved_result_cannot_hide_failed_process(self):
        process, run, _ = self.start_fake(FakeProcess(code=1), workflow="four_way_v2_evaluation")
        result = self.finish(process, run, {"workflow": "four_way_v2_evaluation", "status": "passed", "evaluation": {"summary": {"complete": True}}})
        self.assertEqual(result["status"], "failed")

    def test_unrecognized_workflow_never_launches(self):
        with patch.object(server.subprocess, "Popen") as popen:
            for workflow in ["system('bad')", "../baseline", "evaluate_campaign", "four_way", "four_way_v1_evaluation", [], None]:
                with self.assertRaises(server.WorkbenchError):
                    self.workbench.start_run(workflow)
            popen.assert_not_called()
        self.assertEqual(list(self.workbench.runs_dir.iterdir()), [])

    def test_characterization_is_distinct_and_exposes_conditional_findings(self):
        workflows = {item["id"]: item for item in self.workbench.state()["workflows"]}
        self.assertIn("receiver_characterization", workflows)
        self.assertIn("receiver_tests", workflows)
        process, run, _ = self.start_fake(workflow="receiver_characterization")
        folder = self.workbench._run_dir(run["id"])
        output = folder / "output/receiver_characterization"
        output.mkdir(parents=True)
        (output / "cases.csv").write_text("caseId,domainStatus\nC1,invalid\n")
        study = {"studyId": "RECEIVER-V2", "scope": "Conditional simulation", "totalCases": 1,
                 "validCases": 0, "invalidCases": 1, "suitableForFourWay": False,
                 "findings": ["No candidate established"], "limitations": ["Not measured"],
                 "cases": [{"caseId": "C1", "domainStatus": "invalid"}]}
        result = self.finish(process, run, {"workflow": "receiver_characterization", "status": "passed",
                    "summary": "Conditional sweep completed", "metrics": {"totalCases": 1},
                    "characterization": study, "artifacts": ["output/receiver_characterization/cases.csv"]})
        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["characterization"], study)
        artifact = next(item for item in result["artifacts"] if item["name"].endswith("cases.csv"))
        self.assertEqual(self.workbench.artifact_path(artifact["url"].removeprefix("/artifacts/")), output / "cases.csv")
        self.assertFalse(result["characterization"]["suitableForFourWay"])
        self.workbench.close()
        self.workbench = server.Workbench(self.root, matlab=sys.executable)
        self.assertEqual(self.workbench.get_run(run["id"])["characterization"], study)
        self.assertNotIn("evaluate_campaign", {item["id"] for item in self.workbench.state()["workflows"]})

    def test_characterization_result_cannot_hide_execution_failure(self):
        process, run, _ = self.start_fake(FakeProcess(code=1), workflow="receiver_characterization")
        result = self.finish(process, run, {"workflow": "receiver_characterization", "status": "passed",
                    "characterization": {"studyId": "RECEIVER-V2", "suitableForFourWay": True}})
        self.assertEqual(result["status"], "failed")
        self.assertIn("code 1", result["summary"])

    def test_development_preserves_per_hypothesis_results_and_failed_guards(self):
        self.assertIn("four_way_v2_development", {w["id"] for w in self.workbench.state()["workflows"]})
        process, run, _ = self.start_fake(workflow="four_way_v2_development")
        study = {"summary": {"complete": True, "all_execution_clean_guards_pass": False},
                 "pairs": [{"Variant": "V01", "Arm": "BASELINE", "ExecutionGuardPass": False}]}
        result = self.finish(process, run, {"workflow": "four_way_v2_development", "status": "passed",
                    "summary": "Development completed; conditional simulation only.", "development": study})
        self.assertEqual(result["status"], "completed")
        self.assertFalse(result["development"]["summary"]["all_execution_clean_guards_pass"])
        self.assertNotIn("development", self.workbench.state()["runs"][0])
        self.workbench.close()
        self.workbench = server.Workbench(self.root, matlab=sys.executable)
        self.assertEqual(self.workbench.get_run(run["id"])["development"], study)

    def test_development_cannot_hide_process_failure(self):
        process, run, _ = self.start_fake(FakeProcess(code=1), workflow="four_way_v2_development")
        result = self.finish(process, run, {"workflow": "four_way_v2_development", "status": "passed",
                    "development": {"summary": {"complete": True}}})
        self.assertEqual(result["status"], "failed")

    def test_v2_documents_are_allowlisted_only_when_present(self):
        docs = ["04_EMI_Models/Receiver_V2_Contract.md", "04_EMI_Models/Four_Way_EMI_Experiment_V2.md"]
        for relative in docs:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("Conditional simulation contract")
            self.assertEqual(self.workbench.artifact_path(relative), path)
        document_urls = {item["url"] for item in self.workbench.state()["documents"]}
        self.assertTrue(all(server.artifact_url(relative) in document_urls for relative in docs))

    def test_run_is_isolated_and_output_not_precreated(self):
        process, run, popen = self.start_fake()
        folder = self.workbench._run_dir(run["id"])
        self.assertFalse((folder / "output").exists())
        command = popen.call_args.args[0]
        self.assertEqual(command, [self.workbench.matlab, "-wait", "-batch", "run('runner.m')"])
        self.assertEqual(popen.call_args.kwargs["cwd"], folder)
        self.assertFalse(popen.call_args.kwargs["shell"])
        self.assertIn("emi_workbench_run(", (folder / "runner.m").read_text())
        self.finish(process, run)

    def test_second_run_rejected_while_first_is_active(self):
        process, run, _ = self.start_fake()
        with self.assertRaises(server.WorkbenchError) as caught:
            self.workbench.start_run("receiver_tests")
        self.assertEqual(caught.exception.status, 409)
        self.assertTrue(all(not item["enabled"] for item in self.workbench.state()["workflows"]))
        self.finish(process, run)

    def test_success_requires_result_and_zero_exit(self):
        process, run, _ = self.start_fake()
        result = self.finish(process, run, {"workflow": "baseline", "status": "passed", "summary": "Good baseline", "metrics": {"rmse": 0.125}, "artifacts": []})
        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["metrics"], {"rmse": 0.125})
        self.assertIsNotNone(result["finished_at"])

    def test_zero_exit_with_missing_result_is_failed(self):
        process, run, _ = self.start_fake()
        self.assertEqual(self.finish(process, run)["status"], "failed")

    def test_nonzero_exit_overrides_passed_result(self):
        process, run, _ = self.start_fake(FakeProcess(code=1))
        result = self.finish(process, run, {"workflow": "baseline", "status": "passed"})
        self.assertEqual(result["status"], "failed")
        self.assertIn("code 1", result["summary"])

    def test_failed_checks_override_zero_exit(self):
        process, run, _ = self.start_fake()
        result = self.finish(process, run, {"workflow": "baseline", "status": "failed", "summary": "One check failed"})
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["summary"], "One check failed")

    def test_wrong_workflow_result_is_failed(self):
        process, run, _ = self.start_fake()
        result = self.finish(process, run, {"workflow": "project_tests", "status": "passed"})
        self.assertEqual(result["status"], "failed")

    def test_launch_failure_is_recorded(self):
        with patch.object(server.subprocess, "Popen", side_effect=OSError("not executable")):
            run = self.workbench.start_run("baseline")
        self.assertEqual(run["status"], "failed")
        self.assertIn("not executable", self.workbench.get_run(run["id"])["summary"])

    def test_initial_persistence_failure_does_not_publish_or_launch(self):
        with patch.object(self.workbench, "_save", side_effect=OSError("disk full")), patch.object(server.subprocess, "Popen") as popen:
            with self.assertRaises(OSError):
                self.workbench.start_run("baseline")
            popen.assert_not_called()
        self.assertEqual(self.workbench.runs, {})
        self.assertTrue(all(workflow["enabled"] for workflow in self.workbench.state()["workflows"] if workflow["id"] not in server.GATED_WORKFLOWS))

    def test_postlaunch_persistence_failure_blocks_until_process_exits(self):
        saved = self.workbench._save
        calls = 0
        def fail_second_save(run):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("disk full after launch")
            return saved(run)
        with patch.object(self.workbench, "_save", side_effect=fail_second_save):
            process, run, _ = self.start_fake()
            self.assertEqual(run["status"], "running")
            self.assertIn(run["id"], self.workbench.processes)
            with self.assertRaises(server.WorkbenchError):
                self.workbench.start_run("baseline")
            self.assertEqual(self.finish(process, run)["status"], "failed")
        self.assertFalse(self.workbench.runs[run["id"]].get("needs_recovery"))
        self.assertTrue(all(workflow["enabled"] for workflow in self.workbench.state()["workflows"] if workflow["id"] not in server.GATED_WORKFLOWS))

    def test_current_process_identity_is_live(self):
        alive, identity = server.process_identity(os.getpid())
        self.assertTrue(alive)
        self.assertTrue(identity or os.name != "nt")

    def test_project_lock_blocks_second_server(self):
        with self.assertRaises(RuntimeError):
            server.Workbench(self.root, matlab=sys.executable)

    def test_restarted_server_waits_for_existing_process(self):
        process, run, _ = self.start_fake()
        self.workbench.close()
        with patch.object(server, "process_identity", return_value=(True, None)):
            replacement = server.Workbench(self.root, matlab=sys.executable)
            try:
                self.assertEqual(replacement.get_run(run["id"])["status"], "running")
                with self.assertRaises(server.WorkbenchError):
                    replacement.start_run("baseline")
            finally:
                replacement.close()
        process.done.set()

    def test_restarted_server_does_not_infer_success_without_exit_code(self):
        process, run, _ = self.start_fake()
        server.write_json(self.workbench._run_dir(run["id"]) / "result.json", {"workflow": "baseline", "status": "passed", "summary": "Passed"})
        self.workbench.close()
        with patch.object(server, "process_identity", return_value=(False, None)):
            replacement = server.Workbench(self.root, matlab=sys.executable)
            try:
                recovered = replacement.get_run(run["id"])
                self.assertEqual(recovered["status"], "interrupted")
                self.assertIn("exit code is unavailable", recovered["summary"])
            finally:
                replacement.close()
        process.done.set()

    def test_incomplete_launch_record_blocks_duplicate_after_restart(self):
        run_id = "20260915T120000Z_123456abcdef"
        self.write(f"12_Workbench/runs/{run_id}/run.json", {"id": run_id, "workflow": "baseline", "status": "running", "pid": None})
        self.workbench.close()
        replacement = server.Workbench(self.root, matlab=sys.executable)
        try:
            self.assertEqual(replacement.get_run(run_id)["status"], "interrupted")
            with self.assertRaises(server.WorkbenchError):
                replacement.start_run("baseline")
        finally:
            replacement.close()

    def test_log_tail_is_bounded(self):
        process, run, _ = self.start_fake()
        folder = self.workbench._run_dir(run["id"])
        (folder / "matlab.log").write_bytes(b"x" * (server.MAX_LOG_BYTES * 3) + b"FINAL")
        result = self.finish(process, run)
        self.assertTrue(result["log"].endswith("FINAL"))
        self.assertLess(len(result["log"]), server.MAX_LOG_BYTES + 200)

    def test_artifact_access_is_allowlisted_and_traversal_rejected(self):
        (self.root / "README.md").write_text("Overview")
        (self.root / "private.txt").write_text("Not an artifact")
        self.assertEqual(self.workbench.artifact_path("README.md"), self.root / "README.md")
        for path in ["private.txt", "../README.md", "12_Workbench/../README.md", "C:/Windows/win.ini", "README.md:secret", "README.md.", "README.md ", "..\\README.md"]:
            with self.subTest(path=path), self.assertRaises(server.WorkbenchError):
                self.workbench.artifact_path(path)

    def test_run_result_cannot_expose_outside_files(self):
        process, run, _ = self.start_fake()
        folder = self.workbench._run_dir(run["id"])
        (folder / "output").mkdir()
        (folder / "output/good.csv").write_text("x\n1\n")
        result = self.finish(process, run, {"workflow": "baseline", "status": "passed", "artifacts": ["output/good.csv", "../../server.py", "C:/Windows/win.ini", {"path": "bad"}]})
        names = {artifact["name"] for artifact in result["artifacts"]}
        self.assertEqual(names, {"matlab.log", "result.json", "output/good.csv"})
        with self.assertRaises(server.WorkbenchError):
            self.workbench.artifact_path(f"12_Workbench/runs/{run['id']}/runner.m")

    def test_symlink_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as outside:
            target = Path(outside)
            (target / "results").mkdir()
            (target / "results/verification_summary.json").write_text("{}")
            link = self.root / "11_EDMD_Hybrid_Estimation"
            try:
                link.symlink_to(target, target_is_directory=True)
            except OSError:
                if os.name != "nt":
                    raise
                # Windows junctions exercise the same escape check without the
                # administrator/developer privilege required by file symlinks.
                created = subprocess.run(["cmd.exe", "/d", "/c", "mklink", "/J", str(link), str(target)],
                                         capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)
                if created.returncode:
                    self.skipTest("This account cannot create symbolic links or junctions")
            try:
                with self.assertRaises(server.WorkbenchError):
                    self.workbench.artifact_path("11_EDMD_Hybrid_Estimation/results/verification_summary.json")
            finally:
                if link.is_symlink():
                    link.unlink()
                else:
                    link.rmdir()

    def test_oversized_or_nonfinite_json_is_unavailable(self):
        path = self.root / "broken.json"
        path.write_text('{"metric": NaN}')
        self.assertIsNone(server.read_json(path))
        path.write_text(" " * (server.MAX_JSON_BYTES + 1))
        self.assertIsNone(server.read_json(path))

    def test_matlab_literal_escapes_quotes_and_windows_slashes(self):
        self.assertEqual(server.matlab_quote("C:\\researcher's\\project"), "'C:/researcher''s/project'")


class HttpTests(unittest.TestCase):
    def setUp(self):
        fixture = {"passed": True, "reason": "", "scientific_project_root": "C:/accepted/project", "acceptance_path": "C:/accepted/receipt.json"}
        checker = patch.object(server.acceptance, "check_acceptance", return_value=fixture)
        checker.start()
        self.addCleanup(checker.stop)
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        (root / "12_Workbench/web").mkdir(parents=True)
        (root / "12_Workbench/web/index.html").write_text("<!doctype html><title>Workbench</title>")
        (root / "README.md").write_text("Project overview")
        self.workbench = server.Workbench(root, matlab=sys.executable)
        self.http = server.WorkbenchServer(0, self.workbench)
        self.thread = threading.Thread(target=self.http.serve_forever, kwargs={"poll_interval": 0.02}, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.http.shutdown()
        self.http.server_close()
        self.thread.join(timeout=2)
        self.workbench.close()
        self.temp.cleanup()

    def request(self, method="GET", path="/api/state", body=None, headers=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.http.server_port, timeout=2)
        try:
            connection.request(method, path, body=body, headers=headers or {})
            response = connection.getresponse()
            return response.status, dict(response.getheaders()), response.read()
        finally:
            connection.close()

    def test_state_and_static_page_are_available_locally(self):
        status, headers, body = self.request()
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["project"]["root"], str(self.workbench.root))
        self.assertEqual(headers["Cache-Control"], "no-store")
        status, _, body = self.request(path="/")
        self.assertEqual(status, 200)
        self.assertIn(b"Workbench", body)

    def test_host_rebinding_and_cross_origin_are_denied(self):
        for headers in [{"Host": "attacker.test"}, {"Origin": "https://attacker.test"}, {"Sec-Fetch-Site": "cross-site"}]:
            self.assertEqual(self.request(headers=headers)[0], 403)

    def test_post_requires_csrf_token_and_json(self):
        body = json.dumps({"workflow": "baseline"})
        self.assertEqual(self.request("POST", "/api/runs", body, {"Content-Type": "application/json"})[0], 403)
        headers = {"X-EMI-Token": self.workbench.token}
        self.assertEqual(self.request("POST", "/api/runs", body, headers)[0], 415)
        headers["Content-Type"] = "application/json"
        self.assertEqual(self.request("POST", "/api/runs", "{", headers)[0], 400)
        self.assertEqual(self.request("POST", "/api/runs", json.dumps({"workflow": "baseline", "code": "bad"}), headers)[0], 400)

    def test_valid_post_dispatches_only_allowlisted_workflow(self):
        headers = {"X-EMI-Token": self.workbench.token, "Content-Type": "application/json", "Origin": f"http://127.0.0.1:{self.http.server_port}"}
        with patch.object(self.workbench, "start_run", return_value={"id": "fixture", "status": "running"}) as start:
            status, _, body = self.request("POST", "/api/runs", json.dumps({"workflow": "baseline"}), headers)
        self.assertEqual(status, 202)
        self.assertEqual(json.loads(body)["status"], "running")
        start.assert_called_once_with("baseline")

    def test_url_encoded_traversal_and_unlisted_files_are_denied(self):
        for path in ["/artifacts/%2e%2e/README.md", "/artifacts/12_Workbench/server.lock", "/%2e%2e/server.py", "/artifacts/README.md%3Asecret"]:
            self.assertEqual(self.request(path=path)[0], 404)
        status, headers, body = self.request(path="/artifacts/README.md")
        self.assertEqual(status, 200)
        self.assertEqual(headers["Content-Type"], "text/plain; charset=utf-8")
        self.assertIn(b"overview", body)


if __name__ == "__main__":
    unittest.main()
