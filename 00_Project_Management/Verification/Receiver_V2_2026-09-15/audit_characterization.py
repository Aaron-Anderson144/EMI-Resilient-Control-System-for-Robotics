"""Independent coverage and summary reconstruction for saved Receiver V2 CSVs."""
from pathlib import Path
import argparse, csv, hashlib, json, math


def truth(value):
    assert value.lower() in ("true", "false", "1", "0"), value
    return value.lower() in ("true", "1")


def audit(folder):
    folder = Path(folder)
    summary = json.loads((folder / "summary.json").read_text(encoding="utf-8"))
    with (folder / "cases.csv").open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    assert len(rows) == summary["totalCases"] == 640
    assert len({r["caseId"] for r in rows}) == len(rows)
    groups = {}
    for row in rows:
        groups.setdefault(row["recordId"], []).append(row)
    assert len(groups) == summary["circuitRecords"] == 40
    expected = {(threshold, delay, law)
                for threshold in ("typical_illustration", "lower_illustration", "upper_illustration", "narrow_hysteresis_assumption")
                for delay in (25., 40.) for law in ("transport", "inertial")}
    for record, cases in groups.items():
        assert len(cases) == 16
        actual = {(r["thresholdVariant"], float(r["latency_ns"]), r["pulseLaw"]) for r in cases}
        assert actual == expected, record
    clean = [r for r in rows if not truth(r["exposed"])]
    exposed = [r for r in rows if truth(r["exposed"])]
    assert len(clean) == len(exposed) == 320
    def valid(r): return r["domainStatus"] == "inside" and truth(r["numericalConverged"])
    valid_rows = [r for r in rows if valid(r)]
    invalid = [r for r in rows if r["domainStatus"] == "outside"]
    unresolved = [r for r in rows if not valid(r) and r["domainStatus"] != "outside"]
    assert len(valid_rows) == summary["validCases"]
    assert len(invalid) == summary["invalidCases"]
    assert len(unresolved) == summary["unresolvedCases"]
    valid_errors = [r for r in exposed if valid(r) and float(r["finalCountError"]) != 0]
    diagnostic_errors = [r for r in exposed if not valid(r) and float(r["finalCountError"]) != 0]
    for r in clean:
        assert valid(r)
        assert all(float(r[k]) == 0 for k in ("finalCountError", "extraEdges", "missedEdges", "invalidTransitions"))
        assert math.isfinite(float(r["maxTransitionDelay_ns"])) and 0 <= float(r["maxTransitionDelay_ns"]) <= 1000
    for r in valid_rows:
        assert all(abs(float(r[k])) <= 15 for k in ("minVp_V", "maxVp_V", "minVn_V", "maxVn_V", "minVd_V", "maxVd_V"))
        assert float(r["timeOutsideDomain_s"]) == 0
        assert not truth(r["stressFlag"])
    counterpart = {}
    for r in rows:
        key = (r["fixtureId"], r["capacitance_pF"], r["couplingP_pF"], r["thresholdVariant"], r["latency_ns"], r["pulseLaw"])
        counterpart.setdefault(key, []).append(r)
    assert len(counterpart) == 320 and all(len(rs) == 2 and {truth(r["exposed"]) for r in rs} == {True, False} for rs in counterpart.values())
    raw_groups = {}
    for r in rows:
        key = (r["recordId"], r["thresholdVariant"], r["latency_ns"])
        raw_groups.setdefault(key, []).append(r)
    dependent = 0
    valid_dependent = 0
    for pair in raw_groups.values():
        assert len(pair) == 2 and {r["pulseLaw"] for r in pair} == {"transport", "inertial"}
        changed = any(float(pair[0][k]) != float(pair[1][k]) for k in ("finalCountError", "outputEdges"))
        dependent += 2 * changed
        valid_dependent += 2 * (changed and all(valid(r) for r in pair))
    assert dependent == summary["pulseLawDependentCases"]
    return {"passed": True, "checks": ["640 unique cases", "40 complete 16-variant circuit groups", "320 matched clean/exposed pairs", "all clean domains/counts/delay guards", "summary counts independently reconstructed", "valid-case signed voltages", "pulse law comparisons independently reconstructed"],
            "valid_cases": len(valid_rows), "outside_cases": len(invalid), "unresolved_cases": len(unresolved),
            "valid_exposed_final_count_error_cases": len(valid_errors), "diagnostic_exposed_final_count_error_cases": len(diagnostic_errors),
            "pulse_law_dependent_cases": dependent, "valid_pulse_law_dependent_cases": valid_dependent,
            "cases_sha256": hashlib.sha256((folder / "cases.csv").read_bytes()).hexdigest(),
            "scope": "Independent saved-record coverage/summary audit; continuous solver verification is separate."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = audit(args.folder)
    data = json.dumps(result, indent=2) + "\n"
    if args.output:
        with args.output.open("x", encoding="utf-8") as f: f.write(data)
    print(data)
