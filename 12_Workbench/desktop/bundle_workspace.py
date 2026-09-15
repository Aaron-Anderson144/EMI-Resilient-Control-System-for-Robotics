"""Copy the compact, byte-verified workspace used by EMI Workbench Desktop.

The scientific files and historical evidence are never rewritten. This package
supports the three workbench workflows, not every archived research campaign.
The desktop application and its Python/browser runtimes are packaged separately.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import sys


SOURCE_DIRECTORIES = (
    "03_MATLAB/functions", "03_MATLAB/scripts", "03_MATLAB/parameters",
    "03_MATLAB/tests", "03_MATLAB/models", "04_EMI_Models",
    "06_Circuit_Simulations/SC01A/functions",
    "06_Circuit_Simulations/SC01A/scripts",
    "06_Circuit_Simulations/SC01A/tests",
    "06_Circuit_Simulations/SC01A/models",
    "06_Circuit_Simulations/SC01B_R2/functions",
    "06_Circuit_Simulations/SC01B_R2/scripts",
    "06_Circuit_Simulations/SC01B_R2/tests",
    "06_Circuit_Simulations/SC01B_R2/models",
    "06_Circuit_Simulations/SC01B_R2/+sc01b_driver",
    "06_Circuit_Simulations/FOUR_WAY/functions",
    "06_Circuit_Simulations/FOUR_WAY/scripts",
    "06_Circuit_Simulations/FOUR_WAY/tests",
    "12_Workbench/matlab",
)
ROOT_PATTERNS = (
    "03_MATLAB/*.m", "03_MATLAB/README.md",
    "06_Circuit_Simulations/SC01A/*.m",
    "06_Circuit_Simulations/SC01A/*.md",
    "06_Circuit_Simulations/SC01B_R2/*.m",
    "06_Circuit_Simulations/SC01B_R2/*.md",
    "06_Circuit_Simulations/SC01B_R2/sc01b_driver_lib.slx",
    "06_Circuit_Simulations/FOUR_WAY/README.md",
)
REVIEW = "00_Project_Management/Reviews/2026-09-12/Complete_Verification"
DOCUMENTS = (
    "README.md",
    "00_Project_Management/Roadmap.md",
    "00_Project_Management/Reviews/2026-09-12/Receiver_Revision_Brief.md",
    "09_Report/Publication_2026-09-11/EMI_Robotics_Progress_Report.pdf",
    "11_EDMD_Hybrid_Estimation/README.md",
    "11_EDMD_Hybrid_Estimation/docs/VERIFICATION_AND_VALIDATION.md",
    "11_EDMD_Hybrid_Estimation/docs/RESULTS_20260913.md",
    REVIEW + "/Verification_Report.md",
    REVIEW + "/main_test_summary.json",
    REVIEW + "/verification_summary.json",
    "11_EDMD_Hybrid_Estimation/results/verification_summary.json",
    "00_Project_Management/Local_Reproduction.md",
    "09_Report/Publication_2026-09-11/Publication_Reproduction.md",
)
DEPENDENCIES = "00_Project_Management/Local_Dependencies.json"
FREEZE = "04_EMI_Models/four_way_emi_freeze_manifest.json"
ENGINE_SOURCE = "06_Circuit_Simulations/FOUR_WAY/functions/fourway_exact_mex.cpp"
RUN_ID = re.compile(r"\d{8}T\d{6}Z_[a-f0-9]{12}\Z")
EXCLUDED_COMPONENTS = {".git", "__pycache__", "slprj", "node_modules"}
EXCLUDED_SUFFIXES = {".pyc", ".pyo", ".slxc", ".tmp"}


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def local_path(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or "\\" in relative or ":" in relative:
        raise ValueError(f"Invalid project-relative path: {relative!r}")
    parts = PurePosixPath(relative).parts
    if not parts or relative.startswith("/") or any(p in (".", "..") for p in parts):
        raise ValueError(f"Invalid project-relative path: {relative!r}")
    candidate = root.joinpath(*parts)
    resolved = candidate.resolve()
    if not resolved.is_relative_to(root) or resolved == root:
        raise ValueError(f"Path leaves its project folder: {relative}")
    return candidate


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def excluded(path: Path) -> bool:
    return (any(p in EXCLUDED_COMPONENTS for p in path.parts)
            or path.suffix.lower() in EXCLUDED_SUFFIXES)


def build_workspace(source: Path, destination: Path) -> dict:
    source = source.expanduser().resolve(strict=True)
    destination = destination.expanduser().resolve()
    if not source.is_dir():
        raise ValueError("Source project must be a directory.")
    if destination == source or destination.is_relative_to(source) or source.is_relative_to(destination):
        raise ValueError("Destination must be separate from the source project.")
    if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):
        raise ValueError("Destination must not exist, or must be an empty directory.")

    planned: dict[str, dict] = {}
    missing_optional: list[dict] = []

    def add(relative: str, scope: str, optional=False, expected=None):
        path = local_path(source, relative)
        if not path.is_file():
            if optional:
                missing_optional.append({"path": relative, "scope": scope})
                return
            raise ValueError(f"Required workspace file is missing: {relative}")
        size, sha = path.stat().st_size, digest(path)
        if expected and (size != expected["bytes"] or sha != expected["sha256"].lower()):
            raise ValueError(f"Pinned input differs from its preserved manifest: {relative}")
        if relative in planned:
            if scope not in planned[relative]["scopes"]:
                planned[relative]["scopes"].append(scope)
            return
        planned[relative] = {"path": relative, "bytes": size, "sha256": sha,
                             "source_path": relative, "source_bytes": size,
                             "source_sha256": sha, "scopes": [scope]}

    for directory in SOURCE_DIRECTORIES:
        folder = local_path(source, directory)
        if not folder.is_dir():
            raise ValueError(f"Required source directory is missing: {directory}")
        for path in sorted(folder.rglob("*")):
            if path.is_file() and not excluded(path.relative_to(source)):
                add(path.relative_to(source).as_posix(), "workflow_source")
    for pattern in ROOT_PATTERNS:
        for path in sorted(source.glob(pattern)):
            if path.is_file():
                add(path.relative_to(source).as_posix(), "workflow_source")

    # Check every file in the original freeze before a destination is created.
    # In particular, Local_Dependencies.json is frozen and remains unchanged.
    add(FREEZE, "original_design_freeze")
    frozen = read_json(local_path(source, FREEZE))
    for item in frozen["files"]:
        add(item["path"], "original_design_freeze", expected=item)
    add(DEPENDENCIES, "dependency_manifest")
    dependencies = read_json(local_path(source, DEPENDENCIES))
    for item in dependencies["files"]:
        if item["group"] in ("regression_inputs", "experiment_source", "motion_history"):
            add(item["path"], item["group"], optional=item["group"] == "motion_history",
                expected=item)

    # Keep only the current, source-named Windows receiver extension. MATLAB
    # supplies its host runtime; a different source/platform needs a new build.
    engine_sha = digest(local_path(source, ENGINE_SOURCE))
    engine = f"06_Circuit_Simulations/FOUR_WAY/work/fourway_exact_{engine_sha[:16]}.mexw64"
    add(engine, "prebuilt_windows_receiver")
    for relative in DOCUMENTS:
        add(relative, "saved_document_or_evidence", optional=True)

    completed_runs = []
    skipped_runs = []
    runs = local_path(source, "12_Workbench/runs")
    if runs.is_dir():
        for folder in sorted(runs.iterdir()):
            if not folder.is_dir() or not RUN_ID.fullmatch(folder.name):
                continue
            relative = folder.relative_to(source).as_posix()
            try:
                record = read_json(local_path(source, relative + "/run.json"))
            except (OSError, ValueError):
                skipped_runs.append({"id": folder.name, "reason": "unreadable run record"})
                continue
            if record.get("id") != folder.name or record.get("status") != "completed":
                skipped_runs.append({"id": folder.name, "reason": "not a completed run"})
                continue
            add(relative + "/run.json", "saved_completed_run")
            for name in ("result.json", "matlab.log"):
                add(relative + "/" + name, "saved_completed_run", optional=True)
            output = local_path(source, relative + "/output")
            if output.is_dir():
                for path in sorted(output.rglob("*")):
                    if path.is_file() and not excluded(path.relative_to(source)):
                        add(path.relative_to(source).as_posix(), "saved_completed_run")
            completed_runs.append({"id": folder.name, "workflow": record.get("workflow"),
                                   "metrics": record.get("metrics", {})})

    files = [planned[name] for name in sorted(planned)]
    manifest = {
        "schema": "emi-workbench-bundled-workspace-v1",
        "created_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source_root": str(source),
        "scope": "Existing baseline, receiver_tests, and project_tests workflows; compact saved evidence and completed workbench runs.",
        "runtime": {
            "target": "Windows x64",
            "installed_mathworks_runtime": dependencies.get("installed_runtime", {}),
            "note": "Scientific execution requires locally installed licensed MATLAB products. The current Windows receiver MEX is included; rebuilding it requires a compatible C++ compiler.",
            "receiver_source_sha256": engine_sha,
            "receiver_binary_path": engine,
            "receiver_binary_sha256": planned[engine]["sha256"],
        },
        "original_freeze_files_verified": len(frozen["files"]),
        "original_frozen_manifests_modified": False,
        "included_pinned_input_groups": ["regression_inputs", "experiment_source", "motion_history"],
        "excluded_scopes": ["Full historical campaign archives", "Original SC01B suite and runtime", "EDMD execution campaigns", "ngspice distributions (not used by the three exposed workflows)", "Git history", "Compilation caches", "Scratch data and old executable run scripts", "Desktop application and browser/Python runtimes (packaged separately)"],
        "provenance_note": "Saved records retain their original paths, hashes, dates, outcomes and provenance. Their presence does not represent a new reproduction or research acceptance. Historical document links to excluded full archives may be unavailable.",
        "missing_optional_files": missing_optional,
        "saved_completed_runs": completed_runs,
        "skipped_runs": skipped_runs,
        "total_files": len(files),
        "total_bytes": sum(item["bytes"] for item in files),
        "files": files,
    }

    destination.mkdir(parents=True, exist_ok=True)
    for item in files:
        origin = local_path(source, item["path"])
        target = local_path(destination, item["path"])
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(origin, target)
        if target.stat().st_size != item["bytes"] or digest(target) != item["sha256"]:
            raise ValueError(f"Copied file did not match its source inventory: {item['path']}")
    # This is a new distribution manifest, separate from every scientific freeze.
    with (destination / "bundle_manifest.json").open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False, allow_nan=False)
        handle.write("\n")
    return manifest


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        manifest = build_workspace(args.source, args.destination)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Workspace bundle failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"destination": str(args.destination.resolve()),
                      "files": manifest["total_files"], "bytes": manifest["total_bytes"],
                      "frozen_files_verified": manifest["original_freeze_files_verified"],
                      "completed_runs": len(manifest["saved_completed_runs"]),
                      "missing_optional_files": manifest["missing_optional_files"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
