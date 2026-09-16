"""Local binding to the separately accepted, unchanged PLAN-V2 implementation.

The portable interface does not manufacture portable acceptance. Its scientific
launches remain bound to the original source and raw-evidence inventory. The
receipt is data, never a source of executable paths. Only the pinned verifier
bytes at a fixed source-relative location can run in an isolated Python child.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

DESIGN_ID = "FOUR-WAY-EMI-PLAN-V2"
LOCAL_BINDING_PATH = Path(__file__).resolve().parent / "local" / "accepted-science.json"
MAX_BINDING_BYTES = 16 * 1024
VERIFIER_RELATIVE_PATH = "06_Circuit_Simulations/FOUR_WAY_V2/audit/verify_v2_acceptance.py"
EXPECTED_VERIFIER_SHA256 = "3fee4b39862ec15e14ee49874e2a8cc3310f44c61dacbd386d0a376ec098654b"
EXPECTED_ACCEPTANCE_SHA256 = "7f1f5b897fd205a7d6af40416a8a73a9b2612f9c1e98c198bde3adf7a02d9714"


def _sha(data):
    return hashlib.sha256(data).hexdigest()


def _result(root, receipt, passed=False, reason="Acceptance has not been verified."):
    return {
        "passed": bool(passed), "enabled": bool(passed),
        "state": "ready" if passed else "blocked", "reason": reason,
        "design_id": DESIGN_ID,
        "scientific_project_root": str(root) if root is not None else "",
        "acceptance_path": str(receipt) if receipt is not None else "",
        "verifier_sha256": EXPECTED_VERIFIER_SHA256,
        "acceptance_sha256": EXPECTED_ACCEPTANCE_SHA256,
        "binding_kind": "original_local_evidence",
        "checked_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "physical_validation": False,
    }


def _paths(project_root, acceptance_path):
    if project_root is None and acceptance_path is None:
        if not LOCAL_BINDING_PATH.is_file():
            raise ValueError(
                "Accepted scientific setup is not configured. See the Workbench guide to set "
                "12_Workbench/local/accepted-science.json; the original accepted evidence is required.")
        with LOCAL_BINDING_PATH.open("rb") as stream:
            data = stream.read(MAX_BINDING_BYTES + 1)
        if len(data) > MAX_BINDING_BYTES:
            raise ValueError("The local scientific binding is too large.")
        binding = json.loads(data.decode("utf-8-sig"))
        required = {"scientific_project_root", "acceptance_path"}
        if not isinstance(binding, dict) or set(binding) != required or not all(
                isinstance(binding[key], str) and binding[key].strip() for key in required):
            raise ValueError("The local scientific binding must contain only scientific_project_root and acceptance_path as nonempty strings.")
        project_root, acceptance_path = binding["scientific_project_root"], binding["acceptance_path"]
    elif project_root is None or acceptance_path is None:
        raise ValueError("Scientific source and acceptance locations must be supplied together.")
    root, receipt = Path(project_root), Path(acceptance_path)
    if not root.is_absolute() or not receipt.is_absolute():
        raise ValueError("Scientific source and acceptance locations must be absolute local paths.")
    return root.resolve(), receipt.resolve()


def _trusted_inputs(root, receipt):
    if not root.is_dir():
        raise ValueError("The original accepted scientific workspace is unavailable.")
    verifier = root / VERIFIER_RELATIVE_PATH
    if not verifier.is_file():
        raise ValueError("The accepted scientific verifier is unavailable in the original workspace.")
    source = verifier.read_bytes()
    if _sha(source) != EXPECTED_VERIFIER_SHA256:
        raise ValueError("The scientific acceptance verifier differs from the accepted version.")
    if not receipt.is_file():
        raise ValueError("The original implementation acceptance receipt is unavailable.")
    if _sha(receipt.read_bytes()) != EXPECTED_ACCEPTANCE_SHA256:
        raise ValueError("The implementation acceptance receipt differs from the accepted version.")
    return verifier, source


def _verify_worker(project_root, acceptance_path):
    """Execute captured, pinned source bytes; never import a receipt-selected file."""
    root, receipt = _paths(project_root, acceptance_path)
    try:
        verifier, source = _trusted_inputs(root, receipt)
        namespace = {"__name__": "_accepted_plan_v2_verifier_", "__file__": str(verifier)}
        exec(compile(source, str(verifier), "exec"), namespace)
        accepted = namespace["verify"](receipt)
        # Detect changes across the check, rather than granting a stale pass.
        _trusted_inputs(root, receipt)
        if accepted.get("design_id") != DESIGN_ID or accepted.get("passed") is not True:
            raise ValueError("The scientific verifier did not return accepted PLAN-V2 evidence.")
        return _result(root, receipt, True,
                       "Original scientific sources and all required acceptance evidence verified.")
    except Exception as error:
        return _result(root, receipt, reason=f"Acceptance is unavailable: {error}")


def check_prerequisites():
    """The accepted MATLAB gate explicitly invokes the local py -3.12 launcher."""
    launcher = shutil.which("py")
    if not launcher:
        return {"python312_available": False, "reason": "Python 3.12 through the local py launcher is required by the accepted scientific runner."}
    try:
        completed = subprocess.run(
            [launcher, "-3.12", "-I", "-c", "import json,sys; print(json.dumps(list(sys.version_info[:2])))"],
            capture_output=True, text=True, timeout=15, shell=False,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        available = completed.returncode == 0 and json.loads(completed.stdout) == [3, 12]
    except (OSError, ValueError, subprocess.TimeoutExpired):
        available = False
    return {"python312_available": available,
            "reason": "Python 3.12 launcher is available." if available else
                      "The accepted scientific runner requires a working py -3.12 installation."}


def binding_status(project_root=None, acceptance_path=None):
    """Cheap startup check only; never enables launch without full verification."""
    try:
        root, receipt = _paths(project_root, acceptance_path)
        _trusted_inputs(root, receipt)
        prerequisite = check_prerequisites()
        result = _result(root, receipt, reason=prerequisite["reason"])
        result.update(prerequisite)
        result["ready_for_verification"] = prerequisite["python312_available"]
        if prerequisite["python312_available"]:
            result.update(state="checking", reason="Checking all original scientific sources and acceptance evidence.")
        return result
    except (OSError, TypeError, ValueError) as error:
        result = _result(project_root, acceptance_path, reason=str(error))
        result["ready_for_verification"] = False
        return result


def check_acceptance(project_root=None, acceptance_path=None, *, timeout=180, python_executable=None):
    """Return a fresh fail-closed launch status; callers may cache display only.

    Recheck immediately before launching MATLAB. Its unchanged scientific runner
    also performs its own acceptance check. Optional locations come from trusted
    local application configuration, never from an imported run or HTTP payload.
    """
    try:
        root, receipt = _paths(project_root, acceptance_path)
    except (TypeError, ValueError, OSError) as error:
        return _result(project_root, acceptance_path, reason=str(error))
    try:
        _trusted_inputs(root, receipt)
        prerequisite = check_prerequisites()
        if not prerequisite["python312_available"]:
            return _result(root, receipt, reason=prerequisite["reason"])
        executable = str(python_executable or sys.executable)
        command = [executable, "-I", str(Path(__file__).resolve()), "--worker", str(root), str(receipt)]
        completed = subprocess.run(command, capture_output=True, text=True, timeout=timeout,
                                   shell=False, cwd=str(Path(__file__).resolve().parent),
                                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        if completed.returncode != 0:
            try:
                worker = json.loads(completed.stdout)
                reason = worker.get("reason", "The scientific acceptance check failed.")
            except (ValueError, TypeError, AttributeError):
                reason = "The scientific acceptance check could not complete."
            return _result(root, receipt, reason=str(reason))
        worker = json.loads(completed.stdout)
        expected = _result(root, receipt)
        identity_fields = ("design_id", "scientific_project_root", "acceptance_path",
                           "verifier_sha256", "acceptance_sha256", "binding_kind")
        if not isinstance(worker, dict) or any(worker.get(k) != expected[k] for k in identity_fields):
            raise ValueError("The acceptance check returned an unexpected binding.")
        if worker.get("passed") is not True or worker.get("enabled") is not True or worker.get("state") != "ready":
            raise ValueError(worker.get("reason", "The scientific acceptance check failed."))
        _trusted_inputs(root, receipt)
        worker["python312_available"] = True
        return worker
    except subprocess.TimeoutExpired:
        return _result(root, receipt, reason="The full scientific acceptance check timed out; launches remain disabled.")
    except (OSError, ValueError, TypeError) as error:
        return _result(root, receipt, reason=f"Acceptance is unavailable: {error}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worker", action="store_true")
    parser.add_argument("project_root", nargs="?")
    parser.add_argument("acceptance_path", nargs="?")
    args = parser.parse_args(argv)
    try:
        result = (_verify_worker(args.project_root, args.acceptance_path) if args.worker
                  else check_acceptance(args.project_root, args.acceptance_path))
    except (TypeError, ValueError, OSError) as error:
        result = _result(args.project_root, args.acceptance_path, reason=str(error))
    print(json.dumps(result))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
