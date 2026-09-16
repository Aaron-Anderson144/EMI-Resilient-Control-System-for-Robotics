"""Verify the frozen V2 protocol and evidence identities; never authorize evaluation."""
from __future__ import annotations

import argparse
import csv
import hashlib
import itertools
import json
from pathlib import Path, PurePosixPath


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked_path(root, relative):
    p = PurePosixPath(relative)
    if p.is_absolute() or not p.parts or any(x in (".", "..") for x in p.parts) or "\\" in relative or ":" in relative:
        raise ValueError("Invalid project-relative path: " + relative)
    result = root.joinpath(*p.parts).resolve()
    if not result.is_relative_to(root):
        raise ValueError("Path outside project: " + relative)
    return result


def read_json(root, relative):
    return json.loads(checked_path(root, relative).read_text(encoding="utf-8-sig"))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(root):
    root = Path(root).resolve(strict=True)
    base = "04_EMI_Models/"
    manifest = read_json(root, base + "four_way_emi_v2_freeze_manifest.json")
    require(manifest["design_id"] == "FOUR-WAY-EMI-PLAN-V2", "Wrong design ID")
    require(manifest["freeze_type"] == "conditional_protocol_only", "Wrong freeze scope")
    require(manifest["evaluation_unopened"] is True, "Protocol must preserve unopened evaluation")
    names = [f["path"] for f in manifest["files"]]
    require(len(names) == len(set(names)), "Duplicate manifest entry")
    for f in manifest["files"]:
        p = checked_path(root, f["path"])
        require(p.is_file() and p.stat().st_size == f["bytes"] and digest(p) == f["sha256"], "Frozen V2 file changed: " + f["path"])
    old_freeze = read_json(root, base + "four_way_emi_freeze_manifest.json")
    for f in old_freeze["files"]:
        p = checked_path(root, f["path"])
        require(p.is_file() and p.stat().st_size == f["bytes"] and digest(p) == f["sha256"], "Original frozen input changed: " + f["path"])
    config = read_json(root, base + "four_way_emi_v2_configuration.json")
    old = read_json(root, base + "four_way_emi_configuration.json")
    for key in ("source", "task", "victim", "arms", "metrics"):
        require(config[key] == old[key], "Undeclared change to inherited " + key)
    require(config["status"] == "frozen_conditional_protocol_evaluation_locked", "Protocol is not finalized")
    require(config["evaluation_unopened"] and config["implementation_acceptance_required"], "Implementation gate is missing")
    rx = read_json(root, config["receiver_config_file"])
    variants = len(rx["receiver"]["thresholdPairs"]) * len(rx["receiver"]["postThresholdLatency_s"]) * len(rx["receiver"]["pulseLaws"])
    require(variants == 16, "Receiver variant set changed")
    with checked_path(root, config["fixture_file"]).open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    require(len({r["fixture_id"] for r in rows}) == len(rows), "Duplicate fixture ID")
    observed = {tuple(r[k] for k in ("stage", "Ccp_pF", "Ccn_pF", "task_sign", "phase_ns")) for r in rows}
    expected = {("development", str(cp), "8", "1", "0") for cp in (20, 160)}
    expected |= {("evaluation", str(cp), "7", str(sign), str(phase)) for cp, sign, phase in itertools.product((40, 120, 240), (1, -1), (-75, 75))}
    require(len(rows) == 14 and observed == expected, "Reserved fixture coverage changed")
    counts = {"development": 2 * variants * 8, "evaluation": 12 * variants * 8, "closure_diagnostic": 2 * variants * 4 * 2}
    counts["main"] = counts["development"] + counts["evaluation"]
    counts["total"] = counts["main"] + counts["closure_diagnostic"]
    require(config["logical_records"] == counts, "Logical record counts disagree")
    summary = read_json(root, manifest["characterization_summary"])
    require(summary.get("physicalValidation") is False, "Characterization must not claim physical validation")
    return {"design_id": manifest["design_id"], "protocol_identity_passed": True,
            "v2_files_verified": len(names), "original_frozen_files_verified": len(old_freeze["files"]),
            "receiver_variants": variants, "logical_records": counts,
            "evaluation_ready": False, "evaluation_unopened": True,
            "remaining_gates": ["causal V2 motor integration", "native numerical acceptance", "256 development logical records", "independent implementation freeze"],
            "meaning": "Protocol/evidence identity only; does not authorize evaluation or establish hardware validity."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = verify(args.root)
    encoded = json.dumps(result, indent=2, allow_nan=False) + "\n"
    if args.output:
        with args.output.open("x", encoding="utf-8") as f:
            f.write(encoded)
    print(encoded, end="")
