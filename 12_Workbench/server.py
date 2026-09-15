"""Local, standard-library-only launcher for the EMI research workbench.

Run metadata belongs to this integration layer. Scientific outputs are written by
the existing MATLAB routines through matlab/emi_workbench_run.m.
"""
from __future__ import annotations

import argparse
import ctypes
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import sys
import threading
from urllib.parse import quote, unquote, urlsplit
import uuid
import webbrowser


MAX_JSON_BYTES = 2 * 1024 * 1024
MAX_LOG_BYTES = 64 * 1024
RUN_ID = re.compile(r"^\d{8}T\d{6}Z_[a-f0-9]{12}$")
REVIEW = "00_Project_Management/Reviews/2026-09-12/Complete_Verification"
MAIN_EVIDENCE = REVIEW + "/main_test_summary.json"
RESEARCH_EVIDENCE = REVIEW + "/verification_summary.json"
EDMD_EVIDENCE = "11_EDMD_Hybrid_Estimation/results/verification_summary.json"
DOCUMENTS = [
    ("Project overview", "Research scope and repository guide", "README.md"),
    ("Research roadmap", "Current milestones and receiver priorities", "00_Project_Management/Roadmap.md"),
    ("Receiver revision brief", "Characterization work needed before the comparison", "00_Project_Management/Reviews/2026-09-12/Receiver_Revision_Brief.md"),
    ("Progress report", "Saved publication report, September 11", "09_Report/Publication_2026-09-11/EMI_Robotics_Progress_Report.pdf"),
    ("EDMD project", "Hybrid estimation scope and usage", "11_EDMD_Hybrid_Estimation/README.md"),
    ("EDMD verification", "Latest saved verification and its limitations", "11_EDMD_Hybrid_Estimation/docs/VERIFICATION_AND_VALIDATION.md"),
    ("EDMD findings", "September 13 forecasting and correction results", "11_EDMD_Hybrid_Estimation/docs/RESULTS_20260913.md"),
    ("Complete verification review", "Saved project-wide verification report", REVIEW + "/Verification_Report.md"),
]
ALLOWED_PROJECT_FILES = {item[2] for item in DOCUMENTS} | {
    MAIN_EVIDENCE, RESEARCH_EVIDENCE, EDMD_EVIDENCE,
}
WORKFLOWS = {
    "baseline": ("Baseline control simulation", "Run the existing PID motor baseline and save its response and metrics."),
    "receiver_tests": ("Receiver model checks", "Run the existing causal receiver and receiver-domain tests."),
    "project_tests": ("Main project tests", "Run the existing MATLAB project test suite; this can take several minutes."),
}


def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def safe_path(root: Path, relative: str) -> Path:
    """Reject traversal and Windows path aliases before resolving symlinks."""
    if not isinstance(relative, str) or not relative or "\\" in relative:
        raise ValueError("Invalid file path")
    parts = relative.split("/")
    if any(not part or part in (".", "..") or ":" in part or
           part.endswith((".", " ")) or any(ord(c) < 32 for c in part)
           for part in parts):
        raise ValueError("Invalid file path")
    root = root.resolve()
    path = root.joinpath(*parts).resolve()
    if not path.is_relative_to(root) or path == root:
        raise ValueError("File is outside its allowed folder")
    return path


def read_json(path: Path):
    def reject_nonfinite(value):
        raise ValueError(f"Nonfinite JSON number: {value}")
    try:
        if path.stat().st_size > MAX_JSON_BYTES:
            return None
        with path.open("r", encoding="utf-8-sig") as handle:
            raw = handle.read(MAX_JSON_BYTES + 1)
        if len(raw) > MAX_JSON_BYTES:
            return None
        value = json.loads(raw, parse_constant=reject_nonfinite)
        return value if isinstance(value, dict) else None
    except (OSError, ValueError, UnicodeError):
        return None


def write_json(path: Path, value):
    temporary = safe_path(path.parent, path.name + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def artifact_url(relative):
    return "/artifacts/" + quote(relative, safe="/")


def matlab_quote(value):
    return "'" + str(value).replace("\\", "/").replace("'", "''") + "'"


def find_matlab(explicit=None):
    """Only executable paths supplied locally are accepted, never HTTP input."""
    if explicit:
        candidate = Path(explicit).expanduser()
        if not candidate.is_file():
            raise ValueError("The specified MATLAB executable does not exist.")
        return str(candidate.resolve())
    configured = os.environ.get("MATLAB_EXECUTABLE")
    if configured and Path(configured).is_file():
        return str(Path(configured).resolve())
    found = shutil.which("matlab")
    if found:
        return str(Path(found).resolve())
    if os.name == "nt":
        folder = Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "MATLAB"
        if folder.is_dir():
            for candidate in sorted(folder.glob("R*/bin/matlab.exe"), reverse=True):
                if candidate.is_file():
                    return str(candidate.resolve())
    return None


def process_identity(pid):
    """Return (alive, creation identity). Unknown access is conservatively alive."""
    if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
        return False, None
    if os.name == "nt":
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
        kernel.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = kernel.OpenProcess(0x1000, False, pid)
        if not handle:
            return (ctypes.get_last_error() == 5), None
        try:
            exit_code = wintypes.DWORD()
            if not kernel.GetExitCodeProcess(handle, ctypes.byref(exit_code)):
                return True, None
            times = [wintypes.FILETIME() for _ in range(4)]
            stamp = None
            if kernel.GetProcessTimes(handle, *(ctypes.byref(t) for t in times)):
                stamp = str((times[0].dwHighDateTime << 32) | times[0].dwLowDateTime)
            return exit_code.value == 259, stamp
        finally:
            kernel.CloseHandle(handle)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False, None
    except PermissionError:
        return True, None
    try:
        stat = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        return stat[0] != "Z", stat[19]
    except (OSError, IndexError):
        return True, None


class ProjectLock:
    """An OS-owned lock prevents two workbench servers launching against one root."""
    def __init__(self, path):
        self.handle = path.open("a+b")
        try:
            self.handle.seek(0)
            if not self.handle.read(1):
                self.handle.write(b"0")
                self.handle.flush()
            self.handle.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(self.handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            self.handle.close()
            raise RuntimeError("A workbench server is already open for this project.") from exc

    def close(self):
        if not self.handle.closed:
            self.handle.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(self.handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.handle, fcntl.LOCK_UN)
            self.handle.close()


class WorkbenchError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


class Workbench:
    def __init__(self, project_root=None, matlab=None):
        self.root = Path(project_root or Path(__file__).resolve().parent.parent).resolve()
        if not self.root.is_dir():
            raise ValueError("Project root does not exist")
        self.home = safe_path(self.root, "12_Workbench")
        self.home.mkdir(exist_ok=True)
        self.runs_dir = safe_path(self.home, "runs")
        self.runs_dir.mkdir(exist_ok=True)
        self.web_dir = safe_path(self.home, "web")
        self.matlab = find_matlab(matlab)
        self.token = secrets.token_urlsafe(32)
        self.guard = threading.RLock()
        self.runs = {}
        self.processes = {}
        self.evidence_cache = {}
        self.lock = ProjectLock(safe_path(self.home, "server.lock"))
        self.closed = False
        self._load_runs()

    def close(self):
        # MATLAB is deliberately not terminated when a browser/server is closed.
        # A subsequent server observes the persisted PID before offering new runs.
        with self.guard:
            self.closed = True
            self.lock.close()

    def _run_dir(self, run_id):
        if not RUN_ID.fullmatch(run_id):
            raise WorkbenchError("Run not found", 404)
        return safe_path(self.runs_dir, run_id)

    def _save(self, run):
        write_json(safe_path(self._run_dir(run["id"]), "run.json"), run)

    def _load_runs(self):
        for folder in self.runs_dir.iterdir():
            if not RUN_ID.fullmatch(folder.name):
                continue
            try:
                folder = self._run_dir(folder.name)
                run = read_json(safe_path(folder, "run.json"))
            except ValueError:
                continue
            if not run or run.get("id") != folder.name or run.get("workflow") not in WORKFLOWS:
                continue
            self.runs[run["id"]] = run
            if run.get("status") == "running":
                if not run.get("pid"):
                    run.update(status="interrupted", finished_at=utc_now(), needs_recovery=True,
                               summary="The server stopped during launch. Process identity is unavailable; new runs are blocked until this launch is checked locally.")
                    self._save(run)
                else:
                    run["recovered"] = True
        self._refresh_recovered()

    def _refresh_recovered(self):
        for run in self.runs.values():
            if run.get("status") != "running" or not run.get("recovered"):
                continue
            alive, stamp = process_identity(run.get("pid"))
            same_process = not stamp or not run.get("pid_identity") or stamp == run["pid_identity"]
            if alive and same_process:
                continue
            run.update(status="interrupted", finished_at=utc_now(),
                       summary="The MATLAB process has ended after a server restart. Its exit code is unavailable; saved files are retained but completion is unverified.")
            self._apply_result(run, verified_exit=None)
            self._save(run)

    def _cached_evidence(self, relative):
        try:
            path = safe_path(self.root, relative)
            info = path.stat()
            signature = (info.st_mtime_ns, info.st_size)
        except (OSError, ValueError):
            return None
        previous = self.evidence_cache.get(relative)
        if previous and previous[0] == signature:
            return previous[1]
        value = read_json(path)
        self.evidence_cache[relative] = (signature, value)
        return value

    def evidence(self):
        main = self._cached_evidence(MAIN_EVIDENCE) or {}
        edmd = self._cached_evidence(EDMD_EVIDENCE) or {}
        review = self._cached_evidence(RESEARCH_EVIDENCE) or {}
        def counts(passed, total):
            if all(type(n) is int and n >= 0 for n in (passed, total)) and passed <= total:
                return f"{passed} / {total}"
            return "Unknown"
        screen = edmd.get("matlabVerification", {})
        screen = screen.get("edmdBenefitScreen", {}) if isinstance(screen, dict) else {}
        passes = screen.get("passed") if isinstance(screen, dict) else None
        benefit = counts(sum(passes), len(passes)) if isinstance(passes, list) and passes and all(type(p) is bool for p in passes) else "Unknown"
        acceptance = review.get("research_acceptance_passed")
        items = [
            ("main_tests", "Main project tests", counts(main.get("passed"), main.get("tests")), "Passed / total in the saved September 12 review; this is not a new run.", MAIN_EVIDENCE),
            ("edmd_tests", "EDMD verification tests", counts(edmd.get("passed"), edmd.get("automatedTests")), "Passed / total in the saved EDMD verification summary; forecasting verification has a separate research scope.", EDMD_EVIDENCE),
            ("edmd_benefit", "EDMD benefit regimes", benefit, "Regimes meeting the saved forecasting benefit screen. Code verification does not establish a control benefit.", EDMD_EVIDENCE),
            ("research_acceptance", "Comparison acceptance", "Accepted" if acceptance is True else "Not accepted" if acceptance is False else "Unknown", "Saved September 12 review. Receiver/topology characterization remains the next research priority.", RESEARCH_EVIDENCE),
        ]
        evidence = []
        for i, label, value, detail, source in items:
            try:
                exists = safe_path(self.root, source).is_file()
            except ValueError:
                exists = False
            evidence.append(dict(id=i, label=label, value=value, detail=detail, source=source,
                                 url=artifact_url(source) if exists else None))
        return evidence

    def _blocking_reason(self):
        if any(run.get("needs_recovery") for run in self.runs.values()):
            return "A previous launch needs local recovery before another MATLAB run can start."
        if self.processes or any(run.get("status") == "running" for run in self.runs.values()):
            return "A MATLAB workflow is already running."
        if not self.matlab:
            return ("MATLAB was not found. Set MATLAB_EXECUTABLE to its executable path before opening the app. "
                    "When running the development server directly, you can also use --matlab with that path.")
        if not safe_path(self.home, "matlab/emi_workbench_run.m").is_file():
            return "The MATLAB workbench adapter is missing."
        return ""

    def _public_run(self, run, include_log=False):
        result = {key: run.get(key) for key in (
            "id", "workflow", "title", "status", "started_at", "finished_at", "summary")}
        result["metrics"] = run.get("metrics", {})
        result["artifacts"] = self._artifacts(run)
        if include_log:
            result["log"] = self._read_log(run["id"])
        return result

    def state(self):
        with self.guard:
            self._refresh_recovered()
            reason = self._blocking_reason()
            workflows = [dict(id=key, title=value[0], description=value[1], enabled=not reason, reason=reason)
                         for key, value in WORKFLOWS.items()]
            runs = [self._public_run(run) for run in sorted(self.runs.values(), key=lambda run: run["id"], reverse=True)]
            documents = []
            for title, description, relative in DOCUMENTS:
                try:
                    exists = safe_path(self.root, relative).is_file()
                except ValueError:
                    exists = False
                if exists:
                    documents.append(dict(title=title, description=description, url=artifact_url(relative)))
            return dict(
                project=dict(name="EMI-Resilient Control System for Robotics", root=str(self.root)),
                runtime=dict(matlab_available=bool(self.matlab), matlab_path=self.matlab),
                research=dict(status="blocked", title="Receiver characterization comes next",
                              detail="Research checkpoint from the September 12 review: receiver/topology characterization is pending and a combined mitigation benefit remains unproven. Saved evidence below is separate from new workbench runs.",
                              next_step="Characterize the receiver/topology, obtain an accepted development result, then freeze a new comparison."),
                evidence=self.evidence(), workflows=workflows, runs=runs, documents=documents, token=self.token)

    def get_run(self, run_id):
        with self.guard:
            self._refresh_recovered()
            if run_id not in self.runs:
                raise WorkbenchError("Run not found", 404)
            return self._public_run(self.runs[run_id], include_log=True)

    def start_run(self, workflow):
        if not isinstance(workflow, str) or workflow not in WORKFLOWS:
            raise WorkbenchError("Unknown workflow")
        with self.guard:
            if self.closed:
                raise WorkbenchError("Workbench server is closing", 503)
            self._refresh_recovered()
            reason = self._blocking_reason()
            if reason:
                raise WorkbenchError(reason, 409 if self.matlab else 503)
            run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ_") + uuid.uuid4().hex[:12]
            folder = self._run_dir(run_id)
            folder.mkdir()
            # Only MATLAB may create output/: existing output guards require it absent.
            runner = ("addpath(" + matlab_quote(self.home / "matlab") + ");\n" +
                      "emi_workbench_run(" + ", ".join(map(matlab_quote, [self.root, workflow, folder])) + ");\n")
            safe_path(folder, "runner.m").write_text(runner, encoding="utf-8")
            run = dict(id=run_id, workflow=workflow, title=WORKFLOWS[workflow][0],
                       status="running", started_at=utc_now(), finished_at=None,
                       summary="Starting MATLAB…", metrics={}, artifact_paths=[], pid=None,
                       pid_identity=None, server_pid=os.getpid())
            self._save(run)
            # Publish only after the pre-launch record is durable. A failed disk
            # write here must not leave a phantom active run in memory.
            self.runs[run_id] = run
            process = None
            try:
                log = safe_path(folder, "matlab.log").open("wb")
                try:
                    process = subprocess.Popen([self.matlab, "-wait", "-batch", "run('runner.m')"],
                                               cwd=folder, stdin=subprocess.DEVNULL, stdout=log,
                                               stderr=subprocess.STDOUT, shell=False,
                                               creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                finally:
                    log.close()
                self.processes[run_id] = process
                _, stamp = process_identity(process.pid)
                run.update(pid=process.pid, pid_identity=stamp, summary="MATLAB workflow is running.")
                self._save(run)
                threading.Thread(target=self._wait_run, args=(run_id, process), daemon=True).start()
            except OSError as exc:
                if process is None:
                    run.update(status="failed", finished_at=utc_now(), summary=f"MATLAB could not start: {exc}")
                    self._save(run)
                else:
                    # A process that launched must never be relabeled failed merely
                    # because persisting its identity failed; that could enable a duplicate.
                    run.update(needs_recovery=True, summary="MATLAB launched, but its process record could not be saved. New runs are blocked until this process ends.")
                    threading.Thread(target=self._wait_run, args=(run_id, process), daemon=True).start()
            return self._public_run(run)

    def _wait_run(self, run_id, process):
        exit_code = process.wait()
        with self.guard:
            if self.closed:
                return
            run = self.runs[run_id]
            run.update(finished_at=utc_now(), exit_code=exit_code)
            run.pop("needs_recovery", None)
            self._apply_result(run, verified_exit=exit_code)
            try:
                self._save(run)
            except OSError:
                run["summary"] += " The updated run record could not be saved; check disk access before closing."
            self.processes.pop(run_id, None)

    def _apply_result(self, run, verified_exit):
        result = read_json(safe_path(self._run_dir(run["id"]), "result.json"))
        valid = result and result.get("workflow") == run["workflow"] and result.get("status") in ("passed", "failed")
        if valid:
            run["metrics"] = result.get("metrics") if isinstance(result.get("metrics"), dict) else {}
            paths = result.get("artifacts", [])
            # MATLAB jsonencode may emit a lone string for a scalar string array.
            run["artifact_paths"] = [paths] if isinstance(paths, str) else paths if isinstance(paths, list) else []
        if verified_exit is None:
            return
        if valid and verified_exit == 0 and result["status"] == "passed":
            run["status"] = "completed"
            run["summary"] = str(result.get("summary") or "Workflow completed.")[:4000]
        else:
            run["status"] = "failed"
            if not valid:
                run["summary"] = f"MATLAB exited with code {verified_exit}, but a valid workflow result was not saved. Check the log."
            elif verified_exit != 0:
                run["summary"] = f"MATLAB exited with code {verified_exit}. " + str(result.get("summary") or "Check the log.")[:3500]
            else:
                run["summary"] = str(result.get("summary") or "Workflow checks failed.")[:4000]

    def _allowed_run_files(self, run):
        folder = self._run_dir(run["id"])
        allowed = set()
        for relative in ["matlab.log", "result.json"] + run.get("artifact_paths", []):
            if not isinstance(relative, str):
                continue
            try:
                path = safe_path(folder, relative)
                if path.is_file():
                    allowed.add(path.relative_to(folder).as_posix())
            except (ValueError, OSError):
                continue
        return allowed

    def _artifacts(self, run):
        return [dict(name=relative, url=artifact_url("12_Workbench/runs/" + run["id"] + "/" + relative))
                for relative in sorted(self._allowed_run_files(run))]

    def _read_log(self, run_id):
        try:
            path = safe_path(self._run_dir(run_id), "matlab.log")
            with path.open("rb") as handle:
                size = handle.seek(0, os.SEEK_END)
                handle.seek(max(0, size - MAX_LOG_BYTES))
                tail = handle.read(MAX_LOG_BYTES).decode("utf-8", errors="replace")
                return ("[Earlier output omitted; download matlab.log for the complete log.]\n" if size > MAX_LOG_BYTES else "") + tail
        except (OSError, ValueError):
            return ""

    def artifact_path(self, relative):
        try:
            path = safe_path(self.root, relative)
            allowed = relative in ALLOWED_PROJECT_FILES
            parts = relative.split("/")
            if len(parts) >= 4 and parts[:2] == ["12_Workbench", "runs"]:
                with self.guard:
                    run = self.runs.get(parts[2])
                    allowed = bool(run and "/".join(parts[3:]) in self._allowed_run_files(run))
            if allowed and path.is_file():
                return path
        except (ValueError, OSError):
            pass
        raise WorkbenchError("Artifact not found", 404)


class WorkbenchServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = False

    def __init__(self, port, workbench):
        self.workbench = workbench
        super().__init__(("127.0.0.1", port), WorkbenchHandler)


class WorkbenchHandler(BaseHTTPRequestHandler):
    server_version = "EMIWorkbench/1"

    def log_message(self, fmt, *args):
        # Keep polling quiet; actionable startup/run errors are visible in the UI.
        if args and str(args[1] if len(args) > 1 else "").startswith("5"):
            super().log_message(fmt, *args)

    def _guard_request(self):
        port = self.server.server_port
        hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}
        if port == 80:
            hosts.update(("127.0.0.1", "localhost"))
        if self.headers.get("Host", "").lower() not in hosts:
            raise WorkbenchError("Invalid local host", 403)
        origin = self.headers.get("Origin")
        if origin is not None and origin.lower() != "http://" + self.headers["Host"].lower():
            raise WorkbenchError("Cross-origin requests are not allowed", 403)
        if self.headers.get("Sec-Fetch-Site", "none") not in ("none", "same-origin"):
            raise WorkbenchError("Cross-site requests are not allowed", 403)

    def _headers(self, status, content_type, length):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(length))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
        self.end_headers()

    def _json(self, value, status=200):
        payload = json.dumps(value, ensure_ascii=False, allow_nan=False).encode("utf-8")
        self._headers(status, "application/json; charset=utf-8", len(payload))
        if self.command != "HEAD":
            self.wfile.write(payload)

    def _file(self, path, artifact=False):
        content_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
        if not artifact and path.suffix.lower() == ".ttf":
            content_type = "font/ttf"
        if path.suffix.lower() in (".md", ".m", ".log", ".txt"):
            content_type = "text/plain; charset=utf-8"
        if artifact and path.suffix.lower() in (".html", ".htm", ".svg", ".js", ".css", ".xml"):
            content_type = "text/plain; charset=utf-8"
        with path.open("rb") as handle:
            self._headers(200, content_type, os.fstat(handle.fileno()).st_size)
            if self.command != "HEAD":
                shutil.copyfileobj(handle, self.wfile, length=64 * 1024)

    def _get(self):
        self._guard_request()
        parsed = urlsplit(self.path)
        if parsed.scheme or parsed.netloc:
            raise WorkbenchError("Invalid request target", 400)
        path = unquote(parsed.path, errors="strict")
        workbench = self.server.workbench
        if path == "/api/state":
            self._json(workbench.state())
        elif path.startswith("/api/runs/"):
            self._json(workbench.get_run(path[len("/api/runs/"):]))
        elif path.startswith("/artifacts/"):
            self._file(workbench.artifact_path(path[len("/artifacts/"):]), artifact=True)
        else:
            relative = "index.html" if path == "/" else path.removeprefix("/")
            try:
                file = safe_path(workbench.web_dir, relative)
            except ValueError as exc:
                raise WorkbenchError("File not found", 404) from exc
            if not file.is_file():
                raise WorkbenchError("File not found", 404)
            self._file(file)

    def do_GET(self):
        try:
            self._get()
        except WorkbenchError as exc:
            self._json({"error": str(exc)}, exc.status)
        except (OSError, ValueError, UnicodeError):
            self._json({"error": "The requested file could not be read"}, 400)

    do_HEAD = do_GET

    def do_POST(self):
        body_read = False
        try:
            self._guard_request()
            if self.path != "/api/runs":
                raise WorkbenchError("Endpoint not found", 404)
            token = self.headers.get("X-EMI-Token", "")
            if not secrets.compare_digest(token, self.server.workbench.token):
                raise WorkbenchError("Invalid workbench token. Refresh the page and try again.", 403)
            if self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower() != "application/json":
                raise WorkbenchError("Send application/json", 415)
            if self.headers.get("Transfer-Encoding"):
                raise WorkbenchError("Transfer encoding is unsupported", 400)
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError as exc:
                raise WorkbenchError("Invalid request length", 400) from exc
            if not 0 < length <= 4096:
                raise WorkbenchError("Request body must be between 1 and 4096 bytes", 413)
            self.connection.settimeout(10)
            try:
                raw_body = self.rfile.read(length)
                body_read = True
                value = json.loads(raw_body)
            except (ValueError, UnicodeError) as exc:
                raise WorkbenchError("Invalid JSON", 400) from exc
            if not isinstance(value, dict) or set(value) != {"workflow"}:
                raise WorkbenchError("Provide only the workflow field", 400)
            self._json(self.server.workbench.start_run(value["workflow"]), 202)
        except WorkbenchError as exc:
            # Drain small rejected request bodies so Windows does not reset the
            # connection before the browser receives the explanatory JSON error.
            if not body_read and not self.headers.get("Transfer-Encoding"):
                try:
                    remaining = int(self.headers.get("Content-Length", "0"))
                    if 0 < remaining <= 4096:
                        self.connection.settimeout(2)
                        self.rfile.read(remaining)
                except (OSError, ValueError):
                    pass
            self._json({"error": str(exc)}, exc.status)
        except (OSError, ValueError):
            self._json({"error": "The workflow could not be started"}, 500)

    def do_OPTIONS(self):
        self._json({"error": "Cross-origin access is not supported"}, 405)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Open the local EMI research workbench.")
    parser.add_argument("--port", type=int, default=8765, help="Local port; 0 selects an available port")
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--matlab", help="Path to the MATLAB executable")
    parser.add_argument("--project-root", type=Path, help="Project root; defaults to the parent of this workbench")
    args = parser.parse_args(argv)
    if not 0 <= args.port <= 65535:
        parser.error("Port must be between 0 and 65535")
    workbench = None
    server = None
    try:
        workbench = Workbench(args.project_root, args.matlab)
        server = WorkbenchServer(args.port, workbench)
        url = f"http://127.0.0.1:{server.server_port}"
        print(f"EMI research workbench: {url}", flush=True)
        print(f"Project: {workbench.root}", flush=True)
        if not args.no_browser:
            webbrowser.open(url)
        server.serve_forever(poll_interval=0.5)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"Workbench could not open: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nWorkbench closed. Any active MATLAB run continues; reopen to inspect its files.", flush=True)
    finally:
        if server:
            server.server_close()
        if workbench:
            workbench.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
