# Causal four-way receiver experiment V2

This module connects the frozen PLAN-V2 receiver hypotheses to the existing three-second motor and controller. It preserves the PLAN-V1 implementation and the frozen V2 electrical-characterization files.

## Measurement boundary

The plant advances under the command already issued for the current interval. Its continuous trajectory generates intended encoder A/B transitions. The loaded circuit, Schmitt comparator, delayed receiver output, and Gray decoder retain state across every pulse and controller sample. Only decoded position, the causal source index, and sample-receipt metadata enter the controller. Circuit-domain flags, exposure labels, plant truth, and scoring remain outside that interface. A clean receiver shadow is replayed afterward on the exposed run's own intended trajectory.

Each record includes its complete receiver variant, circuit/source metadata, comparator/output/decoder events, controller samples, continuous plant metrics, and reconstruction state. Operating-domain or unresolved numerical failures are latched and reject interpretation; any continued waveform is diagnostic.

## Entry points

- `run_fourway_v2_stage("development", freshOutputFolder)` runs all 256 declared development records, with eight independent MATLAB workers by default.
- `run_fourway_v2_stage("evaluation", freshOutputFolder, acceptanceFile)` requires a separately accepted V2 implementation/evidence freeze before running all 1,536 reserved records.
- `run_fourway_v2_closure(freshOutputFolder, acceptanceFile)` runs the 256 declared source-return diagnostics, excluded from primary scoring.
- `audit/audit_v2_records.py` independently reconstructs exported event/count, motor, and paired-metric evidence.
- `audit/verify_v2_acceptance.py` creates or verifies the separate implementation freeze. It checks protocol hashes, exact development/native coverage, test suites, independent audits, and the identities of source and evidence files.

Add the existing `03_MATLAB/functions`, `03_MATLAB/parameters`, `FOUR_WAY/functions`, and this module's `functions` and `scripts` folders to the MATLAB path. Signal Lab supplies these paths for its development workflow.

Workers own complete receiver hypotheses. They share no circuit or control state. Every clean/exposed companion is executed independently; no clean-run cache or cross-hypothesis averaging is used. Worker evidence is retained and consolidated into one campaign index. Failed records remain indexed; incomplete coverage cannot pass acceptance.

## Scope

The sixteen variants are conditional numerical hypotheses, not measured hardware corners or a probability distribution. Post-threshold latency is an explicit assumption. Clamp behavior, physical encoder/cable transfer, and narrow-pulse response remain unmeasured. Numerical agreement cannot establish physical receiver validity or robot-level immunity.
