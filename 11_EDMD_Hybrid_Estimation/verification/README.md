# Independent stored-evidence audit

`verify_evidence.py` recomputes the saved forecast results using Python and NumPy, independently of the MATLAB metric implementation. It reads the three current `latest_*.json` pointers to locate the original experiment, diagnostics, and correction study. It does not run or change MATLAB models. Use the project's `run_verification` in MATLAB for the primary implementation and replay checks.

From the project folder, with Python 3.10 or newer:

```text
python -m pip install -r verification/requirements.txt
python verification/verify_evidence.py --output results/independent_evidence_audit.json
```

The default project root is the parent of the script's `verification` folder, so the command also works from another current directory. An explicit override is available:

```text
python verification/verify_evidence.py --project-root "C:/path/to/project" --output "C:/path/to/audit.json"
```

Without `--output`, the result is printed and no file is written. A successful audit exits with code 0 and reports `status: passed`; a failed assertion exits with a nonzero status. The JSON records resolved input directories, Python and NumPy versions, tolerances, and completed checks. This audit was exercised with Python 3.12 and NumPy 2.5.0.

## Coverage

This audit intentionally targets the current frozen study: 24 training, 12 validation, 40 original evaluation, and 52 correction evaluation trajectories. It expects 1 ms samples, horizons of 1/20/50/100/250 samples, 128 matching forecast origins, 102,400 original diagnostic endpoints, and 199,680 correction endpoints. It also checks the original reference files and experiment artifacts against the preserved version 0.1 manifest. Changing the study protocol or replacing the frozen original run requires a deliberate audit update; a different experiment is not silently accepted.

Checks include endpoint indexing and error identities; finite forecasts; event partitions; fixed correction weights and reasons across horizons; per-trajectory errors, bias, spread, nearest-rank P95 and maxima; equal-trajectory aggregation; paired origins, differences and wins; weight-use summaries; disjoint seed partitions; eligible correction-policy selection; original per-run reproduction and comparison screens; singular-value/ridge arithmetic; and lifted-diagnostic aggregation.

The numeric rule is `abs(actual - expected) <= 1e-11 + 1e-10 * abs(expected)` to allow decimal CSV rounding. Overall maximum differences include quantities with different units, including condition numbers. The per-study maxima concern forecast and event scoring.

Passing verifies consistency of stored evidence. It does not independently regenerate measured/truth arrays, establish uniqueness of those arrays, reproduce bootstrap confidence intervals, test hardware, certify EMI recovery or closed-loop stability, or establish an advantage for quadratic EDMD. The original EDMD benefit screen failed; optional correction weighting has a documented accuracy tradeoff. Those findings remain separate from arithmetic verification.
